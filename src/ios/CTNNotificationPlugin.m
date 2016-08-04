//
//  NotificationPlugin.m
//  mDesignShell
//
//  Created by Gary Meehan on 08/11/2012.
//  Copyright (c) 2012 CommonTime Limited. All rights reserved.
//

#import "CTNNotificationPlugin.h"

#import "CTLogger.h"
#import "CTLogManager.h"

#import "CTNMessage.h"
#import "CTNNotificationProvider.h"
#import "CTNNotificationProviderManager.h"

@interface CTNNotificationPlugin()

@property (nonatomic, readonly) CTLogger* logger;

@property (nonatomic, readwrite, strong) NSMutableDictionary* receiveInboxChangesCallbacks;
@property (nonatomic, readwrite, strong) NSMutableDictionary* receiveOutboxChangesCallbacks;
@property (nonatomic, readwrite, strong) NSMutableDictionary* receiveMessageCallbacks;

@end

@implementation CTNNotificationPlugin

- (void) pluginInitialize
{
  [super pluginInitialize];
  
  [[CTLogManager sharedManager] start];
  
  if ([self.viewController isKindOfClass: [CDVViewController class]])
  {
    NSDictionary* preferences = ((CDVViewController*) self.viewController).settings;
    CTNNotificationProviderManager* providerManager = [CTNNotificationProviderManager sharedManager];
    
    [providerManager startLogging];
    providerManager.defaultProviderName = [preferences objectForKey: @"defaultpushsystem"];
  }
  
  self.receiveInboxChangesCallbacks = [NSMutableDictionary dictionary];
  self.receiveOutboxChangesCallbacks = [NSMutableDictionary dictionary];
  self.receiveMessageCallbacks = [NSMutableDictionary dictionary];
  
  [CTNMessageStore inboxMessageStore].standardDelegate = self;
  [CTNMessageStore outboxMessageStore].standardDelegate = self;
  
  NSNotificationCenter* center = [NSNotificationCenter defaultCenter];
  
  [center addObserver: self
             selector: @selector(didReceiveSendMessageNotification:)
                 name: CTNSendMessageNotification
               object: nil];
}

- (CTLogger*) logger
{
  return [CTNNotificationProviderManager sharedManager].logger;
}

- (void) didReceiveSendMessageNotification: (NSNotification*) notification
{
  NSDictionary* userInfo = notification.userInfo;
  CTNMessage* message = [userInfo objectForKey: CTNSendMessageNotificationMessageKey];
  NSString* status = [userInfo objectForKey: CTNSendMessageNotificationStatusKey];
  
  NSLog(@"Status of sending %@ is %@", message, status);
  
  if ([self.receiveOutboxChangesCallbacks count] > 0)
  {
    NSDictionary* dictionary = [NSDictionary dictionaryWithObjectsAndKeys:
                                [message JSONObject], @"message",
                                status, @"action",
                                nil];
    
    for (NSString* callbackId in [self.receiveOutboxChangesCallbacks allValues])
    {
      CDVPluginResult* result = [CDVPluginResult resultWithStatus: CDVCommandStatus_OK
                                              messageAsDictionary: dictionary];
      
      [result setKeepCallbackAsBool: YES];
      
      [self.commandDelegate sendPluginResult: result callbackId: callbackId];
    }
  }
}

- (void) addChannel: (CDVInvokedUrlCommand*) command
{
  @try
  {
    if (command.arguments.count == 1)
    {
      NSString* channel = [command.arguments objectAtIndex: 0];
      
      [self.logger infoWithFormat: @"Will add channel %@", channel];
      
      NSError* error = nil;
      
      if ([self addChannel: channel error: &error])
      {
        CDVPluginResult* result = [CDVPluginResult resultWithStatus: CDVCommandStatus_OK
                                                    messageAsString: channel];
        
        [self.commandDelegate sendPluginResult: result callbackId: command.callbackId];
        
      }
      else
      {
        CDVPluginResult* result = [CDVPluginResult resultWithStatus: CDVCommandStatus_ERROR
                                                    messageAsString: [error localizedDescription]];
        
        [self.commandDelegate sendPluginResult: result callbackId: command.callbackId];
      }
    }
    else
    {
      CDVPluginResult* result = [CDVPluginResult resultWithStatus: CDVCommandStatus_ERROR
                                                  messageAsString: @"Incorrect number of arguments"];
      
      [self.commandDelegate sendPluginResult: result callbackId: command.callbackId];
    }
  }
  @catch (NSException *exception)
  {
    CDVPluginResult* result = [CDVPluginResult resultWithStatus: CDVCommandStatus_ERROR
                                                messageAsString: [exception reason]];
    
    [self.commandDelegate sendPluginResult: result callbackId: command.callbackId];
  }
}

