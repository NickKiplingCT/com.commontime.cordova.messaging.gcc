//
//  CTNZumoProvider.m
//  Notifications
//
//  Created by Gary Meehan on 02/07/2014.
//  Copyright (c) 2014 CommonTime. All rights reserved.
//

#import "CTNZumoNotificationProvider.h"

#import <MicrosoftAzureMobile/MicrosoftAzureMobile.h>

#import "CTLogger.h"

#import "CTNAttachment.h"
#import "CTNAzureStorageBlobAttachment.h"
#import "CTNContent.h"
#import "CTNFileReference.h"
#import "CTNMessage.h"
#import "CTNMessageReceiver.h"
#import "CTNMessageSender.h"
#import "CTNMessageStore.h"
#import "CTNUtility.h"

#import "CTNZumoMessageSender.h"

@interface CTNZumoNotificationProvider()

@property (nonatomic, readwrite, strong) MSClient* client;
@property (nonatomic, readwrite, strong) NSString* userId;

@end

@implementation CTNZumoNotificationProvider

- (id) initWithURLString: (NSString*) URLString
                  userId: (NSString*) userId
                   token: (NSString*) token
{
  if ((self = [super initWithName: CTNNotificationPluginTypeZumo]))
  {
    self.client = [MSClient clientWithApplicationURLString: URLString];
    
    self.userId = userId;
    
    if (userId)
    {
      self.client.currentUser = [[MSUser alloc] initWithUserId: userId];
      self.client.currentUser.mobileServiceAuthenticationToken = token;
    }
  }
  
  return self;
}

- (NSString*) description
{
  return @"Zumo provider";
}

- (void) setUserId: (NSString*) userId
{
  self.client.currentUser = [[MSUser alloc] initWithUserId: userId];
}

- (void) setToken: (NSString*) token
{
  self.client.currentUser.mobileServiceAuthenticationToken = token;
}

- (void) clearCredentials
{
  [self.client logoutWithCompletion: ^(NSError* error){}];
}

- (CTNMessageSender*) messageSenderForMessage: (CTNMessage*) message
                                        error: (NSError**) error
{
  return [[CTNZumoMessageSender alloc] initWithProvider: self message: message];
}

- (void) messageDidExpire: (CTNMessage*) message
{
  [self postResponseContent: nil
                  errorType: @"expired"
               errorMessage: @"The message has expired"
                 forMessage: message];
  
  [super messageDidExpire: message];
}

- (BOOL) messageWillBeSentByFramework: (CTNMessage*) message
                                error: (NSError**) error
{
  if ([message.content containsFileReferences])
  {
    if (self.useStorage)
    {
      // N.B., at this point the message is NOT in the outbox so we don't need
      // to re-save the new content. Also, it's safe to save the attachments
      // before the message as there are no foreign-key constraints.
      id newContent = [message.content copyByCopyingFileReferencesWithError: error];
      
      if (!newContent)
      {
        return NO;
      }
      
      message.content = newContent;
      
      CTNMessageStore* outbox = [CTNMessageStore outboxMessageStore];
      NSArray* fileReferences = [message.content allFileReferences];
      
      for (CTNFileReference* fileReference in fileReferences)
      {
        NSString* identifier = [[fileReference.path lastPathComponent] stringByDeletingPathExtension];
        CTNAttachment* attachment = [[CTNAzureStorageBlobAttachment alloc] initWithIdentifier: identifier
                                                                                      message: message
                                                                                fileReference: fileReference];
        
        [outbox insertAttachment: attachment];
        
        [self.logger infoWithFormat: @"Created %@ from %@", attachment, fileReference];
      }
    }
    else
    {
      id expandedContent = [message.content copyByExpandingFileReferencesWithError: error];
      
      if (!expandedContent)
      {
        return NO;
      }
      
      message.content = expandedContent;
    }
  }
  
  return YES;
}

- (void) messageWillBeDeleted: (CTNMessage*) message
{
  [[CTNMessageStore outboxMessageStore] removeAllAttachmentsForMessage: message];
  [message.content deleteFilesWithError: NULL];
}

- (void) loginWithProvider: (NSString*) provider
                controller: (UIViewController*) controller
                  animated: (BOOL) animated
         completionHandler: (void (^)(NSString* userId, NSString* authenticationToken, NSError* error)) completionHandler
{
  [self.client loginWithProvider: provider
                      controller: controller
                        animated: animated
                      completion: ^(MSUser *user, NSError *error)
   {
     completionHandler(user.userId, user.mobileServiceAuthenticationToken, error);
   }];
}

- (void) postResponseContent: (id) responseContent
                  forMessage: (CTNMessage*) message
{
  [self postResponseContent: responseContent
                  errorType: nil
               errorMessage: nil
                 forMessage: message];
}

- (void) postResponseContent: (id) responseContent
                   errorType: (NSString*) errorType
                errorMessage: (NSString*) errorMessage
                  forMessage: (CTNMessage*) message
{
  CTNMessage* responseMessage = [CTNMessage message];
  NSMutableDictionary* response = [NSMutableDictionary dictionary];
  
  if (!responseContent)
  {
    responseContent = @{@"result": @NO, @"data": @""};
  }
  
  [response setObject: message.identifier forKey: @"reqId"];
  [response setObject: responseContent forKey: @"response"];
  [response setObject: errorType ? errorType : @"" forKey: @"errorType"];
  [response setObject: errorMessage ? errorMessage : @"" forKey: @"errorMessage"];
  [response setObject: message.content forKey: @"config"];
  
  responseMessage.content = response;
  responseMessage.channel = message.channel;
  responseMessage.subchannel = message.subchannel;
  responseMessage.provider = self.name;
  
  [[CTNMessageStore inboxMessageStore] addMessage: responseMessage];
}

- (BOOL) handleBackgroundEventsForSessionIdentifier: (NSString*) sessionIdentifier
                                  completionHandler: (void (^)(void)) completionHandler
{
  if ([super handleBackgroundEventsForSessionIdentifier: sessionIdentifier completionHandler: completionHandler])
  {
    return YES;
  }
  else
  {
    NSError* error = nil;
    CTNAttachment* attachment = [[CTNMessageStore outboxMessageStore] attachmentForSessionIdentifier: sessionIdentifier error: &error];
    
    if (!attachment)
    {
      return NO;
    }
    
    CTNMessageSender* sender = [self findOrCreateMessageSenderForMessage: attachment.message error: &error];
    
    if (!sender)
    {
      [self.logger warnWithFormat: @"Cannot create message sender for %@", attachment];
      
      return NO;
    }
    
    [sender handleEventsForAttachmentURLSession: attachment completionHandler: completionHandler];
    
    return YES;
  }
}

@end
