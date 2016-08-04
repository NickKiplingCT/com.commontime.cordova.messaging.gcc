//
//  CTNRestNotificationProvider.m
//  MessagingTest
//
//  Created by Gary Meehan on 09/05/2016.
//
//

#import "CTNRestNotificationProvider.h"

#import "CTNContent.h"
#import "CTNMessage.h"
#import "CTNRestMessageSender.h"

@interface CTNRestNotificationProvider()

@property (nonatomic, readwrite, strong) NSDictionary* defaults;

@end

@implementation CTNRestNotificationProvider

- (id) init
{
  if ((self = [super initWithName: CTNNotificationPluginTypeRest]))
  {
  }
  
  return self;
}

- (NSString*) description
{
  return @"REST provider";
}

- (CTNMessageReceiver*) messageReceiverWithChannel: (NSString*) channel
{
  return nil;
}

- (CTNMessageSender*) messageSenderForMessage: (CTNMessage*) message
                                        error: (NSError**) error;
{
  return [[CTNRestMessageSender alloc] initWithProvider: self message: message];
}


- (void) messageWillBeDeleted: (CTNMessage*) message
{
  [super messageWillBeDeleted: message];
  
  [message.content deleteFilesWithError: NULL];
}

@end