- (BOOL) addChannel: (NSString*) channel error: (NSError**) error
{
  CTNMessageStore* inbox = [CTNMessageStore inboxMessageStore];
  
  if ([inbox canAddChannel: channel])
  {
    BOOL isChannelInitialized = [inbox isChannelInitialized: channel];
    CTNNotificationProviderManager* providerManager = [CTNNotificationProviderManager sharedManager];
    
    if ([providerManager receiveMessagesWithDefaultProviderOnChannel: channel
                                                       ignoreHistory: !isChannelInitialized
                                                               error: error])
    {
      if (!isChannelInitialized)
      {
        [inbox didInitializeChannel: channel];
      }
      
      return YES;
    }
    else
    {
      return NO;
    }
  }
  else
  {
    return YES;
  }
}

- (void) removeChannel: (CDVInvokedUrlCommand*) command
{
  @try
  {
    if (command.arguments.count == 1)
    {
      NSString* channel = [command.arguments objectAtIndex: 0];
      
      [self.logger infoWithFormat: @"Will remove channel %@", channel];

      CTNMessageStore* inbox = [CTNMessageStore inboxMessageStore];
      
      if ([inbox canAddChannel: channel])
      {
        CTNNotificationProviderManager* providerManager = [CTNNotificationProviderManager sharedManager];
        
        [providerManager stopReceivingMessagesWithDefaultProviderOnChannel: channel];

        CDVPluginResult* result = [CDVPluginResult resultWithStatus: CDVCommandStatus_OK
                                                    messageAsString: channel];
        
        [self.commandDelegate sendPluginResult: result callbackId: command.callbackId];
      }
      else
      {
        CDVPluginResult* result = [CDVPluginResult resultWithStatus: CDVCommandStatus_ERROR
                                                    messageAsString: @"cannot remove channel"];
        
        [self.commandDelegate sendPluginResult: result callbackId: command.callbackId];
      }
    }
    else
    {
      CDVPluginResult* result = [CDVPluginResult resultWithStatus: CDVCommandStatus_ERROR
                                                  messageAsString: @"Incorrect number of arguments"];
      
      [self.commandDelegate sendPluginResult: result callbackId: command.callbackId];
    }
  }
  @catch (NSException* exception)
  {
    CDVPluginResult* result = [CDVPluginResult resultWithStatus: CDVCommandStatus_ERROR
                                                messageAsString: [exception reason]];
    
    [self.commandDelegate sendPluginResult: result callbackId: command.callbackId];
  }
}

- (void) listChannels: (CDVInvokedUrlCommand*) command
{
  @try
  {
    if (command.arguments.count == 0)
    {
      [self.logger infoWithFormat: @"Will list channels"];

      NSArray* channels = [[CTNNotificationProviderManager sharedManager] allReceivingChannelsWithDefaultProvider];
      
      CDVPluginResult* result = [CDVPluginResult resultWithStatus: CDVCommandStatus_OK
                                                   messageAsArray: channels];
      
      [self.commandDelegate sendPluginResult: result callbackId: command.callbackId];
    }
    else
    {
      CDVPluginResult* result = [CDVPluginResult resultWithStatus: CDVCommandStatus_ERROR
                                                  messageAsString: @"Incorrect number of arguments"];
      
      [self.commandDelegate sendPluginResult: result callbackId: command.callbackId];
    }
  }
  @catch (NSException *exception)
  {
    CDVPluginResult* result = [CDVPluginResult resultWithStatus: CDVCommandStatus_ERROR
                                                messageAsString: [exception reason]];
    
    [self.commandDelegate sendPluginResult: result callbackId: command.callbackId];
  }
}

