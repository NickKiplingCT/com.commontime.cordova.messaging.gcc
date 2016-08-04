//
//  CTNAzureProvider.h
//  Notifications
//
//  Created by Gary Meehan on 12/02/2014.
//  Copyright (c) 2014 CommonTime. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "CTNNotificationProvider.h"

@interface CTNAzureNotificationProvider : CTNNotificationProvider

@property (nonatomic, readonly) NSString* serviceBusHostname;
@property (nonatomic, readonly) NSString* serviceNamespace;
@property (nonatomic, readonly) NSString* sharedAccessKeyName;
@property (nonatomic, readonly) NSString* sharedAccessKey;
@property (nonatomic, readonly) BOOL autoCreate;
@property (nonatomic, readonly) NSString* brokerType;

@property (nonatomic, readonly) BOOL useQueues;
@property (nonatomic, readonly) BOOL useTopics;

- (id) initWithServiceBusHostname: (NSString*) serviceBusHostname
                 serviceNamespace: (NSString*) serviceNamespace
              sharedAccessKeyName: (NSString*) sharedAccessKeyName
                  sharedAccessKey: (NSString*) sharedAccessKey
                       autoCreate: (BOOL) autoCreate
                       brokerType: (NSString*) brokerType;

@end
