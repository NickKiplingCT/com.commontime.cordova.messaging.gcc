//
//  CTLogManager.h
//  Logging
//
//  Created by Gary Meehan on 27/11/2015.
//  Copyright © 2015 CommonTime. All rights reserved.
//

#import <Foundation/Foundation.h>

@class CTConsoleLogDestination;
@class CTFileLogDestination;
@class CTLogger;

@protocol CTLogDestination;

@protocol CTLogManagerDelegate

- (void) sendLogsWithSubject: (NSString*) subject recipient: (NSString*) recipient;

- (void) uploadLogsToURL: (NSURL*) URL;

@end

@interface CTLogManager : NSObject

@property (nonatomic, readwrite, weak) id<CTLogManagerDelegate> delegate;

@property (nonatomic, readonly) CTLogger* applicationLogger;
@property (nonatomic, readonly) CTLogger* frameworkLogger;
@property (nonatomic, readonly) CTLogger* shellLogger;
@property (nonatomic, readonly) CTLogger* secureLogger;

@property (nonatomic, readonly) CTConsoleLogDestination* consoleLogDestination;
@property (nonatomic, readonly) CTFileLogDestination* fileLogDestination;

+ (CTLogManager*) sharedManager;

- (void) start;

- (void) stop;

- (NSArray*) allLoggers;

- (NSArray*) allDestinations;

- (void) addLogger: (CTLogger*) logger;

- (void) removeLogger: (CTLogger*) logger;

- (void) addDestination: (id<CTLogDestination>) destination;

- (void) removeDestination: (id<CTLogDestination>) destination;

- (CTLogger*) loggerWithName: (NSString*) name;

@end
