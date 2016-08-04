//
//  CTNZumoMessageSender.m
//  Notifications
//
//  Created by Gary Meehan on 02/07/2014.
//  Copyright (c) 2014 CommonTime. All rights reserved.
//

#import "CTNZumoMessageSender.h"

#import <MicrosoftAzureMobile/MicrosoftAzureMobile.h>

#import "CTNAzureStorageBlobAttachment.h"
#import "CTNAzureStorageBlobReference.h"

#import "CTLogger.h"

#import "CTNConstants.h"
#import "CTNContent.h"
#import "CTNFileReference.h"
#import "CTNMessage.h"
#import "CTNMessageStore.h"
#import "CTNUtility.h"
#import "HTTPConstants.h"

#import "CTNZumoNotificationProvider.h"

@interface CTNZumoMessageSender()

@property (nonatomic, readwrite, strong) CTNZumoAttachmentUploader* currentAttachmentUploader;
@property (nonatomic, readonly) CTNZumoNotificationProvider* zumoProvider;

@end

@implementation CTNZumoMessageSender

- (CTNZumoNotificationProvider*) zumoProvider
{
  return (CTNZumoNotificationProvider*) self.provider;
}

- (void) start
{
  [super start];
  [self send];
}

- (void) send
{
  if (!self.message.content)
  {
    [self didFailWithDescription: @"missing content" code: CTNTypeError retry: CTNRetryNever];
    
    return;
  }
  
  if (self.zumoProvider.useStorage)
  {
    [self uploadNextAttachment];
  }
  else
  {
    [self sendMessage];
  }
}

- (void) uploadNextAttachment
{
  CTNMessageStore* outbox = [CTNMessageStore outboxMessageStore];
  NSError* error = nil;
  NSArray* attachments = [outbox allAttachmentsForMessage: self.message error: &error];

  if (!attachments)
  {
    [self didFailWithError: error retry: CTNRetryNever];
    
    return;
  }
  
  if (attachments.count == 0)
  {
    [self sendMessage];
  }
  else
  {
    CTNAzureStorageBlobAttachment* nextAttachment = nil;
    
    for (CTNAzureStorageBlobAttachment* attachment in attachments)
    {
      switch (attachment.status)
      {
        case CTNAttachmentPending:
        {
          nextAttachment = attachment;
          
          break;
        }
        case CTNAttachmentUploading:
        {
          // TODO: abort if it's been uploading too long?
          break;
        }
        case CTNAttachmentFailed:
        {
          NSString* description = [NSString stringWithFormat: @"Failed to upload attachment %@", attachment];
          
          [self didFailWithDescription: description
                                  code: CTNAttachmentUploadError
                                 retry: CTNRetryNever];
          
          return;
        }
        default:
        {
          break;
        }
      }
    }
    
    if (nextAttachment)
    {
      [self uploadAttachment: nextAttachment];
    }
    else
    {
      [outbox removeAllAttachmentsForMessage: self.message];
      [self sendMessage];
    }
  }
}

- (void) sendMessage
{
  id transport = [self.message.content objectForKey: @"transport"];
  
  id transportType = [transport objectForKey: @"type"];
  id httpMethod = [transport objectForKey: @"httpMethod"];
  id api = [transport objectForKey: @"api"];
  
  if (![transportType isKindOfClass: [NSString class]])
  {
    [self didFailWithDescription: @"incorrect type" code: CTNTypeError retry: CTNRetryNever];
    
    return;
  }
  
  if (![httpMethod isKindOfClass: [NSString class]])
  {
    [self didFailWithDescription: @"incorrect HTTP method" code: CTNTypeError retry: CTNRetryNever];
    
    return;
  }
  
  if (![api isKindOfClass: [NSString class]])
  {
    [self didFailWithDescription: @"incorrect API call" code: CTNTypeError retry: CTNRetryNever];
    
    return;
  }
  
  if (![transportType isEqualToString: @"zumoDirect"])
  {
    [self didFailWithDescription: @"unknown transport type" code: CTNTypeError retry: CTNRetryNever];
    
    return;
  }
  
  if ([httpMethod isEqualToString: @"POST"] ||
      [httpMethod isEqualToString: @"PUT"] ||
      [httpMethod isEqualToString: @"PATCH"])
  {
    [self.zumoProvider.client invokeAPI: api
                                   body: self.message.content
                             HTTPMethod: httpMethod
                             parameters: nil
                                headers: nil
                             completion: ^(id result, NSHTTPURLResponse *response, NSError *error)
     {
       if ([result containsNonStandardJSON])
       {
         [self.logger warn: @"Non-standard JSON detected in Zumo result"];
         
         NSError* conversionError = nil;
         id convertedResult = [result copyByConvertingToStandardJSONWithError: &conversionError];

         if (convertedResult)
         {
           result = convertedResult;
         }
         else
         {
           [self didReceiveResult: nil response: nil error: conversionError];

           return;
         }
       }
       
       [self didReceiveResult: result response: response error: error];
     }];
  }
  else if ([httpMethod isEqualToString: @"GET"] ||
           [httpMethod isEqualToString: @"DELETE"])
  {
    NSError* error = nil;
    NSData* contentData = [NSJSONSerialization dataWithJSONObject: self.message.content
                                                          options: 0
                                                            error: &error];
    
    if (!contentData)
    {
      [self didFailWithError: error retry: CTNRetryNever];
      
      return;
    }
    
    NSString* contentString = [[NSString alloc] initWithData: contentData encoding: NSUTF8StringEncoding];
    
    [self.zumoProvider.client invokeAPI: api
                                   body: nil
                             HTTPMethod: httpMethod
                             parameters: @{ @"data": contentString }
                                headers: nil
                             completion: ^(id result, NSHTTPURLResponse *response, NSError *error)
     {
       if ([result containsNonStandardJSON])
       {
         [self.logger warn: @"Non-standard JSON detected in Zumo result"];
         
         NSError* conversionError = nil;
         id convertedResult = [result copyByConvertingToStandardJSONWithError: &conversionError];
         
         if (convertedResult)
         {
           result = convertedResult;
        }
         else
         {
           [self didReceiveResult: nil response: nil error: conversionError];
           
           return;
         }
       }
       
       [self didReceiveResult: result response: response error: error];
     }];
  }
  else
  {
    [self didFailWithDescription: @"unknown HTTP method" code: CTNTypeError retry: CTNRetryNever];
  }
}

