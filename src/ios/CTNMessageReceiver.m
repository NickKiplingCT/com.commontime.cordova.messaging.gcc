//
//  CTMessageReceiver.m
//  AzureTester
//
//  Created by Gary Meehan on 29/10/2012.
//  Copyright (c) 2012 CommonTime. All rights reserved.
//

#import "CTNMessageReceiver.h"

#import "CTLogger.h"

#import "CTNConstants.h"
#import "CTNMessage.h"
#import "CTNMessageStore.h"
#import "CTNUtility.h"

@interface CTNMessageReceiver()

@property (nonatomic, readwrite, strong) NSString* channel;

@end

@implementation CTNMessageReceiver

- (id) initWithProvider: (CTNNotificationProvider*) provider
                channel: (NSString*) channel
{
  if ((self = [super initWithProvider: provider
                    sessionIdentifier: [NSString stringWithFormat: @"receiver on %@ at %@", channel, [NSDate date]]]))
  {
    self.channel = channel;
  }
  
  return self;
}

- (void) dealloc
{
  [self stop];
}

- (NSString*) description
{
  return [NSString stringWithFormat: @"receiver on %@", self.channel];
}

- (void) startAndIgnoreHistory: (BOOL) ignoreHistory
{
}

- (void) stop
{
}

- (void) didReceiveMessage: (CTNMessage*) message
{
  CTNMessageStore* inbox = [CTNMessageStore inboxMessageStore];
  
  [inbox addMessage: message];
}

- (void) didFailWithErrorMessage: (NSString*) message
                       errorCode: (NSUInteger) code
                       willRetry: (BOOL) willRetry
{
  NSDictionary* userInfo =
  [NSDictionary dictionaryWithObject: message
                              forKey: NSLocalizedDescriptionKey];
  
  NSError* error = [NSError errorWithDomain: CTNErrorDomain
                                       code: code
                                   userInfo: userInfo];
  
  [self didFailWithError: error willRetry: willRetry];
}

- (void) didFailWithError: (NSError*) error
                willRetry: (BOOL) willRetry

{
  [self.logger warnWithFormat: @"Failed to receive message on %@: %@; %@",
   self,
   [error localizedDescription],
   willRetry ? @"will retry" : @"will not retry"];
}

@end