//
//  CTMessageReceiver.h
//  AzureTester
//
//  Created by Gary Meehan on 29/10/2012.
//  Copyright (c) 2012 CommonTime. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "CTNMessageConnector.h"

@class CTNMessage;
@class CTNNotificationProvider;

@interface CTNMessageReceiver : CTNMessageConnector

@property (nonatomic, readonly) NSString* channel;

- (id) initWithProvider: (CTNNotificationProvider*) provider
                channel: (NSString*) channel;

- (void) startAndIgnoreHistory: (BOOL) ignoreHistory;

- (void) stop;

- (void) didReceiveMessage: (CTNMessage*) message;

- (void) didFailWithErrorMessage: (NSString*) message
                       errorCode: (NSUInteger) code
                       willRetry: (BOOL) willRetry;

- (void) didFailWithError: (NSError*) error
                willRetry: (BOOL) willRetry;

@end
