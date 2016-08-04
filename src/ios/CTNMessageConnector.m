//
//  CTNMessageConnector.m
//  Notifications
//
//  Created by Gary Meehan on 30/01/2015.
//  Copyright (c) 2015 CommonTime. All rights reserved.
//

#import "CTNMessageConnector.h"

#import "CTLogger.h"

#import "CTNNotificationProviderManager.h"
#import "CTNUtility.h"

@interface CTNMessageConnector()

@property (nonatomic, readwrite, assign) CTNNotificationProvider* provider;
@property (nonatomic, readwrite, strong) NSString* sessionIdentifier;

@end

@implementation CTNMessageConnector

- (id) initWithProvider: (CTNNotificationProvider*) provider
      sessionIdentifier: (NSString*) sessionIdentifier
{
  if ((self = [super init]))
  {
    self.provider = provider;
    self.sessionIdentifier = sessionIdentifier;
  }
  
  return self;
}

- (CTLogger*) logger
{
  return [CTNNotificationProviderManager sharedManager].logger;
}

- (BOOL) performFetch
{
  return NO;
}

- (void) handleBackgroundEventsWithCompletionHandler: (void (^)(void)) completionHandler
{
  self.completionHandler = completionHandler;
}

- (void) callCompletionHandler
{
  if (self.completionHandler)
  {
    [self.logger traceWithFormat: @"Calling completion handler for %@", self];

    self.completionHandler();
    self.completionHandler = nil;
  }
}

@end
