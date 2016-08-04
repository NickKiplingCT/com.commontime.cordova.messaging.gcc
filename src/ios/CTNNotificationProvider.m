//
//  CTNProvider.m
//  Notifications
//
//  Created by Gary Meehan on 12/02/2014.
//  Copyright (c) 2014 CommonTime. All rights reserved.
//

#import "CTNNotificationProvider.h"

#import "CTLogger.h"

#import "CTNAttachment.h"
#import "CTNMessage.h"
#import "CTNMessageReceiver.h"
#import "CTNMessageSender.h"
#import "CTNMessageStore.h"
#import "CTNNotificationProviderManager.h"
#import "CTNUtility.h"

@interface CTNNotificationProvider()

@property (nonatomic, readwrite, strong) NSString* name;
@property (nonatomic, readwrite, assign) BOOL isRequestingAuthentication;
@property (nonatomic, readwrite, strong) NSMutableDictionary* receivers;
@property (nonatomic, readwrite, strong) NSMutableSet* senders;

@end

@implementation CTNNotificationProvider

- (id) initWithName: (NSString*) name
{
  if ((self = [super init]))
  {
    self.name = name;
    self.receivers = [NSMutableDictionary dictionary];
    self.senders = [NSMutableSet set];
  }
  
  return self;
}

- (CTLogger*) logger
{
  return [CTNNotificationProviderManager sharedManager].logger;
}

- (CTNMessageReceiver*) messageReceiverWithChannel: (NSString*) channel
{
  return nil;
}

- (CTNMessageSender*) messageSenderForMessage: (CTNMessage*) message
                                        error: (NSError**) error
{
  return nil;
}

- (void) messageDidExpire: (CTNMessage*) message
{
}

- (void) messageWillBeDeleted: (CTNMessage*) message
{
  [self removeDataForMessage: message];
}

- (BOOL) messageWillBeSentByFramework: (CTNMessage*) message
                                error: (NSError**) error
{
  return YES;
}

- (BOOL) receiveMessagesOnChannel: (NSString*) channel
                    ignoreHistory: (BOOL) ignoreHistory
                            error: (NSError**) error
{
  channel = [channel lowercaseString];
  
  CTNMessageReceiver* receiver = [self.receivers objectForKey: channel];
  
  if (receiver)
  {
    return YES;
  }
  
  receiver = [self messageReceiverWithChannel: channel];
  
  if (receiver)
  {
    [receiver startAndIgnoreHistory: ignoreHistory];
    [self.receivers setObject: receiver forKey: channel];
  }
  
  return receiver != nil;
}

- (void) stopAllReceivers
{
  for (CTNMessageReceiver* receiver in [self.receivers allValues])
  {
    [receiver stop];
  }
}

- (void) stopAllSenders
{
  for (CTNMessageSender* sender in self.senders)
  {
    [sender stop];
  }
}

- (NSArray*) allReceivingChannels
{
  return [self.receivers allKeys];
}

- (BOOL) stopReceivingOnChannel: (NSString*) channel
{
  channel = [channel lowercaseString];
  
  CTNMessageReceiver* receiver = [self.receivers objectForKey: channel];
  
  if (receiver)
  {
    [receiver stop];
    [self.receivers removeObjectForKey: channel];
    
    return YES;
  }
  else
  {
    return NO;
  }
}

- (BOOL) sendMessage: (CTNMessage*) message error: (NSError**) error
{
  return [self sendMessage: message error: error completionHandler: NULL];
}

- (BOOL) sendMessage: (CTNMessage*) message
               error: (NSError**) error
   completionHandler: (void (^)()) completionHandler
{
  CTNMessageSender* sender = [self messageSenderForMessage: message error: error];
  
  if (sender)
  {
    sender.completionHandler = completionHandler;
    [[CTNMessageStore outboxMessageStore] saveMessage: message allowUpdate: NO];
    
    sender.delegate = self;
    [self.senders addObject: sender];
    [sender start];
    
    return YES;
  }
  else
  {
    return NO;
  }
}

- (void) sendAllPendingMessages
{
  CTNMessageStore* outbox = [CTNMessageStore outboxMessageStore];
  NSArray* pendingMessages = [outbox allUnreadMessagesForProviderWithName: self.name];
  
  [self.logger infoWithFormat: @"Have %ld pending %@ message(s) to send", (long) pendingMessages.count, self.name];
  
  for (CTNMessage* message in pendingMessages)
  {
    NSError* error = nil;
    
    if (![self sendMessage: message error: &error])
    {
      [self.logger warnWithFormat: @"Cannot send message %@: %@", message, [error localizedDescription]];
    }
  }
}

- (void) requestAuthentication
{
  if (!self.isRequestingAuthentication)
  {
    self.isRequestingAuthentication = YES;
    [self.delegate notificationProviderDidRequestAuthentication: self];
  }
}

- (void) authenticationDidSucceed
{
  self.isRequestingAuthentication = NO;
  [self resendAllMessagesNow];
}

- (void) authenticationDidFail
{
  self.isRequestingAuthentication = NO;
}

- (void) resendAllMessagesNow
{
  for (CTNMessageSender* sender in self.senders)
  {
    [sender resendNow];
  }
}