- (void) sendMessage: (CDVInvokedUrlCommand*) command
{
  @try
  {
    if (command.arguments.count == 1)
    {
      id JSONObject = [command.arguments objectAtIndex: 0];
      CTNMessage* message = [CTNMessage messageWithJSONObject: JSONObject];
      
      if (message.identifier.length == 0)
      {
        [message setUniqueIdentifier];
      }
      
      CTNNotificationProviderManager* providerManager = [CTNNotificationProviderManager sharedManager];
      
      if (message.provider.length == 0)
      {
        message.provider = providerManager.defaultProviderName;
      }
      
      [self.logger infoWithFormat: @"Will send message %@", message];
      
      NSError* error = nil;
      
      message.sentDate = [NSDate date];
      
      CTNNotificationProvider* provider = [providerManager providerWithName: message.provider error: &error];
      
      if (provider &&
          [provider messageWillBeSentByFramework: message error: &error] &&
          [provider sendMessage: message error: &error])
      {
        CDVPluginResult* result = [CDVPluginResult resultWithStatus: CDVCommandStatus_OK
                                                    messageAsString: message.identifier];
        
        [self.commandDelegate sendPluginResult: result callbackId: command.callbackId];
      }
      else
      {
        NSString* message = error ? [error localizedDescription] : @"cannot send message";
        
        CDVPluginResult* result = [CDVPluginResult resultWithStatus: CDVCommandStatus_ERROR
                                                    messageAsString: message];
        
        [self.commandDelegate sendPluginResult: result callbackId: command.callbackId];
      }
    }
    else
    {
      CDVPluginResult* result = [CDVPluginResult resultWithStatus: CDVCommandStatus_ERROR
                                                  messageAsString: @"Incorrect number of arguments"];
      
      [self.commandDelegate sendPluginResult: result callbackId: command.callbackId];
    }
  }
  @catch (NSException *exception)
  {
    CDVPluginResult* result = [CDVPluginResult resultWithStatus: CDVCommandStatus_ERROR
                                                messageAsString: [exception reason]];
    
    [self.commandDelegate sendPluginResult: result callbackId: command.callbackId];
  }
}

- (void) receiveMessageNotification: (CDVInvokedUrlCommand*) command
{
  @try
  {
    if (command.arguments.count == 3)
    {
      NSString* receiver = [command.arguments objectAtIndex: 0];
      NSString* channel = [command.arguments objectAtIndex: 1];
      NSString* subchannel = [command.arguments objectAtIndex: 2];
      
      [self.logger infoWithFormat: @"Will receive messages for %@ on channel %@ and subchannel %@", receiver, channel, subchannel];

      [self.receiveMessageCallbacks setObject: command.callbackId forKey: receiver];
      
      CTNMessageStore* inbox = [CTNMessageStore inboxMessageStore];
      NSArray* messages = [inbox allUnreadMessagesForReceiver: receiver
                                                      channel: channel
                                                   subchannel: subchannel];
      
      
      for (CTNMessage* message in messages)
      {
        [self.logger infoWithFormat: @"Will dispatch%@ for receiver %@", message, receiver];
        
        CDVPluginResult* result = [CDVPluginResult resultWithStatus: CDVCommandStatus_OK
                                                messageAsDictionary: [message JSONObject]];
        
        [result setKeepCallbackAsBool: YES];
        
        [self.commandDelegate sendPluginResult: result callbackId: command.callbackId];
      }
    }
    else
    {
      CDVPluginResult* result = [CDVPluginResult resultWithStatus: CDVCommandStatus_ERROR
                                                  messageAsString: @"Incorrect number of arguments"];
      
      [self.commandDelegate sendPluginResult: result callbackId: command.callbackId];
    }
  }
  @catch (NSException *exception)
  {
    CDVPluginResult* result = [CDVPluginResult resultWithStatus: CDVCommandStatus_ERROR
                                                messageAsString: [exception reason]];
    
    [self.commandDelegate sendPluginResult: result callbackId: command.callbackId];
  }
}

- (void) cancelMessageNotification: (CDVInvokedUrlCommand*) command
{
  @try
  {
    if (command.arguments.count == 1)
    {
      NSString* receiver = [command.arguments objectAtIndex: 0];
      
      [self.logger infoWithFormat: @"Will cancel message notifications for %@", receiver];

      [self.receiveMessageCallbacks removeObjectForKey: receiver];
      
      CDVPluginResult* result = [CDVPluginResult resultWithStatus: CDVCommandStatus_OK];
      
      [self.commandDelegate sendPluginResult: result callbackId: command.callbackId];
    }
    else
    {
      CDVPluginResult* result = [CDVPluginResult resultWithStatus: CDVCommandStatus_ERROR
                                                  messageAsString: @"Incorrect number of arguments"];
      
      [self.commandDelegate sendPluginResult: result callbackId: command.callbackId];
    }
  }
  @catch (NSException *exception)
  {
    CDVPluginResult* result = [CDVPluginResult resultWithStatus: CDVCommandStatus_ERROR
                                                messageAsString: [exception reason]];
    
    [self.commandDelegate sendPluginResult: result callbackId: command.callbackId];
  }
}

