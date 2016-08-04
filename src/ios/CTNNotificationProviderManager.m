//
//  CTNProviderManager.m
//  Notifications
//
//  Created by Gary Meehan on 12/02/2014.
//  Copyright (c) 2014 CommonTime. All rights reserved.
//

#import "CTNNotificationProviderManager.h"

#import "CTLogManager.h"
#import "CTLogger.h"
#import "CTConsoleLogDestination.h"
#import "CTFileLogDestination.h"
#import "CTLogDestination.h"

#import "CTNConstants.h"
#import "CTNMessage.h"
#import "CTNNotificationProvider.h"
#import "CTNMessageStore.h"
#import "CTNUtility.h"

@interface CTNNotificationProviderManager()

@property (nonatomic, readwrite, strong) CTLogger* logger;
@property (nonatomic, readwrite, strong) NSMutableArray* allProviders;

@property (nonatomic, readonly) CTNNotificationProvider* defaultProvider;

@end

@implementation CTNNotificationProviderManager

+ (CTNNotificationProviderManager*) sharedManager
{
  static CTNNotificationProviderManager* instance = nil;
  
  if (instance == nil)
  {
    instance = [[CTNNotificationProviderManager alloc] init];
  }
  
  return instance;
}

- (id) init
{
  if ((self = [super init]))
  {
    self.allProviders = [NSMutableArray array];
  }

  return self;
}

- (void) dealloc
{
  [self stopAllProviders];
}

- (CTNNotificationProvider*) defaultProvider
{
  return [self providerWithName: self.defaultProviderName error: NULL];
}

- (void) startLogging
{
  CTLogManager* logManager = [CTLogManager sharedManager];
  
  self.logger = [[CTLogger alloc] initWithSource: @"NTF" name: @"notification"];
  [self.logger addDestination: logManager.consoleLogDestination];
  [self.logger addDestination: logManager.fileLogDestination];
  [[CTLogManager sharedManager] addLogger: self.logger];
  
#ifdef DEBUG
  self.logger.minimumLevel = CTLogLevelTrace;
#else
  self.logger.minimumLevel = CTLogLevelInfo;
#endif
}

- (void) stopLogging
{
  if (self.logger)
  {
    CTLogManager* logManager = [CTLogManager sharedManager];
    
    [logManager removeLogger: self.logger];
    self.logger = nil;
  }
}

- (void) addProvider: (CTNNotificationProvider*) provider
{
  CTNNotificationProvider* oldProvider = [self providerWithName: provider.name error: NULL];
  
  if (oldProvider)
  {
    [oldProvider stopAllSenders];
    [oldProvider stopAllReceivers];
    
    [self.allProviders removeObject: oldProvider];
  }
  
  [self.allProviders addObject: provider];
}

- (CTNNotificationProvider*) providerWithName: (NSString*) name error: (NSError**) error
{
  if (name.length == 0)
  {
    if (error)
    {
      NSString* description = @"No provider with an empty name";
      NSDictionary* userInfo = @{ NSLocalizedDescriptionKey : description };
      
      *error = [NSError errorWithDomain: CTNErrorDomain
                                   code: CTNCannotMakeProvider
                               userInfo: userInfo];
    }
    
    return nil;    
  }
  
  for (CTNNotificationProvider* provider in self.allProviders)
  {
    if ([name compare: provider.name options: NSCaseInsensitiveSearch] == 0)
    {
      return provider;
    }
  }
  
  if (error)
  {
    NSString* description = [NSString stringWithFormat: @"No provider with name %@", name];
    NSDictionary* userInfo = @{ NSLocalizedDescriptionKey : description };
    
    *error = [NSError errorWithDomain: CTNErrorDomain
                                 code: CTNCannotMakeProvider
                             userInfo: userInfo];
  }
  
  return nil;
}

- (void) stopAllProviders
{
  for (CTNNotificationProvider* provider in self.allProviders)
  {
    [provider stopAllReceivers];
    [provider stopAllSenders];
  }
  
  [self.allProviders removeAllObjects];
}

- (void) authenticationDidSucceed
{
  for (CTNNotificationProvider* provider in [self allProviders])
  {
    [provider authenticationDidSucceed];
  }
}

- (void) authenticationDidFail
{
  for (CTNNotificationProvider* provider in [self allProviders])
  {
    [provider authenticationDidFail];
  }
}

- (BOOL) receiveMessagesWithDefaultProviderOnChannel: (NSString*) channel
                                       ignoreHistory: (BOOL) ignoreHistory
                                               error: (NSError**) error
{
  if (self.defaultProvider)
  {
    return [self.defaultProvider receiveMessagesOnChannel: channel
                                            ignoreHistory: ignoreHistory
                                                    error: error];
  }
  else
  {
    if (error)
    {
      NSDictionary* userInfo = @{ NSLocalizedDescriptionKey: @"No default provider" };
      
      *error = [NSError errorWithDomain: CTNErrorDomain
                                   code: CTNCannotMakeProvider
                               userInfo: userInfo];
    }
    
    return NO;
  }
}

- (BOOL) stopReceivingMessagesWithDefaultProviderOnChannel: (NSString*) channel
{
  return [self.defaultProvider stopReceivingOnChannel: channel];
}

- (NSArray*) allReceivingChannelsWithDefaultProvider
{
  return [self.defaultProvider allReceivingChannels];
}

- (BOOL) performFetch
{
  BOOL hasData = NO;
  
  for (CTNNotificationProvider* provider in [self allProviders])
  {
    hasData |= [provider performFetch];
  }
  
  return hasData;
}

- (BOOL) handleBackgroundEventsForSessionIdentifier: (NSString*) sessionIdentifier
                                  completionHandler: (void (^)(void)) completionHandler
{
  for (CTNNotificationProvider* provider in self.allProviders)
  {
    if ([provider handleBackgroundEventsForSessionIdentifier: sessionIdentifier completionHandler: completionHandler])
    {
      return YES;
    }
  }
  
  return NO;
}

@end
