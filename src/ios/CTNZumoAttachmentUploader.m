//
//  CTNZumoAttachmentUploader.m
//  Notifications
//
//  Created by Gary Meehan on 02/04/2015.
//  Copyright (c) 2015 CommonTime. All rights reserved.
//

#import "CTNZumoAttachmentUploader.h"

#import <MicrosoftAzureMobile/MicrosoftAzureMobile.h>

#import "CTLogger.h"

#import "CTNZumoNotificationProvider.h"
#import "CTNZumoMessageSender.h"

#import "CTNAzureStorageBlobAttachment.h"
#import "CTNAzureStorageBlobReference.h"
#import "CTNFileReference.h"
#import "CTNMessage.h"
#import "CTNMessageStore.h"
#import "CTNNotificationProviderManager.h"
#import "CTNUtility.h"
#import "HTTPConstants.h"

@interface CTNZumoAttachmentUploader()

@property (nonatomic, readwrite, strong) CTNZumoNotificationProvider* provider;

@property (nonatomic, readwrite, strong) CTNAzureStorageBlobAttachment* attachment;
@property (nonatomic, readwrite, strong) NSURLSession* session;
@property (nonatomic, readwrite, strong) NSURLSessionTask* task;
@property (nonatomic, readwrite, strong) NSURL* URL;

@property (nonatomic, readonly) CTLogger* logger;
@property (nonatomic, readonly) NSString* path;
@property (nonatomic, readonly) NSString* sessionIdentifier;

@end

@implementation CTNZumoAttachmentUploader

- (id) initWithAttachment: (CTNAzureStorageBlobAttachment*) attachment
                 provider: (CTNZumoNotificationProvider*) provider
{
  if ((self = [super init]))
  {
    self.provider = provider;
    self.attachment = attachment;
  }
  
  return self;
}

- (void) dealloc
{
  [self stop];
}

- (CTLogger*) logger
{
  return self.provider.logger;
}

- (NSString*) path
{
  return self.attachment.fileReference.path;
}

- (NSString*) description
{
  return [NSString stringWithFormat: @"Uploader for %@", self.attachment];
}

- (NSString*) sessionIdentifier
{
  return [self.attachment description];
}

- (void) start
{
  [self.logger infoWithFormat: @"%@ is starting", self];
  
  if (self.URL)
  {
    [self uploadAttachment];
  }
  else
  {
    [self getSASToken];
  }
}

- (void) uploadAttachment
{
  [self.logger infoWithFormat: @"Uploading %@", self.attachment];

  self.session = [NSURLSession sessionWithConfiguration: [self sessionConfiguration]
                                               delegate: self
                                          delegateQueue: [NSOperationQueue mainQueue]];
  
  self.attachment.status = CTNAttachmentUploading;
  self.attachment.sessionIdentifier = self.session.configuration.identifier;
  
  [[CTNMessageStore outboxMessageStore] updateAttachment: self.attachment];
  
  [self.logger traceWithFormat: @"Started session for %@ with ID %@", self, self.session.configuration.identifier];
  
#ifdef DEBUG
  [self.logger traceWithFormat: @"Uploading attachment to %@", self.URL];
#endif
  
  NSMutableURLRequest* URLRequest = [NSMutableURLRequest requestWithURL: self.URL];
  NSString* MIMEType = CTNMIMETypeFromPath(self.path);
  
  [URLRequest setHTTPMethod: @"PUT"];
  [URLRequest setValue: MIMEType forHTTPHeaderField: @"Content-Type"];
  [URLRequest setValue: @"BlockBlob" forHTTPHeaderField: @"x-ms-blob-type"];
  
  self.task = [self.session uploadTaskWithRequest: URLRequest fromFile: [NSURL fileURLWithPath: self.path]];
  [self.task resume];
}

- (void) rejoinSession
{
  self.session = [NSURLSession sessionWithConfiguration: [self sessionConfiguration]
                                               delegate: self
                                          delegateQueue: [NSOperationQueue mainQueue]];
  
  [self.logger traceWithFormat: @"Resumed session for %@ with ID %@", self, self.session.configuration.identifier];
}

- (void) getSASToken
{
  [self.logger infoWithFormat: @"Requesting SAS token for %@", self];
  
  NSDictionary* body = self.attachment.fileReference.context
  ? @{@"permission": @"write",
      @"gstId": self.attachment.identifier,
      @"reqId": self.attachment.message.identifier,
      @"context": self.attachment.fileReference.context}
  : @{@"permission": @"write",
      @"gstId": self.attachment.identifier,
      @"reqId": self.attachment.message.identifier};
  
  [self.provider.client invokeAPI: @"getsastoken"
                             body: body
                       HTTPMethod: @"POST"
                       parameters: nil
                          headers: nil
                       completion: ^(id result, NSHTTPURLResponse *response, NSError *error)
   {
     if (error)
     {
       [self.logger warnWithFormat: @"Cannot get SAS token: %@", [error localizedDescription]];
       
       CTNRetryStrategy retry;
       
       if (response)
       {
         if (response.statusCode == HTTPStatusUnauthorized)
         {
           [self.logger infoWithFormat: @"%@ will need authentication", self];
           
           self.attachment.status = CTNAttachmentPending;
           [[CTNMessageStore outboxMessageStore] updateAttachment: self.attachment];

           [self.provider requestAuthentication];
           retry = CTNRetryWhenAuthenticated;
         }
         else
         {
           retry = CTNRetryNever;
         }
       }
       else
       {
         retry = CTNRetryAfterDefaultPeriod;
       }
       
       [self.delegate attachmentUploader: self didFailWithError: error retry: retry];
     }
     else
     {
       if ([result isKindOfClass: [NSDictionary class]])
       {
         NSString* blobURLString = [result objectForKey: @"blobUri"];
         NSString* sasToken = [result objectForKey: @"sasToken"];
         NSURL* blobURL = [NSURL URLWithString: blobURLString];
         
         self.attachment.blobReference = [CTNAzureStorageBlobReference azureStorageBlobReferenceWithURL: blobURL
                                                                                                context: self.attachment.fileReference.context];
         
         self.URL = [NSURL URLWithString: [NSString stringWithFormat: @"%@?%@", blobURLString, sasToken]];
         
         [self.logger infoWithFormat: @"Received SAS token for %@; will upload %@ to %@", self, self.attachment.fileReference, self.attachment.blobReference];
         
         [self uploadAttachment];
       }
       else
       {
         [self.delegate attachmentUploader: self didFailWithError: nil retry: CTNRetryNever];
       }
     }
   }];
}