- (void) messageReceivedAck: (CDVInvokedUrlCommand*) command
{
  @try
  {
    if (command.arguments.count == 2)
    {
      NSString* receiver = [command.arguments objectAtIndex: 0];
      NSString* messageIdentifier = [command.arguments objectAtIndex: 1];
      
      [self.logger infoWithFormat: @"%@ has acknowledged receipt of message with ID %@", receiver, messageIdentifier];
      
      CTNMessageStore* inbox = [CTNMessageStore inboxMessageStore];
      CTNMessage* message = [inbox messageForIdentifier: messageIdentifier];
      
      [inbox message: message wasReadByReceiver: receiver];
      [inbox saveMessage: message allowUpdate: YES];
      
      CDVPluginResult* result = [CDVPluginResult resultWithStatus: CDVCommandStatus_OK
                                                   messageAsString: messageIdentifier];
      
      [self.commandDelegate sendPluginResult: result callbackId: command.callbackId];
    }
    else
    {
      CDVPluginResult* result = [CDVPluginResult resultWithStatus: CDVCommandStatus_ERROR
                                                  messageAsString: @"Incorrect number of arguments"];
      
      [self.commandDelegate sendPluginResult: result callbackId: command.callbackId];
    }
  }
  @catch (NSException *exception)
  {
    CDVPluginResult* result = [CDVPluginResult resultWithStatus: CDVCommandStatus_ERROR
                                                messageAsString: [exception reason]];
    
    [self.commandDelegate sendPluginResult: result callbackId: command.callbackId];
  }
}

- (void) cancelAllMessageNotifications: (CDVInvokedUrlCommand*) command
{
  @try
  {
    if (command.arguments.count == 0)
    {
      [self.logger infoWithFormat: @"Will cancel all message notifications"];
      
      [self.receiveMessageCallbacks removeAllObjects];
      
      CDVPluginResult* result = [CDVPluginResult resultWithStatus: CDVCommandStatus_OK];
      
      [self.commandDelegate sendPluginResult: result callbackId: command.callbackId];
    }
    else
    {
      CDVPluginResult* result = [CDVPluginResult resultWithStatus: CDVCommandStatus_ERROR
                                                  messageAsString: @"Incorrect number of arguments"];
      
      [self.commandDelegate sendPluginResult: result callbackId: command.callbackId];
    }
  }
  @catch (NSException *exception)
  {
    CDVPluginResult* result = [CDVPluginResult resultWithStatus: CDVCommandStatus_ERROR
                                                messageAsString: [exception reason]];
    
    [self.commandDelegate sendPluginResult: result callbackId: command.callbackId];
  }
}

- (void) deleteMessage: (CDVInvokedUrlCommand*) command
{
  @try
  {
    if (command.arguments.count == 1)
    {
      NSString* messageIdentifier = [command.arguments objectAtIndex: 0];
      
      [self.logger infoWithFormat: @"Will delete message with ID %@", messageIdentifier];
      
      CTNMessageStore* inbox = [CTNMessageStore inboxMessageStore];
      CTNMessage* message = [inbox messageForIdentifier: messageIdentifier];
      
      if (message)
      {
        [inbox removeMessage: message];
      }
      
      CDVPluginResult* result = [CDVPluginResult resultWithStatus: CDVCommandStatus_OK
                                                  messageAsString: messageIdentifier];
      
      [self.commandDelegate sendPluginResult: result callbackId: command.callbackId];
    }
    else
    {
      CDVPluginResult* result = [CDVPluginResult resultWithStatus: CDVCommandStatus_ERROR
                                                  messageAsString: @"Incorrect number of arguments"];
      
      [self.commandDelegate sendPluginResult: result callbackId: command.callbackId];
    }
  }
  @catch (NSException *exception)
  {
    CDVPluginResult* result = [CDVPluginResult resultWithStatus: CDVCommandStatus_ERROR
                                                messageAsString: [exception reason]];
    
    [self.commandDelegate sendPluginResult: result callbackId: command.callbackId];
  }
}

