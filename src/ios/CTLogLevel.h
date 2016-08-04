//
//  CTLogLevel.h
//  Logging
//
//  Created by Gary Meehan on 26/04/2013.
//  Copyright (c) 2013 CommonTime. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString* CTLogLevelAllDescription;
extern NSString* CTLogLevelTraceDescription;
extern NSString* CTLogLevelDebugDescription;
extern NSString* CTLogLevelInfoDescription;
extern NSString* CTLogLevelWarnDescription;
extern NSString* CTLogLevelErrorDescription;
extern NSString* CTLogLevelFatalDescription;
extern NSString* CTLogLevelOffDescription;

extern NSString* CTLogLevelAllPaddedDescription;
extern NSString* CTLogLevelTracePaddedDescription;
extern NSString* CTLogLevelDebugPaddedDescription;
extern NSString* CTLogLevelInfoPaddedDescription;
extern NSString* CTLogLevelWarnPaddedDescription;
extern NSString* CTLogLevelErrorPaddedDescription;
extern NSString* CTLogLevelFatalPaddedDescription;
extern NSString* CTLogLevelOffPaddedDescription;

// These values come from the Log4j code.
typedef NS_ENUM(NSInteger, CTLogLevel)
{
  CTLogLevelAll = 0,
  CTLogLevelTrace = 5000,
  CTLogLevelDebug = 10000,
  CTLogLevelInfo = 20000,
  CTLogLevelWarn = 30000,
  CTLogLevelError = 40000,
  CTLogLevelFatal = 50000,
  CTLogLevelOff = 1000000,
};

NSString* CTLogLevelDescription(CTLogLevel level);

NSString* CTLogLevelPaddedDescription(CTLogLevel level);

CTLogLevel CTLogLevelFromString(NSString* string);
