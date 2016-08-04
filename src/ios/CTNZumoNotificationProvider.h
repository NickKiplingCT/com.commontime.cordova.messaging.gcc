//
//  CTNZumoProvider.h
//  Notifications
//
//  Created by Gary Meehan on 02/07/2014.
//  Copyright (c) 2014 CommonTime. All rights reserved.
//

#import "CTNNotificationProvider.h"

@class CTNZumoMessageSender;
@class CTNZumoNotificationProvider;

@class MSClient;

@interface CTNZumoNotificationProvider : CTNNotificationProvider

@property (nonatomic, readonly) MSClient* client;
@property (nonatomic, readonly) NSString* userId;
@property (nonatomic, readwrite, assign) BOOL useStorage;

- (id) initWithURLString: (NSString*) URLString
                  userId: (NSString*) userId
                   token: (NSString*) token;

- (void) setUserId: (NSString*) userId;

- (void) setToken: (NSString*) token;

- (void) clearCredentials;

- (void) loginWithProvider: (NSString*) provider
                controller: (UIViewController*) controller
                  animated: (BOOL) animated
         completionHandler: (void (^)(NSString* userId, NSString* authenticationToken, NSError* error)) completionHandler;

- (void) postResponseContent: (id) responseContent
                  forMessage: (CTNMessage*) message;

- (void) postResponseContent: (id) responseContent
                   errorType: (NSString*) errorType
                errorMessage: (NSString*) errorMessage
                  forMessage: (CTNMessage*) message;

@end
