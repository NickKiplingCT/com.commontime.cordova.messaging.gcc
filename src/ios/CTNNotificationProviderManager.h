//
//  CTNProviderManager.h
//  Notifications
//
//  Created by Gary Meehan on 12/02/2014.
//  Copyright (c) 2014 CommonTime. All rights reserved.
//

#import <Foundation/Foundation.h>

@class CTLogger;

@class CTNMessage;
@class CTNNotificationProvider;

@interface CTNNotificationProviderManager : NSObject

@property (nonatomic, readwrite, strong) NSString* defaultProviderName;
@property (nonatomic, readonly) CTLogger* logger;

+ (CTNNotificationProviderManager*) sharedManager;

- (void) startLogging;

- (void) stopLogging;

- (void) addProvider: (CTNNotificationProvider*) provider;

- (CTNNotificationProvider*) providerWithName: (NSString*) name error: (NSError**) error;

- (void) stopAllProviders;

- (void) authenticationDidSucceed;

- (void) authenticationDidFail;

- (BOOL) receiveMessagesWithDefaultProviderOnChannel: (NSString*) channel
                                       ignoreHistory: (BOOL) ignoreHistory
                                               error: (NSError**) error;

- (BOOL) stopReceivingMessagesWithDefaultProviderOnChannel: (NSString*) channel;

- (NSArray*) allReceivingChannelsWithDefaultProvider;

- (BOOL) performFetch;

- (BOOL) handleBackgroundEventsForSessionIdentifier: (NSString*) sessionIdentifier
                                  completionHandler: (void (^)(void)) completionHandler;

@end
