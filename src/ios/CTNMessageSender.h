//
//  CTNMessageSender.h
//  AzureTester
//
//  Created by Gary Meehan on 31/10/2012.
//  Copyright (c) 2012 CommonTime. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "CTNConstants.h"
#import "CTNMessageConnector.h"

@class CTNAttachment;
@class CTNMessage;
@class CTNMessageSender;
@class CTNNotificationProvider;

@protocol CTNMessageSenderDelegate

- (void) messageSenderDidStartSending: (CTNMessageSender*) sender;

- (void) messageSenderDidFinish: (CTNMessageSender*) sender;

@end

@interface CTNMessageSender : CTNMessageConnector

@property (nonatomic, readonly) CTNMessage* message;
@property (nonatomic, readonly) BOOL isStopped;

@property (nonatomic, readwrite, weak) id<CTNMessageSenderDelegate> delegate;

+ (NSString*) messageIdentifierFromSessionIdentifier: (NSString*) sessionIdentifier;

- (id) initWithProvider: (CTNNotificationProvider*) provider
                message: (CTNMessage*) message;

- (void) start;

- (void) stop;

- (BOOL) resendNow;

- (void) didStartSending;

- (void) didSucceed;

- (void) didFailWithDescription: (NSString*) description
                           code: (NSUInteger) code
                          retry: (CTNRetryStrategy) retry;

- (void) didFailWithError: (NSError*) error
                    retry: (CTNRetryStrategy) retry;

- (NSString*) writeMessageData: (NSData*) data withError: (NSError**) error;

- (BOOL) handleEventsForAttachmentURLSession: (CTNAttachment*) attachment
                           completionHandler: (void (^)()) completionHandler;

@end
