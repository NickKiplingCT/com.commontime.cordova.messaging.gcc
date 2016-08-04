//
//  CTLogLevel.m
//  Logging
//
//  Created by Gary Meehan on 26/04/2013.
//  Copyright (c) 2013 CommonTime. All rights reserved.
//

#import "CTLogLevel.h"

NSString* CTLogLevelAllDescription = @"ALL";
NSString* CTLogLevelTraceDescription = @"TRACE";
NSString* CTLogLevelDebugDescription = @"DEBUG";
NSString* CTLogLevelInfoDescription = @"INFO";
NSString* CTLogLevelWarnDescription = @"WARN";
NSString* CTLogLevelErrorDescription = @"ERROR";
NSString* CTLogLevelFatalDescription = @"FATAL";
NSString* CTLogLevelOffDescription = @"OFF";

NSString* CTLogLevelAllPaddedDescription = @"ALL  ";
NSString* CTLogLevelTracePaddedDescription = @"TRACE";
NSString* CTLogLevelDebugPaddedDescription = @"DEBUG";
NSString* CTLogLevelInfoPaddedDescription = @"INFO ";
NSString* CTLogLevelWarnPaddedDescription = @"WARN ";
NSString* CTLogLevelErrorPaddedDescription = @"ERROR";
NSString* CTLogLevelFatalPaddedDescription = @"FATAL";
NSString* CTLogLevelOffPaddedDescription = @"OFF  ";

NSString* CTLogLevelDescription(CTLogLevel level)
{
  switch (level)
  {
    case CTLogLevelAll:
    {
      return CTLogLevelAllDescription;
    }
    case CTLogLevelTrace:
    {
      return CTLogLevelTraceDescription;
    }
    case CTLogLevelDebug:
    {
      return CTLogLevelDebugDescription;
    }
    case CTLogLevelInfo:
    {
      return CTLogLevelInfoDescription;
    }
    case CTLogLevelWarn:
    {
      return CTLogLevelWarnDescription;
    }
    case CTLogLevelError:
    {
      return CTLogLevelErrorDescription;
    }
    case CTLogLevelFatal:
    {
      return CTLogLevelFatalDescription;
    }
    case CTLogLevelOff:
    {
      return CTLogLevelOffDescription;
    }
    default:
    {
      return nil;
    }
  }
}

NSString* CTLogLevelPaddedDescription(CTLogLevel level)
{
  switch (level)
  {
    case CTLogLevelAll:
    {
      return CTLogLevelAllPaddedDescription;
    }
    case CTLogLevelTrace:
    {
      return CTLogLevelTracePaddedDescription;
    }
    case CTLogLevelDebug:
    {
      return CTLogLevelDebugPaddedDescription;
    }
    case CTLogLevelInfo:
    {
      return CTLogLevelInfoPaddedDescription;
    }
    case CTLogLevelWarn:
    {
      return CTLogLevelWarnPaddedDescription;
    }
    case CTLogLevelError:
    {
      return CTLogLevelErrorPaddedDescription;
    }
    case CTLogLevelFatal:
    {
      return CTLogLevelFatalPaddedDescription;
    }
    case CTLogLevelOff:
    {
      return CTLogLevelOffPaddedDescription;
    }
    default:
    {
      return nil;
    }
  }
}

CTLogLevel CTLogLevelFromString(NSString* string)
{
  NSCharacterSet* whitespace = [NSCharacterSet whitespaceAndNewlineCharacterSet];
  NSString* canonical = [[string stringByTrimmingCharactersInSet: whitespace] uppercaseString];
  
  if ([canonical isEqualToString: CTLogLevelAllDescription])
  {
    return CTLogLevelAll;
  }
  else if ([canonical isEqualToString: CTLogLevelTraceDescription])
  {
    return CTLogLevelTrace;
  }
  else if ([canonical isEqualToString: CTLogLevelDebugDescription])
  {
    return CTLogLevelDebug;
  }
  else if ([canonical isEqualToString: CTLogLevelInfoDescription])
  {
    return CTLogLevelInfo;
  }
  else if ([canonical isEqualToString: CTLogLevelWarnDescription])
  {
    return CTLogLevelWarn;
  }
  else if ([canonical isEqualToString: CTLogLevelErrorDescription])
  {
    return CTLogLevelError;
  }
  else if ([canonical isEqualToString: CTLogLevelFatalDescription])
  {
    return CTLogLevelFatal;
  }
  else
  {
    return CTLogLevelOff;
  }
}