- (NSArray*) JSONArrayFromMessageArray: (NSArray*) array
{
  if (array)
  {
    NSMutableArray* JSONArray = [NSMutableArray arrayWithCapacity: array.count];
    
    for (CTNMessage* message in array)
    {
      [JSONArray addObject: message.JSONObject];
    }
    
    return JSONArray;
  }
  else
  {
    return nil;
  }
}

- (void) getMessages: (CDVInvokedUrlCommand*) command
{
  @try
  {
    if (command.arguments.count == 2)
    {
      NSString* channel = [command.arguments objectAtIndex: 0];
      NSString* subchannel = [command.arguments objectAtIndex: 1];
      
      if (subchannel.length == 0)
      {
        [self.logger infoWithFormat: @"Will get all messages on channel %@ and all subchannels", channel];
      }
      else
      {
        [self.logger infoWithFormat: @"Will get all messages on channel %@ and subchannel %@", channel, subchannel];
      }
      
      CTNMessageStore* inbox = [CTNMessageStore inboxMessageStore];
      NSArray* messages = [inbox allMessagesForChannel: channel
                                            subchannel: subchannel];
      
      CDVPluginResult* result = [CDVPluginResult resultWithStatus: CDVCommandStatus_OK
                                                   messageAsArray: [self JSONArrayFromMessageArray: messages]];
      
      [self.commandDelegate sendPluginResult: result callbackId: command.callbackId];
    }
    else
    {
      CDVPluginResult* result = [CDVPluginResult resultWithStatus: CDVCommandStatus_ERROR
                                                  messageAsString: @"Incorrect number of arguments"];
      
      [self.commandDelegate sendPluginResult: result callbackId: command.callbackId];
    }
  }
  @catch (NSException *exception)
  {
    CDVPluginResult* result = [CDVPluginResult resultWithStatus: CDVCommandStatus_ERROR
                                                messageAsString: [exception reason]];
    
    [self.commandDelegate sendPluginResult: result callbackId: command.callbackId];
  }
}

- (void) getUnreadMessages: (CDVInvokedUrlCommand*) command
{
  @try
  {
    if (command.arguments.count == 3)
    {
      NSString* receiver = [command.arguments objectAtIndex: 0];
      NSString* channel = [command.arguments objectAtIndex: 1];
      NSString* subchannel = [command.arguments objectAtIndex: 2];
      
      if (subchannel.length == 0)
      {
        [self.logger infoWithFormat: @"Will get all messages on channel %@ and all subchannels that are unread by %@", channel, receiver];
      }
      else
      {
        [self.logger infoWithFormat: @"Will get all messages on channel %@ and subchannel %@ that are unread by %@", channel, subchannel, receiver];
      }
      
      CTNMessageStore* inbox = [CTNMessageStore inboxMessageStore];
      NSArray* messages = [inbox allUnreadMessagesForReceiver: receiver
                                                      channel: channel
                                                   subchannel: subchannel];
      
      CDVPluginResult* result = [CDVPluginResult resultWithStatus: CDVCommandStatus_OK
                                                   messageAsArray: [self JSONArrayFromMessageArray: messages]];
      
      [self.commandDelegate sendPluginResult: result callbackId: command.callbackId];
    }
    else
    {
      CDVPluginResult* result = [CDVPluginResult resultWithStatus: CDVCommandStatus_ERROR
                                                  messageAsString: @"Incorrect number of arguments"];
      
      [self.commandDelegate sendPluginResult: result callbackId: command.callbackId];
    }
  }
  @catch (NSException *exception)
  {
    CDVPluginResult* result = [CDVPluginResult resultWithStatus: CDVCommandStatus_ERROR
                                                messageAsString: [exception reason]];
    
    [self.commandDelegate sendPluginResult: result callbackId: command.callbackId];
  }
}

