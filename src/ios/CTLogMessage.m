//
//  CTLogMessage.m
//  Logging
//
//  Created by Gary Meehan on 26/04/2013.
//  Copyright (c) 2013 CommonTime. All rights reserved.
//

#import "CTLogMessage.h"

@interface CTLogMessage()

@property (nonatomic, readwrite, assign) CTLogLevel level;
@property (nonatomic, readwrite, strong) NSString* source;
@property (nonatomic, readwrite, strong) NSString* detail;
@property (nonatomic, readwrite, strong) NSDate* date;

@end

@implementation CTLogMessage

+ (id) messageWithLevel: (CTLogLevel) level
                 source: (NSString*) source
                 detail: (NSString*) detail
{
  return [[self alloc] initWithLevel: level source: source detail: detail];
}

- (id) initWithLevel: (CTLogLevel) level
              source: (NSString*) source
              detail: (NSString*) detail
{
  if ((self = [super init]))
  {
    self.date = [NSDate date];
    self.level = level;
    self.source = source;
    self.detail = detail;
  }
  
  return self;
}

@end
