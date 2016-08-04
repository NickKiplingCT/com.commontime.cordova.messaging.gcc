//
//  CTNAzureProvider.m
//  Notifications
//
//  Created by Gary Meehan on 12/02/2014.
//  Copyright (c) 2014 CommonTime. All rights reserved.
//

#import "CTNAzureNotificationProvider.h"

#import "CTNAzureMessageReceiver.h"
#import "CTNAzureMessageSender.h"

@interface CTNAzureNotificationProvider()

@property (nonatomic, readwrite, strong) NSString* serviceBusHostname;
@property (nonatomic, readwrite, strong) NSString* serviceNamespace;
@property (nonatomic, readwrite, strong) NSString* sharedAccessKeyName;
@property (nonatomic, readwrite, strong) NSString* sharedAccessKey;
@property (nonatomic, readwrite, assign) BOOL autoCreate;
@property (nonatomic, readwrite, strong) NSString* brokerType;

@end

@implementation CTNAzureNotificationProvider 

- (id) initWithServiceBusHostname: (NSString*) serviceBusHostname
                 serviceNamespace: (NSString*) serviceNamespace
              sharedAccessKeyName: (NSString*) sharedAccessKeyName
                  sharedAccessKey: (NSString*) sharedAccessKey
                       autoCreate: (BOOL) autoCreate
                       brokerType: (NSString*) brokerType
{
  if ((self = [super initWithName: CTNNotificationPluginTypeAzure]))
  {
    self.serviceBusHostname = serviceBusHostname;
    self.serviceNamespace = serviceNamespace;
    self.sharedAccessKeyName = sharedAccessKeyName;
    self.sharedAccessKey = sharedAccessKey;
    self.autoCreate = autoCreate;
    self.brokerType = brokerType;
  }
  
  return self;
}

- (BOOL) useQueues
{
  return !self.useTopics;
}

- (BOOL) useTopics
{
  return [self.brokerType compare: @"topic" options: NSCaseInsensitiveSearch] == NSOrderedSame;
}

- (NSString*) description
{
  return @"Azure provider";
}

- (CTNMessageReceiver*) messageReceiverWithChannel: (NSString*) channel
{
  return [[CTNAzureMessageReceiver alloc] initWithProvider: self channel: channel];
}

- (CTNMessageSender*) messageSenderForMessage: (CTNMessage*) message
                                        error: (NSError**) error;
{
  return [[CTNAzureMessageSender alloc] initWithProvider: self message: message];
}

@end
