//
//  Messages.h
//  AzureTester
//
//  Created by Gary Meehan on 29/10/2012.
//  Copyright (c) 2012 CommonTime. All rights reserved.
//

#import <Foundation/Foundation.h>

@class CTNContentReference;

@interface CTNMessage : NSObject<NSCoding>
{
@private
  NSString* _channel;
  NSString* _subchannel;
}

@property (nonatomic, readwrite, strong) NSString* identifier;
@property (nonatomic, readwrite, strong) NSString* channel;
@property (nonatomic, readwrite, strong) NSString* subchannel;
@property (nonatomic, readwrite, strong) id content;
@property (nonatomic, readwrite, strong) CTNContentReference* contentReference;
@property (nonatomic, readwrite, strong) NSString* notification;
@property (nonatomic, readwrite, strong) NSDate* sentDate;
@property (nonatomic, readwrite, strong) NSDate* expiryDate;
@property (nonatomic, readwrite, strong) NSString* provider;

@property (nonatomic, readwrite, assign) NSTimeInterval timeToLive;
@property (nonatomic, readwrite, strong) NSDate* lastTriedToSendDate;

@property (nonatomic, readwrite) BOOL isDeleted;

@property (nonatomic, readonly) BOOL hasExpired;

+ (id) message;

+ (id) messageWithJSONObject: (id) JSONObject;

- (id) initWithJSONObject: (id) JSONObject;

- (id) JSONObject;

- (void) setUniqueIdentifier;

- (BOOL) isEqualToMessage: (CTNMessage*) message;

@end
