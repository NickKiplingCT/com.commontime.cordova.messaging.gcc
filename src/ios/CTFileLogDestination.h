//
//  CTFileDestination.h
//  Logging
//
//  Created by Gary Meehan on 26/04/2013.
//  Copyright (c) 2013 CommonTime. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "CTLogDestination.h"

@interface CTFileLogDestination : NSObject<CTLogDestination>

@property (nonatomic, readonly) unsigned long long maximumFileSize;
@property (nonatomic, readonly) unsigned int componentCount;

- (id) initWithDirectory: (NSString*) directory;

- (NSString*) compressLogsToFile: (NSString*) filename;

- (NSString*) concatenateLogsToFile: (NSString*) filename;

- (NSData*) concatenateLogsToData;

- (void) clear;

@end
