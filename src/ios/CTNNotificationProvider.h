//
//  CTNProvider.h
//  Notifications
//
//  Created by Gary Meehan on 12/02/2014.
//  Copyright (c) 2014 CommonTime. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "CTNMessageSender.h"

@class CTLogger;

@class CTNMessage;
@class CTNMessageReceiver;
@class CTNNotificationProvider;

@protocol CTNNotificationProviderDelegate

- (void) notificationProviderDidRequestAuthentication: (CTNNotificationProvider*) provider;

- (void) notificationProvider: (CTNNotificationProvider*) provider didRequestDisplayOfData: (NSData*) data;

@end

@interface CTNNotificationProvider : NSObject<CTNMessageSenderDelegate>

@property (nonatomic, readwrite, weak) id<CTNNotificationProviderDelegate> delegate;

@property (nonatomic, readonly) NSString* name;
@property (nonatomic, readonly) CTLogger* logger;
@property (nonatomic, readonly) BOOL needsDeletionStub;

- (id) initWithName: (NSString*) name;

- (CTNMessageReceiver*) messageReceiverWithChannel: (NSString*) channel;

- (CTNMessageSender*) messageSenderForMessage: (CTNMessage*) message
                                        error: (NSError**) error;

- (BOOL) messageWillBeSentByFramework: (CTNMessage*) message
                                error: (NSError**) error;

- (void) messageDidExpire: (CTNMessage*) message;

- (void) messageWillBeDeleted: (CTNMessage*) message;

- (void) requestAuthentication;

- (void) authenticationDidSucceed;

- (void) authenticationDidFail;

- (void) stopAllReceivers;

- (void) stopAllSenders;

- (BOOL) receiveMessagesOnChannel: (NSString*) channel
                    ignoreHistory: (BOOL) ignoreHistory
                            error: (NSError**) error;

- (BOOL) stopReceivingOnChannel: (NSString*) channel;

- (NSArray*) allReceivingChannels;

- (BOOL) sendMessage: (CTNMessage*) message
               error: (NSError**) error;

- (BOOL) sendMessage: (CTNMessage*) message
               error: (NSError**) error
   completionHandler: (void (^)()) completionHandler;

- (void) sendAllPendingMessages;

- (void) resendAllMessagesNow;

- (BOOL) performFetch;

- (BOOL) handleBackgroundEventsForSessionIdentifier: (NSString*) sessionIdentifier
                                  completionHandler: (void (^)(void)) completionHandler;

- (NSString*) pathToDataForMessage: (CTNMessage*) message;

- (NSString*) writeData: (NSData*) data
             forMessage: (CTNMessage*) message
                  error: (NSError**) error;

- (void) removeDataForMessage: (CTNMessage*) message;

- (BOOL) handleEventsForBackgroundURLSession: (NSString*) identifier
                           completionHandler: (void (^)()) completionHandler;

- (CTNMessageSender*) findOrCreateMessageSenderForMessage: (CTNMessage*) message
                                                    error: (NSError**) error;

@end
