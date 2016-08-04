//
//  CTLogger.h
//  Logging
//
//  Created by Gary Meehan on 26/04/2013.
//  Copyright (c) 2013 CommonTime. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "CTLogDestination.h"
#import "CTLogLevel.h"

@interface CTLogger : NSObject

@property (nonatomic, readonly) NSString* source;
@property (nonatomic, readonly) NSString* name;

@property (nonatomic, readwrite, assign) CTLogLevel minimumLevel;

- (id) initWithSource: (NSString*) source name: (NSString*) name;

- (id) initWithSource: (NSString*) source name: (NSString*) name key: (NSData*) key initializationVector: (NSData*) initializationVector;

- (BOOL) isLoggingAtLevel: (CTLogLevel) level;

- (void) addDestination: (id<CTLogDestination>) destination;

- (void) removeDestination: (id<CTLogDestination>) destination;

- (NSSet*) allDestinations;

- (void) trace: (NSString*) detail;

- (void) traceWithFormat: (NSString*) format, ... NS_FORMAT_FUNCTION(1, 2);

- (void) debug: (NSString*) detail;

- (void) debugWithFormat: (NSString*) format, ... NS_FORMAT_FUNCTION(1, 2);

- (void) info: (NSString*) detail;

- (void) infoWithFormat: (NSString*) format, ... NS_FORMAT_FUNCTION(1, 2);

- (void) warn: (NSString*) detail;

- (void) warnWithFormat: (NSString*) format, ... NS_FORMAT_FUNCTION(1, 2);

- (void) error: (NSString*) detail;

- (void) errorWithFormat: (NSString*) format, ... NS_FORMAT_FUNCTION(1, 2);

- (void) fatal: (NSString*) detail;

- (void) fatalWithFormat: (NSString*) format, ... NS_FORMAT_FUNCTION(1, 2);

- (void) writeDetail: (NSString*) string atLevel: (CTLogLevel) level;

@end
