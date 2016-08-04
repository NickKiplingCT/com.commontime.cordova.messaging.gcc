//
//  CTLogDestination.h
//  Logging
//
//  Created by Gary Meehan on 26/04/2013.
//  Copyright (c) 2013 CommonTime. All rights reserved.
//

#import <Foundation/Foundation.h>

@class CTLogMessage;

@protocol CTLogDestination<NSObject>

- (void) writeMessage: (CTLogMessage*) message;

- (void) clear;

@end
