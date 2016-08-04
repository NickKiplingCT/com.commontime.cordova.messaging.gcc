//
//  CTNMessageConnector.h
//  Notifications
//
//  Created by Gary Meehan on 30/01/2015.
//  Copyright (c) 2015 CommonTime. All rights reserved.
//

#import <Foundation/Foundation.h>

@class CTLogger;

@class CTNNotificationProvider;

@interface CTNMessageConnector : NSObject

@property (nonatomic, readonly) CTLogger* logger;
@property (nonatomic, readonly) CTNNotificationProvider* provider;
@property (nonatomic, readonly) NSString* sessionIdentifier;
@property (nonatomic, readwrite, copy) void (^completionHandler)();

- (id) initWithProvider: (CTNNotificationProvider*) provider
      sessionIdentifier: (NSString*) sessionIdentifier;

- (BOOL) performFetch;

- (void) handleBackgroundEventsWithCompletionHandler: (void (^)(void)) completionHandler;

- (void) callCompletionHandler;

@end
