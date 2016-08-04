//
//  CTNMessageSender.m
//  AzureTester
//
//  Created by Gary Meehan on 31/10/2012.
//  Copyright (c) 2012 CommonTime. All rights reserved.
//

#import "CTNMessage.h"

#import "CTLogger.h"

#import "CTNConstants.h"
#import "CTNMessageStore.h"
#import "CTNNotificationProvider.h"
#import "CTNUtility.h"

@interface CTNMessageSender()

@property (nonatomic, readwrite, strong) CTNMessage* message;
@property (nonatomic, readwrite, strong) NSTimer* timer;
@property (nonatomic, readwrite, assign) BOOL isStopped;

@end

static NSString* CTNMessageSenderIdentifierPrefix = @"MessageSender-";

@implementation CTNMessageSender

+ (NSString*) messageIdentifierFromSessionIdentifier: (NSString*) sessionIdentifier
{
  NSRange range = [sessionIdentifier rangeOfString: CTNMessageSenderIdentifierPrefix];
  
  if (range.location == 0)
  {
    return [sessionIdentifier substringFromIndex: range.length];
  }
  else
  {
    return nil;
  }
}

- (id) initWithProvider: (CTNNotificationProvider*) provider
                message: (CTNMessage*) message
{
  if ((self = [super initWithProvider: provider
                    sessionIdentifier: [NSString stringWithFormat: @"sender for %@", message]]))
  {
    self.message = message;
  }
  
  return self;
}

- (void) dealloc
{
  [self stop];
  
  if (self.timer.isValid)
  {
    [self.timer invalidate];
  }
}

- (NSString*) description
{
  return [NSString stringWithFormat: @"sender for %@", self.message];
}

- (void) start
{
  [self.logger traceWithFormat: @"Starting %@", self];
}

- (void) stop
{
  if (self.isStopped)
  {
    return;
  }
  
  [self removeMessageData];

  if (self.timer.isValid)
  {
    [self.timer invalidate];
  }
  
  self.timer = nil;
  self.isStopped = YES;

  [self.logger traceWithFormat: @"Stopped %@", self];
}

- (void) resendWithTimer: (NSTimer*) timer
{
  [self start];
}

- (void) postStatus: (NSString*) status
{
  NSNotificationCenter* center = [NSNotificationCenter defaultCenter];
  NSDictionary* userInfo =
  [NSDictionary dictionaryWithObjectsAndKeys:
   self.message, CTNSendMessageNotificationMessageKey,
   status, CTNSendMessageNotificationStatusKey,
   nil];
  
  [center postNotificationName: CTNSendMessageNotification
                        object: self
                      userInfo: userInfo];
}

- (BOOL) resendNow
{
  // The timer will only be valid if the sender is waiting to retry.
  if (self.timer.isValid)
  {
    dispatch_async(dispatch_get_main_queue(), ^{ [self.timer fire]; });
    
    return YES;
  }
  else
  {
    return NO;
  }
}

- (BOOL) performFetch
{
  if ([self.timer isValid])
  {
    [self.timer invalidate];
    [self resendWithTimer: nil];
    
    return YES;
  }
  else
  {
    return NO;
  }
}

- (void) didStartSending
{
  [self postStatus: CTNMessageSending];
  [self.delegate messageSenderDidStartSending: self];
}

- (void) didSucceed
{
  [self.logger infoWithFormat: @"%@ was successfully sent", self.message];
  
  [self postStatus: CTNMessageSent];
  [[CTNMessageStore outboxMessageStore] removeMessage: self.message];

  [self stop];
  [self callCompletionHandler];
  [self.delegate messageSenderDidFinish: self];
}

- (void) didFailWithDescription: (NSString*) description
                           code: (NSUInteger) code
                          retry: (CTNRetryStrategy) retry
{
  NSError* error = [NSError errorWithDomain: CTNErrorDomain
                                       code: code
                                   userInfo: @{CTNMessageKey: self.message, NSLocalizedDescriptionKey: description}];
  
  [self didFailWithError: error retry: retry];
}

- (void) didFailWithError: (NSError*) error
                    retry: (CTNRetryStrategy) retry
{
  BOOL willRetry = retry != CTNRetryNever;
  
  if (retry != CTNRetryWhenAuthenticated && self.message.hasExpired)
  {
    [self.logger warnWithFormat: @"%@ has expired", self.message];
  
    willRetry = NO;
  }
  
  if (willRetry)
  {
    if (retry == CTNRetryImmediately)
    {
      [self.logger warnWithFormat: @"%@ failed: %@ (%ld); will retry immediately", self, [error localizedDescription], (long) error.code];
      
      [self postStatus: CTNMessageFailedToSendAndWillRetry];
      [self stop];
      [self resendWithTimer: nil];
    }
    else if (retry == CTNRetryAfterDefaultPeriod)
    {
      [self.logger warnWithFormat: @"%@ failed: %@ (%ld); will retry in %lu seconds", self, [error localizedDescription], (long) error.code, (long) CTNTimeIntervalBetweenRetries];
      
      [self postStatus: CTNMessageFailedToSendAndWillRetry];
      [self stop];
      
      self.timer = [NSTimer scheduledTimerWithTimeInterval: CTNTimeIntervalBetweenRetries
                                                    target: self
                                                  selector: @selector(resendWithTimer:)
                                                  userInfo: nil
                                                   repeats: NO];
    }
    else if (retry == CTNRetryWhenAuthenticated)
    {
      [self.logger warnWithFormat: @"%@ failed: %@ (%ld); will retry when authenticated", self, [error localizedDescription], (long) error.code];
      
      [self postStatus: CTNMessageFailedToSendAndWillRetry];
      [self stop];

      // This timer will never fire (in my lifetime) but we need a valid timer
      // for the resend code to work
      self.timer = [NSTimer scheduledTimerWithTimeInterval: 60.0 * 60 * 24 * 365 * 100
                                                    target: self
                                                  selector: @selector(resendWithTimer:)
                                                  userInfo: nil
                                                   repeats: NO];
    }
  }
  else
  {
    [self.logger warnWithFormat: @"%@ failed: %@; won't retry", self, [error localizedDescription]];

    [self postStatus: CTNMessageFailedToSend];
    [[CTNMessageStore outboxMessageStore] removeMessage: self.message];
    [self.delegate messageSenderDidFinish: self];
  }
}

- (NSData*) messageData
{
  // This may be the content of the message or the entire message itself,
  // depending on the provider type. In either case, it's in JSON format.
  [self doesNotRecognizeSelector: _cmd];
  
  return nil;
}

- (NSString*) pathToMessageData
{
  return [self.provider pathToDataForMessage: self.message];
}

- (NSString*) writeMessageData: (NSData*) data withError: (NSError**) error
{
  return [self.provider writeData: data forMessage: self.message error: error];
}

- (void) removeMessageData
{
  [self.provider removeDataForMessage: self.message];
}

- (BOOL) handleEventsForAttachmentURLSession: (CTNAttachment*) attachment
                           completionHandler: (void (^)()) completionHandler;
{
  return NO;
}

@end
