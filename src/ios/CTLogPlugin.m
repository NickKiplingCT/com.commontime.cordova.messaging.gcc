//
//  CTLogPlugin
//  mDesignShell
//
//  Created by Gary Meehan on 01/10/2012.
//  Copyright (c) 2012 CommonTime Limited. All rights reserved.
//

#import "CTLogPlugin.h"

#import "CTLogger.h"
#import "CTLogManager.h"

@implementation CTLogPlugin

- (void) log: (CDVInvokedUrlCommand*) command
{
  if ([command.arguments count] >= 3)
  {
    NSString* name = [command.arguments objectAtIndex: 0];
    NSNumber* level = [command.arguments objectAtIndex: 1];
    NSString* line = [command.arguments objectAtIndex: 2];
    CTLogger* logger = [[CTLogManager sharedManager] loggerWithName: name];
    
    [logger writeDetail: line atLevel: [level intValue]];
  }
}

- (void) start:  (CDVInvokedUrlCommand*) command
{
  [[CTLogManager sharedManager] start];
  
  CDVPluginResult* result = [CDVPluginResult resultWithStatus: CDVCommandStatus_OK];
  
  [self.commandDelegate sendPluginResult: result callbackId: command.callbackId];
}

- (void) stop: (CDVInvokedUrlCommand*) command
{
  [[CTLogManager sharedManager] stop];
  
  CDVPluginResult* result = [CDVPluginResult resultWithStatus: CDVCommandStatus_OK];
  
  [self.commandDelegate sendPluginResult: result callbackId: command.callbackId];
}

- (void) enable: (CDVInvokedUrlCommand*) command
{
  for (CTLogger* logger in [[CTLogManager sharedManager] allLoggers])
  {
    logger.minimumLevel = CTLogLevelAll;
  }
}

- (void) disable: (CDVInvokedUrlCommand*) command
{
  for (CTLogger* logger in [[CTLogManager sharedManager] allLoggers])
  {
    logger.minimumLevel = CTLogLevelOff;
  }
}

- (void) upload: (CDVInvokedUrlCommand*) command
{
  NSURL* URL = nil;
  
  if ([command.arguments count] > 0)
  {
    NSString* URLString = [command.arguments objectAtIndex: 0];
    
    if ([URLString isKindOfClass: [NSString class]])
    {
      URL = [NSURL URLWithString: URLString];
    }
  }
  
  [[CTLogManager sharedManager].delegate uploadLogsToURL: URL];
  
  CDVPluginResult* result = [CDVPluginResult resultWithStatus: CDVCommandStatus_OK];
  
  [self.commandDelegate sendPluginResult: result callbackId: command.callbackId];
}

- (void) mail: (CDVInvokedUrlCommand*) command
{
  NSString* recipient = nil;
  
  if ([command.arguments count] > 0)
  {
    recipient = [command.arguments objectAtIndex: 0];
    
    if ([recipient isKindOfClass: [NSNull class]])
    {
      recipient = nil;
    }
  }
  
  [[CTLogManager sharedManager].delegate sendLogsWithSubject: @"mDesign Logs" recipient: recipient];

  CDVPluginResult* result = [CDVPluginResult resultWithStatus: CDVCommandStatus_OK];
  
  [self.commandDelegate sendPluginResult: result callbackId: command.callbackId];
}

- (void) deleteLogFiles: (CDVInvokedUrlCommand*) command
{
  CTLogManager* logManager = [CTLogManager sharedManager];
  
  for (id<CTLogDestination> destination in [logManager allDestinations])
  {
    [destination clear];
  }
  
  [[logManager loggerWithName: @"shell"] info: @"Deleted all log files"];

  CDVPluginResult* result = [CDVPluginResult resultWithStatus: CDVCommandStatus_OK];
  
  [self.commandDelegate sendPluginResult: result callbackId: command.callbackId];
}

@end
