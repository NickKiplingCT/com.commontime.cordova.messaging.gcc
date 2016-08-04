//
//  ConsoleDestination.m
//  Logging
//
//  Created by Gary Meehan on 26/04/2013.
//  Copyright (c) 2013 CommonTime. All rights reserved.
//

#import "CTConsoleLogDestination.h"

#import "CTLogLevel.h"
#import "CTLogMessage.h"

@implementation CTConsoleLogDestination

- (void) writeMessage: (CTLogMessage*) message
{
  NSLog(@"%@ %@ - %@",
        message.source,
        CTLogLevelPaddedDescription(message.level),
        message.detail);
}

- (void) clear
{
}

@end
