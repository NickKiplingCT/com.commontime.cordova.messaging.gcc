//
//  NotificationPlugin.h
//  mDesignShell
//
//  Created by Gary Meehan on 08/11/2012.
//  Copyright (c) 2012 CommonTime Limited. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <Cordova/CDV.h>

#import "CTNMessageStore.h"

@interface CTNNotificationPlugin : CDVPlugin<CTNMessageStoreDelegate>

- (void) addChannel: (CDVInvokedUrlCommand*) command;

- (void) removeChannel: (CDVInvokedUrlCommand*) command;

- (void) listChannels: (CDVInvokedUrlCommand*) command;

- (void) receiveMessageNotification: (CDVInvokedUrlCommand*) command;

- (void) cancelMessageNotification: (CDVInvokedUrlCommand*) command;

- (void) sendMessage: (CDVInvokedUrlCommand*) command;

- (void) messageReceivedAck: (CDVInvokedUrlCommand*) command;

- (void) cancelAllMessageNotifications: (CDVInvokedUrlCommand*) command;

- (void) deleteMessage: (CDVInvokedUrlCommand*) command;

- (void) getMessages: (CDVInvokedUrlCommand*) command;

- (void) getUnreadMessages: (CDVInvokedUrlCommand*) command;

- (void) receiveInboxChanges: (CDVInvokedUrlCommand*) command;

- (void) cancelInboxChanges: (CDVInvokedUrlCommand*) command;

- (void) setOptions: (CDVInvokedUrlCommand*) command;

@end
