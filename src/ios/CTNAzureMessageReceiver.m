//
//  CTAzureMessageReceiver.m
//  AzureTester
//
//  Created by Gary Meehan on 29/10/2012.
//  Copyright (c) 2012 CommonTime. All rights reserved.
//

#import "CTNAzureMessageReceiver.h"

#import "CTLogger.h"

#import "CTNAzureConstants.h"

#import "CTNConstants.h"
#import "CTNMessage.h"
#import "CTNNotificationProvider.h"
#import "CTNUtility.h"

@interface CTNAzureMessageReceiver()

@property (nonatomic, readonly) CTNAzureNotificationProvider* azureProvider;
@property (nonatomic, readwrite, strong) CTNAzureConnection* connection;
@property (nonatomic, readwrite, strong) NSTimer* timer;

@end

@implementation CTNAzureMessageReceiver

@synthesize timer;

- (CTNAzureNotificationProvider*) azureProvider
{
  return (CTNAzureNotificationProvider*) self.provider;
}

- (void) startAndIgnoreHistory: (BOOL) ignoreHistory
{
  [super startAndIgnoreHistory: ignoreHistory];
  
  if (self.connection)
  {
    return;
  }

  self.connection =
  [[CTNAzureConnection alloc] initWithProvider: self.azureProvider
                             sessionIdentifier: self.sessionIdentifier
                                       channel: self.channel];
  
  self.connection.delegate = self;
  [self.connection start];
}

- (void) stop
{
  [self.connection stop];
  self.connection.delegate = nil;
  self.connection = nil;
  
  if (self.timer.isValid)
  {
    [self.timer invalidate];
  }
  
  self.timer = nil;
  
  [super stop];
}

- (void) receiveNextMessageWithTimer: (NSTimer*) theTimer
{
  self.timer = nil;
  
  if (self.connection)
  {
    [self.connection retry];
  }
  else
  {
    [self startAndIgnoreHistory: NO];
  }
}

- (BOOL) performFetch
{
  if ([self.timer isValid] && self.connection)
  {
    [self.timer invalidate];
    self.timer = nil;
    [self.connection retry];

    return YES;
  }
  else
  {
    return NO;
  }
}

#pragma mark - CTNAzureConnectionDelegate

- (void) azureConnection: (CTNAzureConnection*) service
        didFailWithError: (NSError*) error
                canRetry: (BOOL) canRetry
{
  [self.logger warnWithFormat: @"Azure connection failed with error: %@ %@ retry", [error localizedDescription], canRetry ? @"Will" : @"Will not"];
  
  if (canRetry)
  {
    self.timer = [NSTimer scheduledTimerWithTimeInterval: CTNTimeIntervalBetweenRetries
                                                  target: self
                                                selector: @selector(receiveNextMessageWithTimer:)
                                                userInfo: nil
                                                 repeats: NO];
  }
  else
  {
    self.connection.delegate = nil;
    self.connection = nil;
  }
}

- (void) azureConnectionDidSendMessage: (CTNAzureConnection*) connection
{
}

- (void) azureConnection: (CTNAzureConnection*) connection
       didReceiveMessage: (CTNMessage*) message
{
  message.provider = self.provider.name;
  [self didReceiveMessage: message];
}

- (void) azureConnection: (CTNAzureConnection*) connection didFinishEventsForBackgroundURLSession: (NSURLSession*) session
{
  [self.logger infoWithFormat: @"Background events did finish for %@", self];
  
  [self callCompletionHandler];
}

@end
