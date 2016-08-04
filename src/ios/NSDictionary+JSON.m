//
//  NSDictionary+JSON.m
//  Notifications
//
//  Created by Gary Meehan on 20/11/2012.
//  Copyright (c) 2012 CommonTime. All rights reserved.
//

#import "NSDictionary+JSON.h"

@implementation NSDictionary(JSON)

+ (id) dictionaryWithJSONString: (NSString*) string
{
  NSData* data = [string dataUsingEncoding: NSUTF8StringEncoding];
  
  return [NSJSONSerialization JSONObjectWithData: data
                                         options: 0
                                           error: NULL];
}

- (NSDate*) dateForJSONKey: (NSString*) key
{
  id value = [self objectForKey: key];
  
  if ([value isKindOfClass: [NSNumber class]])
  {
    return [NSDate dateWithTimeIntervalSince1970: [value doubleValue] / 1000];
  }
  else
  {
    return nil;
  }
}

- (NSString*) stringForJSONKey: (NSString*) key
{
  id value = [self objectForKey: key];
  
  if ([value isKindOfClass: [NSString class]])
  {
    return value;
  }
  else
  {
    return nil;
  }
}

- (id) objectForJSONKey: (NSString*) key
{
  id value = [self objectForKey: key];

  if ([value isKindOfClass: [NSNull class]])
  {
    return nil;
  }
  else
  {
    return value;
  }
}

- (NSInteger) integerForJSONKey: (NSString*) key
{
  id value = [self objectForKey: key];
  
  if ([value isKindOfClass: [NSNumber class]])
  {
    return [value integerValue];
  }
  else
  {
    return 0;
  }
}

- (double) doubleForJSONKey: (NSString*) key
{
  id value = [self objectForKey: key];
  
  if ([value isKindOfClass: [NSNumber class]])
  {
    return [value doubleValue];
  }
  else
  {
    return 0.0;
  }
}

- (long long) longLongForJSONKey: (NSString*) key
{
  id value = [self objectForKey: key];
  
  if ([value isKindOfClass: [NSNumber class]])
  {
    return [value longLongValue];
  }
  else
  {
    return 0;
  }
}

- (BOOL) boolForJSONKey: (NSString*) key
{
  id value = [self objectForKey: key];
  
  if ([value isKindOfClass: [NSNumber class]])
  {
    return [value boolValue];
  }
  else
  {
    return NO;
  }
}

- (NSArray*) arrayForJSONKey: (NSString*) key
{
  id value = [self objectForKey: key];
  
  if ([value isKindOfClass: [NSArray class]])
  {
    return value;
  }
  else
  {
    return nil;
  }
}

- (NSString*) JSONString
{
  NSData* data = [NSJSONSerialization dataWithJSONObject: self
                                                 options: 0
                                                   error: NULL];
  
  return  [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
}

@end

@implementation NSMutableDictionary(JSON)

- (void) setObject: (id) value forJSONKey: (NSString*) key
{
  if (value)
  {
    [self setObject: value forKey: key];
  }
  else
  {
    [self removeObjectForKey: key];
  }
}

- (void) setDate: (NSDate*) value forJSONKey: (NSString*) key
{
  if (value)
  {
    [self setLongLong: [value timeIntervalSince1970] * 1000L forJSONKey: key];
  }
  else
  {
    [self removeObjectForKey: key];
  }
}

- (void) setString: (NSString*) value forJSONKey: (NSString*) key
{
  if (value)
  {
    [self setObject: value forKey: key];
  }
  else
  {
    [self removeObjectForKey: key];
  }
}

- (void) setInteger: (NSInteger) value forJSONKey: (NSString*) key
{
  [self setObject: [NSNumber numberWithInteger: value] forKey: key];
}

- (void) setDouble: (double) value forJSONKey: (NSString*) key
{
  [self setObject: [NSNumber numberWithDouble: value] forKey: key];
}

- (void) setLongLong: (long long) value forJSONKey: (NSString*) key
{
  [self setObject: [NSNumber numberWithLongLong: value] forKey: key];
}

- (void) setArray: (NSArray*) value forJSONKey: (NSString*) key
{
  [self setObject: value forKey: key];
}

- (void) setBool: (BOOL) value forJSONKey: (NSString*) key
{
  [self setObject: [NSNumber numberWithBool: value] forKey: key];
}

@end