- (void) stop
{
  [self.task cancel];
  self.task = nil;
  
  [self.session invalidateAndCancel];
  self.session = nil;
}

- (NSURLSessionConfiguration*) sessionConfiguration
{
  NSURLSessionConfiguration* config = nil;
  
  if ([NSURLSessionConfiguration respondsToSelector: @selector(backgroundSessionConfigurationWithIdentifier:)])
  {
    config = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier: self.sessionIdentifier];
  }
  else
  {
    config = [NSURLSessionConfiguration ephemeralSessionConfiguration];
  }
  
  config.discretionary = NO;
  config.requestCachePolicy = NSURLCacheStorageNotAllowed;
  
  return config;
}

#pragma mark - NSURLSessionTaskDelegate

- (void) URLSession: (NSURLSession*) session
didReceiveChallenge: (NSURLAuthenticationChallenge *)challenge
  completionHandler: (void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential *credential)) completionHandler
{
  completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
}

- (void) URLSession: (NSURLSession*) session
               task: (NSURLSessionTask*) task
didCompleteWithError: (NSError*) error
{
  if (task.taskIdentifier != self.task.taskIdentifier)
  {
    [self.logger traceWithFormat: @"Ignoring completion event on task %lu for %@", (unsigned long) task.taskIdentifier, self];
    
    return;
  }
  
  NSHTTPURLResponse* response = (NSHTTPURLResponse*) task.response;
  
  if (error)
  {
    [self.logger traceWithFormat: @"Task %lu did complete for for %@ with error %@", (unsigned long) task.taskIdentifier, self, [error localizedDescription]];

    // If we get a error response from the server, we assume we can't retry;
    // otherwise we assume a transient error and that we can.
    [self.delegate attachmentUploader: self didFailWithError: error retry: task.response ? CTNRetryNever : CTNRetryAfterDefaultPeriod];
  }
  else
  {
    if (200 < response.statusCode && response.statusCode < 300)
    {
      [self.logger traceWithFormat: @"Task %lu did complete for for %@", (unsigned long) task.taskIdentifier, self];
      [self.logger infoWithFormat: @"%@ did succeed", self];
      
      [self.delegate attachmentUploaderDidSucceed: self];
    }
    else
    {
      NSString* description = [NSString stringWithFormat: @"Attachment upload failed with HTTP error %ld", (long) response.statusCode];
      NSError* httpError = [NSError errorWithDomain: CTNErrorDomain
                                               code: CTNHTTPError
                                           userInfo: @{NSLocalizedDescriptionKey: description}];
      
      [self.delegate attachmentUploader: self didFailWithError: httpError retry: CTNRetryNever];
    }
  }
  
  self.task = nil;
}

- (void) URLSession: (NSURLSession*) session
               task: (NSURLSessionTask*) task
    didSendBodyData: (int64_t) bytesSent
     totalBytesSent: (int64_t) totalBytesSent
totalBytesExpectedToSend: (int64_t) totalBytesExpectedToSend
{
  if (task.taskIdentifier != self.task.taskIdentifier)
  {
    [self.logger traceWithFormat: @"Ignoring did-send event on task %lu for %@", (unsigned long) task.taskIdentifier, self];
    
    return;
  }
  
  if (totalBytesExpectedToSend == NSURLSessionTransferSizeUnknown)
  {
    [self.logger traceWithFormat: @"%@ wrote %@", self, CTNFormatBytes(bytesSent)];
  }
  else
  {
    [self.logger traceWithFormat: @"%@ wrote %@ (%.1lf%%)", self, CTNFormatBytes(bytesSent), 100.0 * totalBytesSent / totalBytesExpectedToSend];
  }
}

- (void) URLSession: (NSURLSession*) session
               task: (NSURLSessionTask*) task
didReceiveChallenge: (NSURLAuthenticationChallenge*) challenge
  completionHandler: (void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential*)) completionHandler
{
  completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
}

- (void) URLSessionDidFinishEventsForBackgroundURLSession: (NSURLSession*) session
{
  [self.logger traceWithFormat: @"Background events did finish for %@", self];
  
  if (self.backgroundCompletionHandler)
  {
    self.backgroundCompletionHandler();
    self.backgroundCompletionHandler = nil;
  }
}

@end
