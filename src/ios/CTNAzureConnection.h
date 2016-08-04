//
//  CTNAzureConnection
//  Notifications
//
//  Created by Gary Meehan on 05/11/2012.
//  Copyright (c) 2012 CommonTime. All rights reserved.
//

#import <Foundation/Foundation.h>

@class CTNMessage;

@class CTNAzureConnection;
@class CTNAzureNotificationProvider;

@protocol CTNAzureConnectionDelegate

- (void) azureConnection: (CTNAzureConnection*) connection
        didFailWithError: (NSError*) error
                canRetry: (BOOL) canRetry;

- (void) azureConnectionDidSendMessage: (CTNAzureConnection*) connection;

- (void) azureConnection: (CTNAzureConnection*) connection
       didReceiveMessage: (CTNMessage*) message;

- (void) azureConnection: (CTNAzureConnection*) connection
didFinishEventsForBackgroundURLSession: (NSURLSession*) session;

@end

@interface CTNAzureConnection : NSObject<NSURLSessionDataDelegate, NSURLSessionTaskDelegate, NSURLSessionDownloadDelegate>

@property (nonatomic, readwrite, assign) id<CTNAzureConnectionDelegate> delegate;

- (id) initWithProvider: (CTNAzureNotificationProvider*) provider
      sessionIdentifier: (NSString*) sessionIdentifier
                channel: (NSString*) channel;

- (id) initWithProvider: (CTNAzureNotificationProvider*) provider
      sessionIdentifier: (NSString*) sessionIdentifier
                message: (CTNMessage*) message
         messageDataURL: (NSURL*) messageDataURL;

- (void) start;

- (void) stop;

- (void) retry;

@end
