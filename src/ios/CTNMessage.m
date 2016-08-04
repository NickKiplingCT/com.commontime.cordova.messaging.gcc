//
//  Messages.m
//  AzureTester
//
//  Created by Gary Meehan on 29/10/2012.
//  Copyright (c) 2012 CommonTime. All rights reserved.
//

#import "CTNMessage.h"

#import "CTNConstants.h"

#import "NSDictionary+JSON.h"

@implementation CTNMessage

@dynamic hasExpired;
@dynamic channel;
@dynamic subchannel;

+ (id) message
{
  return [[self alloc] init];
}

+ (id) messageWithJSONObject: (id) JSONObject
{
  return [[self alloc] initWithJSONObject: JSONObject];
}

- (id) init
{
  if ((self = [super init]))
  {
    [self setUniqueIdentifier];
    
    self.sentDate = [NSDate date];
    self.timeToLive = CTNMessageTimeToLive;
  }
  
  return self;
}

- (id) initWithJSONObject: (id) JSONObject
{
  if ((self = [super init]))
  {
    if ([JSONObject isKindOfClass: [NSDictionary class]])
    {
      self.identifier = [JSONObject stringForJSONKey: CTNIdentifierKey];
      self.channel = [JSONObject stringForJSONKey: CTNChannelKey];
      self.subchannel = [JSONObject stringForJSONKey: CTNSubchannelKey];
      self.content = [JSONObject objectForJSONKey: CTNContentKey];
      self.notification = [JSONObject stringForJSONKey: CTNNotificationKey];
      self.sentDate = [JSONObject dateForJSONKey: CTNSentDateKey];
      self.expiryDate = [JSONObject dateForJSONKey: CTNExpiryDateKey];
      self.provider = [JSONObject stringForJSONKey: CTNProviderKey];
      
      self.timeToLive = CTNMessageTimeToLive;
      
      if (!self.identifier)
      {
        [self setUniqueIdentifier];
      }
      
      if (!self.sentDate)
      {
        self.sentDate = [NSDate date];
      }
      
      if (!self.expiryDate)
      {
        self.expiryDate = [NSDate dateWithTimeInterval: self.timeToLive sinceDate: self.sentDate];
      }      
    }
    else
    {
      self = nil;
    }
  }
  
  return self;
}

- (id) initWithCoder: (NSCoder*) decoder
{
  if ((self = [super init]))
  {
    self.identifier = [decoder decodeObjectForKey: CTNIdentifierKey];
    self.channel = [decoder decodeObjectForKey: CTNChannelKey];
    self.subchannel = [decoder decodeObjectForKey: CTNSubchannelKey];
    self.content = [decoder decodeObjectForKey: CTNContentKey];
    self.notification = [decoder decodeObjectForKey: CTNNotificationKey];
    self.sentDate = [decoder decodeObjectForKey: CTNSentDateKey];
    self.expiryDate = [decoder decodeObjectForKey: CTNExpiryDateKey];
    self.lastTriedToSendDate = [decoder decodeObjectForKey: CTNLastTriedToSendDateKey];
    self.isDeleted = [decoder decodeBoolForKey: CTNIsDeletedKey];
    self.provider = [decoder decodeObjectForKey: CTNProviderKey];
    
    self.timeToLive = CTNMessageTimeToLive;
  }
  
  return self;
}

- (void) dealloc
{
  self.identifier = nil;
  self.channel = nil;
  self.subchannel = nil;
  self.content = nil;
  self.notification = nil;
  self.sentDate = nil;
  self.expiryDate = nil;
  self.lastTriedToSendDate = nil;
  self.provider = nil;
  self.contentReference = nil;
}

- (NSString*) channel
{
  return _channel;
}

- (void) setChannel: (NSString*) channel
{
  if (_channel != channel)
  {
    _channel = [channel lowercaseString];
  }
}

- (NSString*) subchannel
{
  return _subchannel;
}

- (void) setSubchannel: (NSString*) subchannel
{
  if (_subchannel != subchannel)
  {
    _subchannel = [subchannel lowercaseString];
  }
}

- (NSDate*) expiryDate
{
  if (_expiryDate)
  {
    return _expiryDate;
  }
  else
  {
    return [self.sentDate dateByAddingTimeInterval: self.timeToLive];
  }
}

- (void) setUniqueIdentifier
{
  CFUUIDRef uuid = CFUUIDCreate(kCFAllocatorDefault);
  CFStringRef identifier = CFUUIDCreateString(kCFAllocatorDefault, uuid);
  
  self.identifier = (__bridge NSString*) identifier;
  
  CFRelease(uuid);
  CFRelease(identifier);
}

- (BOOL) hasExpired
{
  return [self.expiryDate compare: [NSDate date]] == NSOrderedAscending;
}

- (id) JSONObject
{
  NSMutableDictionary* JSONObject = [NSMutableDictionary dictionary];
  
  [JSONObject setString: self.identifier forJSONKey: CTNIdentifierKey];
  [JSONObject setString: self.channel forJSONKey: CTNChannelKey];
  [JSONObject setString: self.subchannel forJSONKey: CTNSubchannelKey];
  [JSONObject setObject: self.content forJSONKey: CTNContentKey];
  [JSONObject setString: self.notification forJSONKey: CTNNotificationKey];
  [JSONObject setDate: self.sentDate forJSONKey: CTNSentDateKey];
  [JSONObject setDate: self.expiryDate forJSONKey: CTNExpiryDateKey];
  [JSONObject setString: self.provider forJSONKey: CTNProviderKey];
  
  return JSONObject;
}

- (NSString*) description
{
  return [NSString stringWithFormat: @"Message %@", self.identifier];
}

- (void) encodeWithCoder: (NSCoder*) encoder
{
  [encoder encodeObject: self.identifier forKey: CTNIdentifierKey];
  [encoder encodeObject: self.channel forKey: CTNChannelKey];
  [encoder encodeObject: self.subchannel forKey: CTNSubchannelKey];
  [encoder encodeObject: self.content forKey: CTNContentKey];
  [encoder encodeObject: self.notification forKey: CTNNotificationKey];
  [encoder encodeObject: self.sentDate forKey: CTNSentDateKey];
  [encoder encodeObject: self.expiryDate forKey: CTNExpiryDateKey];
  [encoder encodeObject: self.lastTriedToSendDate forKey: CTNLastTriedToSendDateKey];
  [encoder encodeBool: self.isDeleted forKey: CTNIsDeletedKey];
  [encoder encodeObject: self.provider forKey: CTNProviderKey];
}

- (BOOL) isEqualToMessage: (CTNMessage*) message
{
  return [self.identifier isEqualToString: message.identifier];
}

@end
