//
//  CTLogMessage.h
//  Logging
//
//  Created by Gary Meehan on 26/04/2013.
//  Copyright (c) 2013 CommonTime. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "CTLogLevel.h"

@interface CTLogMessage : NSObject

@property (nonatomic, readonly) CTLogLevel level;
@property (nonatomic, readonly) NSString* source;
@property (nonatomic, readonly) NSString* detail;
@property (nonatomic, readonly) NSDate* date;

+ (id) messageWithLevel: (CTLogLevel) level
                 source: (NSString*) source
                 detail: (NSString*) detail;

- (id) initWithLevel: (CTLogLevel) level
              source: (NSString*) source
              detail: (NSString*) detail;

@end
