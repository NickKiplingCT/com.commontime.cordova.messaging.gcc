//
//  CTLogManager.m
//  Logging
//
//  Created by Gary Meehan on 27/11/2015.
//  Copyright © 2015 CommonTime. All rights reserved.
//

#import "CTLogManager.h"

#import "CTLogger.h"
#import "CTConsoleLogDestination.h"
#import "CTFileLogDestination.h"
#import "CTLogDestination.h"

@interface CTLogManager()

@property (nonatomic, readwrite, strong) NSMutableArray* loggers;
@property (nonatomic, readwrite, strong) NSMutableArray* destinations;

@property (nonatomic, readwrite, strong) CTLogger* applicationLogger;
@property (nonatomic, readwrite, strong) CTLogger* frameworkLogger;
@property (nonatomic, readwrite, strong) CTLogger* shellLogger;
@property (nonatomic, readwrite, strong) CTLogger* secureLogger;

@property (nonatomic, readwrite, strong) CTConsoleLogDestination* consoleLogDestination;
@property (nonatomic, readwrite, strong) CTFileLogDestination* fileLogDestination;

@end

@implementation CTLogManager

+ (CTLogManager*) sharedManager
{
  static CTLogManager* instance = nil;
  static dispatch_once_t onceToken = 0;
  
  dispatch_once(&onceToken, ^{
    instance = [[CTLogManager alloc] init];
  });
  
  return instance;
}

- (id) init
{
  if ((self = [super init]))
  {
    self.loggers = [NSMutableArray array];
    self.destinations = [NSMutableArray array];
  }
  
  return self;
}

- (void) dealloc
{
  [self stop];
}

- (void) start
{
  [self startConsoleLogDestination];
  [self startFileLogDestination];
  
  [self startApplicationLogger];
  [self startFrameworkLogger];
  [self startSecureLogger];
  [self startShellLogger]; 
}

- (void) startApplicationLogger
{
  if (self.applicationLogger)
  {
    return;
  }
  
  self.applicationLogger = [[CTLogger alloc] initWithSource: @"APP" name: @"application"];
  [self.applicationLogger addDestination: self.consoleLogDestination];
  [self.applicationLogger addDestination: self.fileLogDestination];
  [self addLogger: self.applicationLogger];
}

- (void) startFrameworkLogger
{
  if (self.frameworkLogger)
  {
    return;
  }
  
  self.frameworkLogger = [[CTLogger alloc] initWithSource: @"FWK" name: @"framework"];
  [self.frameworkLogger addDestination: self.consoleLogDestination];
  [self.frameworkLogger addDestination: self.fileLogDestination];
  [self addLogger: self.frameworkLogger];
}

- (void) startShellLogger
{
  if (self.shellLogger)
  {
    return;
  }
  
  self.shellLogger = [[CTLogger alloc] initWithSource: @"SHL" name: @"shell"];
  [self.shellLogger addDestination: self.consoleLogDestination];
  [self.shellLogger addDestination: self.fileLogDestination];
  [self addLogger: self.shellLogger];
}

- (void) startSecureLogger
{
  if (self.secureLogger)
  {
    return;
  }
  
  uint8_t key[] = { 0xb4, 0x2a, 0x73, 0x73, 0xc7, 0xf1, 0x4c, 0xa3, 0x99, 0x09, 0x5b, 0x06, 0xbe, 0xc9, 0xc6, 0x78 };
  uint8_t iv[] = { 0xd0, 0x7b, 0x6b, 0xaf, 0x86, 0x5d, 0x47, 0x19, 0xaa, 0x80, 0xef, 0x87, 0xc7, 0x24, 0x19, 0xb };
  
  self.secureLogger = [[CTLogger alloc] initWithSource: @"SEC"
                                                  name: @"secure"
                                                   key: [NSData dataWithBytes: key length: sizeof(key)]
                                  initializationVector: [NSData dataWithBytes: iv length: sizeof(iv)]];
  
  [self.secureLogger addDestination: self.consoleLogDestination];
  [self.secureLogger addDestination: self.fileLogDestination];
  [self addLogger: self.secureLogger];
}

- (void) startConsoleLogDestination
{
  if (self.consoleLogDestination)
  {
    return;
  }
  
  self.consoleLogDestination = [[CTConsoleLogDestination alloc] init];
  [self addDestination: self.consoleLogDestination];
}

- (void) startFileLogDestination
{
  if (self.fileLogDestination)
  {
    return;
  }
  
  NSArray* paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
  
  if (paths.count > 0)
  {
    NSString* baseDirectory = [paths objectAtIndex: 0];
    NSString* logDirectory = [baseDirectory stringByAppendingPathComponent: @"Logs"];
    
    self.fileLogDestination = [[CTFileLogDestination alloc] initWithDirectory: logDirectory];
    [self addDestination: self.fileLogDestination];
  }
}

- (void) stop
{
  self.loggers = nil;
  self.destinations = nil;
  
  self.applicationLogger = nil;
  self.frameworkLogger = nil;
  self.shellLogger = nil;
  self.secureLogger = nil;
}

- (NSArray*) allLoggers
{
  return self.loggers;
}

- (NSArray*) allDestinations
{
  return self.destinations;
}

- (void) addLogger: (CTLogger*) logger
{
  if (logger)
  {
    [self.loggers addObject: logger];
  }
}

- (void) removeLogger: (CTLogger*) logger
{
  if (logger)
  {
    [self.loggers removeObject: logger];
    
    if (logger == self.applicationLogger)
    {
      self.applicationLogger = nil;
    }
    else if (logger == self.frameworkLogger)
    {
      self.frameworkLogger = nil;
    }
    else if (logger == self.shellLogger)
    {
      self.shellLogger = nil;
    }
    else if (logger == self.secureLogger)
    {
      self.secureLogger = nil;
    }
  }
}

- (void) addDestination: (id<CTLogDestination>) destination
{
  if (destination)
  {
    [self.destinations addObject: destination];
  }
}

- (void) removeDestination: (id<CTLogDestination>) destination
{
  if (destination)
  {
    [self.destinations removeObject: destination];
    
    if (destination == self.consoleLogDestination)
    {
      self.consoleLogDestination = nil;
    }
    else if (destination == self.fileLogDestination)
    {
      self.fileLogDestination = nil;
    }
  }
}

- (CTLogger*) loggerWithName: (NSString*) name
{
  for (CTLogger* logger in self.loggers)
  {
    if ([logger.name compare: name options: NSCaseInsensitiveSearch] == NSOrderedSame)
    {
      return logger;
    }
  }
  
  return nil;
}

@end
