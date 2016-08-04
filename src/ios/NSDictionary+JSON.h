//
//  NSDictionary+JSON.h
//  Notifications
//
//  Created by Gary Meehan on 20/11/2012.
//  Copyright (c) 2012 CommonTime. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSDictionary(JSON)

+ (id) dictionaryWithJSONString: (NSString*) string;

- (id) objectForJSONKey: (NSString*) key;

- (NSDate*) dateForJSONKey: (NSString*) key;

- (NSString*) stringForJSONKey: (NSString*) key;

- (NSInteger) integerForJSONKey: (NSString*) key;

- (double) doubleForJSONKey: (NSString*) key;

- (long long) longLongForJSONKey: (NSString*) key;

- (NSArray*) arrayForJSONKey: (NSString*) key;

- (BOOL) boolForJSONKey: (NSString*) key;

- (NSString*) JSONString;

@end

@interface NSMutableDictionary(JSON)

- (void) setObject: (id) value forJSONKey: (NSString*) key;

- (void) setDate: (NSDate*) value forJSONKey: (NSString*) key;

- (void) setString: (NSString*) value forJSONKey: (NSString*) key;

- (void) setInteger: (NSInteger) value forJSONKey: (NSString*) key;

- (void) setDouble: (double) value forJSONKey: (NSString*) key;

- (void) setLongLong: (long long) value forJSONKey: (NSString*) key;

- (void) setArray: (NSArray*) value forJSONKey: (NSString*) key;

- (void) setBool: (BOOL) value forJSONKey: (NSString*) key;

@end