- (void) receiveInboxChanges: (CDVInvokedUrlCommand*) command
{
  @try
  {
    if (command.arguments.count == 1)
    {
      NSString* receiver = [command.arguments objectAtIndex: 0];

      [self.logger infoWithFormat: @"Will receive inbox changes for %@", receiver];
      
      CTNMessageStore* inbox = [CTNMessageStore inboxMessageStore];
      
      [self.receiveInboxChangesCallbacks setObject: command.callbackId forKey: receiver];
      [inbox markAllUnreadMessagesAsCreated];
    }
    else
    {
      CDVPluginResult* result = [CDVPluginResult resultWithStatus: CDVCommandStatus_ERROR
                                                  messageAsString: @"Incorrect number of arguments"];
      
      [self.commandDelegate sendPluginResult: result callbackId: command.callbackId];
    }
  }
  @catch (NSException *exception)
  {
    CDVPluginResult* result = [CDVPluginResult resultWithStatus: CDVCommandStatus_ERROR
                                                messageAsString: [exception reason]];
    
    [self.commandDelegate sendPluginResult: result callbackId: command.callbackId];
  }
}

- (void) cancelInboxChanges: (CDVInvokedUrlCommand*) command
{
  @try
  {
    if (command.arguments.count == 1)
    {
      NSString* receiver = [command.arguments objectAtIndex: 0];

      [self.logger infoWithFormat: @"Will cancel receiving inbox changes for %@", receiver];

      [self.receiveInboxChangesCallbacks removeObjectForKey: receiver];

      CDVPluginResult* result = [CDVPluginResult resultWithStatus: CDVCommandStatus_OK];
      
      [self.commandDelegate sendPluginResult: result callbackId: command.callbackId];
    }
    else
    {
      CDVPluginResult* result = [CDVPluginResult resultWithStatus: CDVCommandStatus_ERROR
                                                  messageAsString: @"Incorrect number of arguments"];
      
      [self.commandDelegate sendPluginResult: result callbackId: command.callbackId];
    }
  }
  @catch (NSException *exception)
  {
    CDVPluginResult* result = [CDVPluginResult resultWithStatus: CDVCommandStatus_ERROR
                                                messageAsString: [exception reason]];
    
    [self.commandDelegate sendPluginResult: result callbackId: command.callbackId];
  }
}

- (void) receiveOutboxChanges: (CDVInvokedUrlCommand*) command
{
  @try
  {
    if (command.arguments.count == 1)
    {
      NSString* receiver = [command.arguments objectAtIndex: 0];
      
      [self.logger infoWithFormat: @"Will receive outbox changes for %@", receiver];
      
      [self.receiveOutboxChangesCallbacks setObject: command.callbackId forKey: receiver];
    }
    else
    {
      CDVPluginResult* result = [CDVPluginResult resultWithStatus: CDVCommandStatus_ERROR
                                                  messageAsString: @"Incorrect number of arguments"];
      
      [self.commandDelegate sendPluginResult: result callbackId: command.callbackId];
    }
  }
  @catch (NSException *exception)
  {
    CDVPluginResult* result = [CDVPluginResult resultWithStatus: CDVCommandStatus_ERROR
                                                messageAsString: [exception reason]];
    
    [self.commandDelegate sendPluginResult: result callbackId: command.callbackId];
  }
}

- (void) cancelOutboxChanges: (CDVInvokedUrlCommand*) command
{
  @try
  {
    if (command.arguments.count == 1)
    {
      NSString* receiver = [command.arguments objectAtIndex: 0];
      
      [self.logger infoWithFormat: @"Will cancel receiving outbox changes for %@", receiver];
      
      [self.receiveOutboxChangesCallbacks removeObjectForKey: receiver];

      CDVPluginResult* result = [CDVPluginResult resultWithStatus: CDVCommandStatus_OK];
      
      [self.commandDelegate sendPluginResult: result callbackId: command.callbackId];
    }
    else
    {
      CDVPluginResult* result = [CDVPluginResult resultWithStatus: CDVCommandStatus_ERROR
                                                  messageAsString: @"Incorrect number of arguments"];
      
      [self.commandDelegate sendPluginResult: result callbackId: command.callbackId];
    }
  }
  @catch (NSException *exception)
  {
    CDVPluginResult* result = [CDVPluginResult resultWithStatus: CDVCommandStatus_ERROR
                                                messageAsString: [exception reason]];
    
    [self.commandDelegate sendPluginResult: result callbackId: command.callbackId];
  }
}