- (BOOL) performFetch
{
  BOOL hasData = NO;
  
  for (CTNMessageSender* sender in self.senders)
  {
    hasData |= [sender performFetch];
  }
  
  for (CTNMessageReceiver* receiver in [self.receivers allValues])
  {
    hasData |= [receiver performFetch];
  }
  
  return hasData;
}

- (CTNMessageSender*) findMessageSenderForMessage: (CTNMessage*) message
{
  for (CTNMessageSender* sender in self.senders)
  {
    if ([sender.message isEqualToMessage: message])
    {
      return sender;
    }
  }
  
  return nil;
}

- (CTNMessageSender*) findOrCreateMessageSenderForMessage: (CTNMessage*) message
                                                    error: (NSError**) error
{
  CTNMessageSender* sender = [self findMessageSenderForMessage: message];
  
  if (!sender)
  {
    sender = [self messageSenderForMessage: message error: error];
    
    if (sender)
    {
      [self.senders addObject: sender];
    }
  }
  
  return sender;
}

- (CTNMessageConnector*) findConnectorForSessionIdentifier: (NSString*) sessionIdentifier
{
  for (CTNMessageSender* sender in self.senders)
  {
    if ([sender.sessionIdentifier isEqualToString: sessionIdentifier])
    {
      return sender;
    }
  }
  
  for (CTNMessageReceiver* receiver in [self.receivers allValues])
  {
    if ([receiver.sessionIdentifier isEqualToString: sessionIdentifier])
    {
      return receiver;
    }
  }
  
  return nil;
}

- (BOOL) handleBackgroundEventsForSessionIdentifier: (NSString*) sessionIdentifier
                                  completionHandler: (void (^)(void)) completionHandler
{
  CTNMessageConnector* connector = [self findConnectorForSessionIdentifier: sessionIdentifier];
  
  if (connector)
  {
    [self.logger traceWithFormat: @"Handling background events for %@", connector];
    
    [connector handleBackgroundEventsWithCompletionHandler: completionHandler];
    
    return YES;
  }
  else
  {
    return NO;
  }
}

- (NSString*) pathToDataForMessage: (CTNMessage*) message
{
  NSArray* paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
  NSString* documentsDirectory = ([paths count] > 0) ? [paths objectAtIndex: 0] : nil;
  
  if (documentsDirectory)
  {
    NSString* filename = [NSString stringWithFormat: @"%@.json", message.identifier];
    
    return [documentsDirectory stringByAppendingPathComponent: filename];
  }
  else
  {
    return nil;
  }
}

- (NSString*) writeData: (NSData*) data
             forMessage: (CTNMessage*) message
                  error: (NSError**) error
{
  NSString* path = [self pathToDataForMessage: message];
  NSFileManager* fileManager = [NSFileManager defaultManager];
  
  if ([fileManager fileExistsAtPath: path])
  {
    [self.logger traceWithFormat: @"Message data for %@ already exists at %@", self, path];
    
    return path;
  }
  else
  {
    if ([data writeToFile: path options: NSDataWritingAtomic error: error])
    {
      [self.logger traceWithFormat: @"Wrote message data for %@ to %@", self, path];
      
      return path;
    }
    else
    {
      if (error)
      {
        [self.logger traceWithFormat: @"Failed to write message data for %@ to %@: %@", self, path, [*error localizedDescription]];
      }
      else
      {
        [self.logger traceWithFormat: @"Failed to write message data for %@ to %@", self, path];
      }
      
      return nil;
    }
  }
}

- (void) removeDataForMessage: (CTNMessage*) message
{
  NSString* path = [self pathToDataForMessage: message];
  NSFileManager* fileManager = [NSFileManager defaultManager];
  
  if ([fileManager fileExistsAtPath: path])
  {
    NSError* error = NULL;
    
    if ([fileManager removeItemAtPath: path error: &error])
    {
      [self.logger traceWithFormat: @"Removed message data for %@ at %@", self, path];
    }
    else
    {
      [self.logger traceWithFormat: @"Failed to remove message data for %@ at %@: %@", self, path, [error localizedDescription]];
    }
  }
}

#pragma mark - CTNMessageSenderDelegate

- (void) messageSenderDidStartSending: (CTNMessageSender*) sender
{
}

- (void) messageSenderDidFinish: (CTNMessageSender*) sender
{
  sender.delegate = nil;
  [self.senders removeObject: sender];
}

- (BOOL) needsDeletionStub
{
  return NO;
}

- (BOOL) handleEventsForBackgroundURLSession: (NSString*) identifier
                           completionHandler: (void (^)()) completionHandler
{
  NSError* error = nil;
  CTNAttachment* attachment = [[CTNMessageStore outboxMessageStore] attachmentForSessionIdentifier: identifier error: &error];
  
  if (!attachment)
  {
    return NO;
  }
  
  CTNMessageSender* sender = [self findMessageSenderForMessage: attachment.message];
  
  if (!sender)
  {
    sender = [self messageSenderForMessage: attachment.message error: &error];
    
    if (sender)
    {
      [self.senders addObject: sender];
    }
    else
    {
      [self.logger warnWithFormat: @"Cannot create message sender for %@", attachment];
      
      return NO;
    }
  }
  
  [sender handleEventsForAttachmentURLSession: attachment completionHandler: completionHandler];
  
  return YES;
}

@end
