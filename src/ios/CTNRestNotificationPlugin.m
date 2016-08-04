//
//  CTNRestNotificationPlugin.m
//  MessagingTest
//
//  Created by Gary Meehan on 09/05/2016.
//
//

#import "CTNRestNotificationPlugin.h"

#import "CTNNotificationProviderManager.h"
#import "CTNRestNotificationProvider.h"

@implementation CTNRestNotificationPlugin

- (void) start: (CDVInvokedUrlCommand*) command
{
  @try
  {
    CTNNotificationProviderManager* providerManager = [CTNNotificationProviderManager sharedManager];
    
    if ([providerManager providerWithName: CTNNotificationPluginTypeRest error: NULL])
    {
      NSLog(@"The REST notification plugin has already been started");
      
      CDVPluginResult* result = [CDVPluginResult resultWithStatus: CDVCommandStatus_OK];
      
      [self.commandDelegate sendPluginResult: result callbackId: command.callbackId];
      
      return;
    }
    
    NSLog(@"Will start the REST notification plugin");
    
    CTNNotificationProvider* provider = [[CTNRestNotificationProvider alloc] init];
    
    [providerManager addProvider: provider];
    [provider sendAllPendingMessages];
    
    CDVPluginResult* result = [CDVPluginResult resultWithStatus: CDVCommandStatus_OK];
    
    [self.commandDelegate sendPluginResult: result callbackId: command.callbackId];
  }
  @catch (NSException *exception)
  {
    CDVPluginResult* result = [CDVPluginResult resultWithStatus: CDVCommandStatus_ERROR
                                                messageAsString: [exception reason]];
    
    [self.commandDelegate sendPluginResult: result callbackId: command.callbackId];
  }
}

@end