- (void) setOptions: (CDVInvokedUrlCommand*) command
{
  @try
  {
    if (command.arguments.count == 1)
    {
      NSDictionary* options = command.arguments[0];
      
      if ([options isKindOfClass: [NSDictionary class]])
      {
        NSString* defaultPushSystem = options[@"defaultPushSystem"];
        
        if (defaultPushSystem)
        {
          [CTNNotificationProviderManager sharedManager].defaultProviderName = defaultPushSystem;
          
          NSLog(@"Set default push system to %@", defaultPushSystem);
        }
        
        CDVPluginResult* result = [CDVPluginResult resultWithStatus: CDVCommandStatus_OK];
        
        [self.commandDelegate sendPluginResult: result callbackId: command.callbackId];
      }
    }
    else
    {
      CDVPluginResult* result = [CDVPluginResult resultWithStatus: CDVCommandStatus_ERROR
                                                  messageAsString: @"Incorrect number of arguments"];
      
      [self.commandDelegate sendPluginResult: result callbackId: command.callbackId];
    }
  }
  @catch (NSException *exception)
  {
    CDVPluginResult* result = [CDVPluginResult resultWithStatus: CDVCommandStatus_ERROR
                                                messageAsString: [exception reason]];
    
    [self.commandDelegate sendPluginResult: result callbackId: command.callbackId];
  }
}

#pragma mark - CTNMessageStoreDelegate

- (BOOL) messageStore: (CTNMessageStore*) messageStore
        didAddMessage: (CTNMessage*) message
{
  [self.logger infoWithFormat: @"%@ was added to %@", message, messageStore];
  
  if (messageStore == [CTNMessageStore inboxMessageStore])
  {
    NSDictionary* dictionary = @{@"message": [message JSONObject],
                                 @"action": @"create"};
    
    if (messageStore == [CTNMessageStore inboxMessageStore])
    {
      for (NSString* callbackId in [self.receiveInboxChangesCallbacks allValues])
      {
        CDVPluginResult* result = [CDVPluginResult resultWithStatus: CDVCommandStatus_OK
                                                messageAsDictionary: dictionary];
        
        [result setKeepCallbackAsBool: YES];
        
        [self.commandDelegate sendPluginResult: result callbackId: callbackId];
      }
    }
  }
  
  NSDictionary* JSONObject = [message JSONObject];
  
  for (NSString* receiver in [self.receiveMessageCallbacks allKeys])
  {
    NSString* callbackId = [self.receiveMessageCallbacks objectForKey: receiver];
    
    if (![messageStore wasMessage: message readByReceiver: receiver])
    {
      [self.logger debugWithFormat: @"Will dispatch message %@ for %@", message, receiver];
      
      CDVPluginResult* result = [CDVPluginResult resultWithStatus: CDVCommandStatus_OK
                                              messageAsDictionary: JSONObject];
      
      [result setKeepCallbackAsBool: YES];
      
      [self.commandDelegate sendPluginResult: result callbackId: callbackId];
    }
  }
  
  return YES;
}

- (BOOL) messageStore: (CTNMessageStore*) messageStore
     didUpdateMessage: (CTNMessage*) message
{
  [self.logger infoWithFormat: @"%@ was updated in %@", message, messageStore];
  
  if (messageStore == [CTNMessageStore inboxMessageStore])
  {
    NSDictionary* dictionary = @{@"message": [message JSONObject],
                                 @"action": @"update"};
    
    for (NSString* callbackId in [self.receiveInboxChangesCallbacks allValues])
    {
      CDVPluginResult* result = [CDVPluginResult resultWithStatus: CDVCommandStatus_OK
                                              messageAsDictionary: dictionary];
      
      [result setKeepCallbackAsBool: YES];
      
      [self.commandDelegate sendPluginResult: result callbackId: callbackId];
    }
  }
  
  return YES;
}

- (BOOL) messageStore: (CTNMessageStore*) messageStore
     didRemoveMessage: (CTNMessage*) message
{
  [self.logger infoWithFormat: @"%@ was removed from %@", message, messageStore];
  
  if (messageStore == [CTNMessageStore inboxMessageStore])
  {
    NSDictionary* dictionary = @{@"message": [message JSONObject],
                                 @"action": @"delete"};
    
    for (NSString* callbackId in [self.receiveInboxChangesCallbacks allValues])
    {
      CDVPluginResult* result = [CDVPluginResult resultWithStatus: CDVCommandStatus_OK
                                              messageAsDictionary: dictionary];
      
      [result setKeepCallbackAsBool: YES];
      
      [self.commandDelegate sendPluginResult: result callbackId: callbackId];
    }
  }
  
  return YES;
}

@end
