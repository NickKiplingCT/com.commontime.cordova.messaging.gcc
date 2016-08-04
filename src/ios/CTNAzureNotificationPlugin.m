//
//  CTNAzureNotificationPlugin.m
//  MessagingTest
//
//  Created by Gary Meehan on 06/04/2016.
//
//

#import "CTNAzureNotificationPlugin.h"

#import "CTNAzureNotificationProvider.h"

#import "CTNNotificationProviderManager.h"

@implementation CTNAzureNotificationPlugin

- (void) start: (CDVInvokedUrlCommand*) command
{
  @try
  {
    CTNNotificationProviderManager* providerManager = [CTNNotificationProviderManager sharedManager];
    
    if ([providerManager providerWithName: CTNNotificationPluginTypeAzure error: NULL])
    {
      NSLog(@"The Azure Service Bus (ASB) notification plugin has already been started");
      
      CDVPluginResult* result = [CDVPluginResult resultWithStatus: CDVCommandStatus_OK];
      
      [self.commandDelegate sendPluginResult: result callbackId: command.callbackId];

      return;
    }
    
    NSString* serviceBusHostname = nil;
    NSString* serviceNamespace = nil;
    NSString* sasKeyName = nil;
    NSString* sasKey = nil;
    NSString* brokerType = nil;
    BOOL autoCreate = YES;
    
    if (command.arguments.count >= 1 && [[command.arguments objectAtIndex: 0] isKindOfClass: [NSDictionary class]])
    {
      NSDictionary* preferences = [command.arguments objectAtIndex: 0];
      
      serviceBusHostname = [preferences objectForKey: @"sbHostName"];
      serviceNamespace = [preferences objectForKey: @"serviceNamespace"];
      sasKeyName = [preferences objectForKey: @"sasKeyName"];
      sasKey = [preferences objectForKey: @"sasKey"];
      brokerType = [preferences objectForKey: @"brokerType"];
      
      if ([preferences objectForKey: @"brokerAutoCreate"])
      {
        autoCreate = [[preferences objectForKey: @"brokerAutoCreate"] boolValue];
      }
    }
    else  if ([self.viewController isKindOfClass: [CDVViewController class]])
    {
      NSDictionary* preferences = ((CDVViewController*) self.viewController).settings;
      
      serviceBusHostname = [preferences objectForKey: @"sbhostname"];
      serviceNamespace = [preferences objectForKey: @"servicenamespace"];
      sasKeyName = [preferences objectForKey: @"saskeyname"];
      sasKey = [preferences objectForKey: @"saskey"];
      brokerType = [preferences objectForKey: @"brokertype"];
      
      if ([preferences objectForKey: @"brokerautocreate"])
      {
        autoCreate = [[preferences objectForKey: @"brokerautocreate"] boolValue];
      }
    }
    else
    {
      CDVPluginResult* result = [CDVPluginResult resultWithStatus: CDVCommandStatus_ERROR
                                                 messageAsString: @"no settings"];
      
      [self.commandDelegate sendPluginResult: result callbackId: command.callbackId];
      
      return;
    }
    
    NSLog(@"Will start Azure Service Bus (ASB) notification plugin");
    
    CTNNotificationProvider* provider = [[CTNAzureNotificationProvider alloc] initWithServiceBusHostname: serviceBusHostname
                                                                                        serviceNamespace: serviceNamespace
                                                                                     sharedAccessKeyName: sasKeyName
                                                                                         sharedAccessKey: sasKey
                                                                                              autoCreate: autoCreate
                                                                                              brokerType: brokerType];
    
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