- (void) uploadAttachment: (CTNAzureStorageBlobAttachment*) attachment
{
  self.currentAttachmentUploader.delegate = nil;
  self.currentAttachmentUploader = [[CTNZumoAttachmentUploader alloc] initWithAttachment: attachment provider: self.zumoProvider];
  self.currentAttachmentUploader.delegate = self;
  
  [self.currentAttachmentUploader start];
}

- (void) didReceiveResult: (id) result
                 response: (NSHTTPURLResponse*) response
                    error: (NSError*) error
{
  if (error)
  {
    [self.logger warnWithFormat: @"Cannot send message: %@", [error localizedDescription]];
    
    CTNRetryStrategy retry;
    
    if (response)
    {
      if (response.statusCode == HTTPStatusUnauthorized)
      {
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
    
    [self didFailWithError: error retry: retry];
  }
  else
  {
    [self didSucceedWithResult: result];
  }
}

- (void) didSucceedWithResult: (id) result
{
  [self.zumoProvider postResponseContent: result forMessage: self.message];
  [self didSucceed];
}

- (void) didFailWithError: (NSError*) error retry: (CTNRetryStrategy) retry
{
  BOOL willRetry = retry != CTNRetryNever && !self.message.hasExpired;
  
  if (!willRetry)
  {
    [self.zumoProvider postResponseContent: nil
                                 errorType: self.message.hasExpired ? @"expired" : @"other"
                              errorMessage: [error localizedDescription]
                                forMessage: self.message];
  }
  
  [super didFailWithError: error retry: retry];
}

- (BOOL) handleEventsForAttachmentURLSession: (CTNAttachment*) attachment
                           completionHandler: (void (^)()) completionHandler;
{
  if (self.currentAttachmentUploader.attachment == attachment)
  {
    self.currentAttachmentUploader.backgroundCompletionHandler = completionHandler;
    
    return YES;
  }
  else if ([attachment isKindOfClass: [CTNAzureStorageBlobAttachment class]])
  {
    self.currentAttachmentUploader.delegate = nil;
    self.currentAttachmentUploader = [[CTNZumoAttachmentUploader alloc] initWithAttachment: (CTNAzureStorageBlobAttachment*) attachment provider: self.zumoProvider];
    self.currentAttachmentUploader.delegate = self;
    self.currentAttachmentUploader.backgroundCompletionHandler = completionHandler;
    [self.currentAttachmentUploader rejoinSession];
    
    return YES;
  }
  else
  {
    return NO;
  }
}

#pragma mark - CTNZumoAttachmentUploaderDelegate

- (void) attachmentUploaderDidSucceed: (CTNZumoAttachmentUploader*) uploader
{
  NSError* error = nil;
  NSFileManager* fileManager = [NSFileManager defaultManager];
  
  [fileManager removeItemAtPath: uploader.attachment.fileReference.path error: &error];
  
  id newContent = [self.message.content copyByReplacingFileReference: uploader.attachment.fileReference
                                       withAzureStorageBlobReference: uploader.attachment.blobReference
                                                               error: &error];
  
  if (!newContent)
  {
    [self didFailWithError: error retry: CTNRetryNever];
    
    return;
  }
  
  self.message.content = newContent;
  uploader.attachment.status = CTNAttachmentSucceeded;
  
  CTNMessageStore* outbox = [CTNMessageStore outboxMessageStore];

  [outbox saveMessage: self.message allowUpdate: YES];
  [outbox updateAttachment: uploader.attachment];
  
  self.currentAttachmentUploader.delegate = nil;
  self.currentAttachmentUploader = nil;
  [self uploadNextAttachment];
}

- (void) attachmentUploader: (CTNZumoAttachmentUploader*) uploader
           didFailWithError: (NSError*) error
                      retry: (CTNRetryStrategy) retry
{
  uploader.attachment.status = CTNAttachmentPending;
  [[CTNMessageStore outboxMessageStore] updateAttachment: uploader.attachment];
  
  self.currentAttachmentUploader.delegate = nil;
  self.currentAttachmentUploader = nil;
  
  [self didFailWithError: error retry: retry];
}

@end
