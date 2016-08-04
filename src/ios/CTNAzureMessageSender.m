//
//  CTNAzureMessageSender.m
//  AzureTester
//
//  Created by Gary Meehan on 31/10/2012.
//  Copyright (c) 2012 CommonTime. All rights reserved.
//

#import "CTNAzureMessageSender.h"

#import "CTLogger.h"

#import "CTNAzureConstants.h"

#import "CTNConstants.h"
#import "CTNMessage.h"
#import "CTNMessageStore.h"
#import "CTNUtility.h"

@interface CTNAzureMessageSender()

@property (nonatomic, readonly) CTNAzureNotificationProvider* azureProvider;
@property (nonatomic, readwrite, strong) CTNAzureConnection* connection;

@end

@implementation CTNAzureMessageSender

- (CTNAzureNotificationProvider*) azureProvider
{
  return (CTNAzureNotificationProvider*) self.provider;
}

- (void) start
{
  [super start];
  
  NSError* error = NULL;
  NSString* path = [self writeMessageData: CTNDataFromJSONObject([self.message JSONObject]) withError: &error];
  
  if (!path)
  {
    [self didFailWithError: error retry: CTNRetryNever];

    return;
  }
  
  NSURL* URL = [NSURL fileURLWithPath: path];
  
  self.connection = [[CTNAzureConnection alloc] initWithProvider: self.azureProvider
                                               sessionIdentifier: self.sessionIdentifier
                                                         message: self.message
                                                  messageDataURL: URL];
  
  self.connection.delegate = self;
  [self.connection start];
  [self didStartSending];
  
  [self.logger traceWithFormat: @"Started %@", self];
}

- (void) stop
{
  if (self.isStopped)
  {
    return;
  }
  
  [self.logger traceWithFormat: @"Stopping %@", self];
  
  [self.connection stop];
  self.connection.delegate = nil;
  self.connection = nil;
  
  [super stop];
}

#pragma mark - CTNAzureConnectionDelegate

- (void) azureConnection: (CTNAzureConnection*) connection
        didFailWithError: (NSError*) error
                canRetry: (BOOL) canRetry
{
  [self didFailWithError: error retry: canRetry ? CTNRetryAfterDefaultPeriod : CTNRetryNever];
}

- (void) azureConnectionDidSendMessage:(CTNAzureConnection *)connection
{
  [self didSucceed];
}

- (void) azureConnection: (CTNAzureConnection*) connection
       didReceiveMessage: (CTNMessage*) message
{
  // Nothing to do since we don't expect it
}

- (void) azureConnection: (CTNAzureConnection*) connection didFinishEventsForBackgroundURLSession: (NSURLSession*) session
{
  [self.logger infoWithFormat: @"Background events did finish for %@", self];
  
  [self callCompletionHandler];
}

@end
