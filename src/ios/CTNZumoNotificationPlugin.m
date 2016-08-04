//
//  CTNZumoNotificationPlugin.m
//  MessagingTest
//
//  Created by Gary Meehan on 19/05/2016.
//
//

#import "CTNZumoNotificationPlugin.h"

#import "CTNNotificationProviderManager.h"
#import "CTNZumoNotificationProvider.h"

static NSString* CTNZumoUserIdKey = @"zumoUserId";
static NSString* CTNZumoTokenKey = @"zumoToken";

@interface CTNZumoNotificationPlugin()

@property (nonatomic, readwrite, strong) NSString* authenticationMethod;

@end

@implementation CTNZumoNotificationPlugin

- (void) start: (CDVInvokedUrlCommand*) command
{
  @try
  {
    NSLog(@"Will start the Azure App Services plugin");
    
    NSString* URLString = nil;
    bool useBlobStorage = NO;
    
    if (command.arguments.count >= 1 && [[command.arguments objectAtIndex: 0] isKindOfClass: [NSDictionary class]])
    {
      NSDictionary* preferences = [command.arguments objectAtIndex: 0];
      
      URLString = [preferences objectForKey: @"url"];
      self.authenticationMethod = [preferences objectForKey: @"authenticationMethod"];
      
      if ([preferences objectForKey: @"useBlobStorage"])
      {
        useBlobStorage = [[preferences objectForKey: @"useBlobStorage"] boolValue];
      }
    }
    else  if ([self.viewController isKindOfClass: [CDVViewController class]])
    {
      NSDictionary* preferences = ((CDVViewController*) self.viewController).settings;
      
      URLString = [preferences objectForKey: @"zumourl"];
      self.authenticationMethod = [preferences objectForKey: @"zumoauthenticationmethod"];

      if ([preferences objectForKey: @"zumouseblobstorage"])
      {
        useBlobStorage = [[preferences objectForKey: @"zumouseblobstorage"] boolValue];
      }
    }
    else
    {
      CDVPluginResult* result = [CDVPluginResult resultWithStatus: CDVCommandStatus_ERROR
                                                  messageAsString: @"no settings"];
      
      [self.commandDelegate sendPluginResult: result callbackId: command.callbackId];
      
      return;
    }
    
    NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
    NSString* userId = [userDefaults stringForKey: CTNZumoUserIdKey];
    NSString* token = [userDefaults stringForKey: CTNZumoTokenKey];
    
    CTNZumoNotificationProvider* provider = [[CTNZumoNotificationProvider alloc] initWithURLString: URLString
                                                                                            userId: userId
                                                                                             token: token];
    
    provider.useStorage = useBlobStorage;
    provider.delegate = self;
    [[CTNNotificationProviderManager sharedManager] addProvider: provider];
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

- (void) logout: (CDVInvokedUrlCommand*) command
{
  @try
  {
    NSLog(@"Will log out of Azure App Services");
    
    CTNNotificationProviderManager* manager = [CTNNotificationProviderManager sharedManager];
    CTNZumoNotificationProvider* provider = (CTNZumoNotificationProvider*) [manager providerWithName: CTNNotificationPluginTypeZumo
                                                                                               error: NULL];
    
    [provider clearCredentials];
    
    NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
    
    [userDefaults removeObjectForKey: CTNZumoUserIdKey];
    [userDefaults removeObjectForKey: CTNZumoTokenKey];
    
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

#pragma mark - CTNNotificationProviderDelegate

- (void) notificationProviderDidRequestAuthentication: (CTNNotificationProvider*) provider
{
  [(CTNZumoNotificationProvider*) provider loginWithProvider: self.authenticationMethod
                                                  controller: self.viewController
                                                    animated: YES
                                           completionHandler: ^(NSString *userId, NSString *authenticationToken, NSError *error)
   {
     if (error)
     {
       NSLog(@"Cannot authenticate with Azure App Services: %@", [error localizedDescription]);
       
       [provider authenticationDidFail];
     }
     else
     {
       NSLog(@"Authenticated %@ with Azure App Services", userId);
       
       NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
       
       if (userId)
       {
         [userDefaults setObject: userId forKey: CTNZumoUserIdKey];
       }
       else
       {
         [userDefaults removeObjectForKey: CTNZumoUserIdKey];
       }
       
       if (authenticationToken)
       {
         [userDefaults setObject: authenticationToken forKey: CTNZumoTokenKey];
       }
       else
       {
         [userDefaults removeObjectForKey: CTNZumoTokenKey];
       }
       
       [provider authenticationDidSucceed];
     }
   }];
}

- (void) notificationProvider: (CTNNotificationProvider*) provider didRequestDisplayOfData: (NSData*) data
{
}

@end

