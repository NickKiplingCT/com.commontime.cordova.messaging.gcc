//
//  CTLogger.m
//  Logging
//
//  Created by Gary Meehan on 26/04/2013.
//  Copyright (c) 2013 CommonTime. All rights reserved.
//

#import "CTLogger.h"

#import <CommonCrypto/CommonCryptor.h>

#import "CTLogMessage.h"

@interface CTLogger()

@property (nonatomic, readwrite, strong) NSString* source;
@property (nonatomic, readwrite, strong) NSString* name;
@property (nonatomic, readwrite, strong) NSData* key;
@property (nonatomic, readwrite, strong) NSData* initializationVector;
@property (nonatomic, readwrite, strong) NSMutableSet* destinations;

@property (nonatomic, readonly) BOOL isSecure;

@end

@implementation CTLogger

static NSMutableSet* loggers;

- (id) initWithSource: (NSString*) source name: (NSString*) name
{
  return [self initWithSource: source name: name key: nil initializationVector: nil];
}

- (id) initWithSource: (NSString*) source name: (NSString*) name key: (NSData*) key initializationVector: (NSData*) initializationVector
{
  if ((self = [super init]))
  {
    if ((key.length == 0 || key.length == 16) && (initializationVector.length == 0 || initializationVector.length == 16))
    {
      self.source = source;
      self.name = name;
      self.destinations = [NSMutableSet set];
      self.key = key;
      self.initializationVector = initializationVector;
      
      if (!loggers)
      {
        loggers = [[NSMutableSet alloc] init];
      }
      
      [loggers addObject: self];
    }
    else
    {
      self = nil;
    }
  }
  
  return self;
}

- (void) dealloc
{
  [loggers removeObject: self];
}

- (BOOL) isSecure
{
  return self.initializationVector.length > 0;
}

- (BOOL) isLoggingAtLevel: (CTLogLevel) level
{
  return self.minimumLevel <= level;
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
  }
}

- (NSSet*) allDestinations
{
  return self.destinations;
}

- (void) trace: (NSString*) detail
{
  if (self.minimumLevel <= CTLogLevelTrace && self.destinations.count > 0)
  {
    [self writeDetail: detail atLevel: CTLogLevelTrace];
  }
}

- (void) traceWithFormat: (NSString*) format, ...
{
  if (self.minimumLevel <= CTLogLevelTrace && self.destinations.count > 0)
  {
    va_list args;
    va_start(args, format);
    
    NSString* string = [[NSString alloc] initWithFormat: format arguments: args];
    
    [self writeDetail: string atLevel: CTLogLevelTrace];
    
    va_end(args);
  }
}

- (void) debug: (NSString*) detail
{
  if (self.minimumLevel <= CTLogLevelDebug && self.destinations.count > 0)
  {
    [self writeDetail: detail atLevel: CTLogLevelDebug];
  }
}

- (void) debugWithFormat: (NSString*) format, ...
{
  if (self.minimumLevel <= CTLogLevelDebug && self.destinations.count > 0)
  {
    va_list args;
    va_start(args, format);
    
    NSString* string = [[NSString alloc] initWithFormat: format arguments: args];
    
    [self writeDetail: string atLevel: CTLogLevelDebug];
    
    va_end(args);
  }
}

- (void) info: (NSString*) detail
{
  if (self.minimumLevel <= CTLogLevelInfo && self.destinations.count > 0)
  {
    [self writeDetail: detail atLevel: CTLogLevelInfo];
  }
}

- (void) infoWithFormat: (NSString*) format, ...
{
  if (self.minimumLevel <= CTLogLevelInfo && self.destinations.count > 0)
  {
    va_list args;
    va_start(args, format);
    
    NSString* string = [[NSString alloc] initWithFormat: format arguments: args];
    
    [self writeDetail: string atLevel: CTLogLevelInfo];
    
    va_end(args);
  }
}

- (void) warn: (NSString*) detail
{
  if (self.minimumLevel <= CTLogLevelWarn && self.destinations.count > 0)
  {
    [self writeDetail: detail atLevel: CTLogLevelWarn];
  }
}

- (void) warnWithFormat: (NSString*) format, ...
{
  if (self.minimumLevel <= CTLogLevelWarn && self.destinations.count > 0)
  {
    va_list args;
    va_start(args, format);
    
    NSString* string = [[NSString alloc] initWithFormat: format arguments: args];
    
    [self writeDetail: string atLevel: CTLogLevelWarn];
    
    va_end(args);
  }
}

- (void) error: (NSString*) detail
{
  if (self.minimumLevel <= CTLogLevelError && self.destinations.count > 0)
  {
    [self writeDetail: detail atLevel: CTLogLevelError];
  }
}

- (void) errorWithFormat: (NSString*) format, ...
{
  if (self.minimumLevel <= CTLogLevelError && self.destinations.count > 0)
  {
    va_list args;
    va_start(args, format);
    
    NSString* string = [[NSString alloc] initWithFormat: format arguments: args];
    
    [self writeDetail: string atLevel: CTLogLevelError];
    
    va_end(args);
  }
}

- (void) fatal: (NSString*) detail
{
  if (self.minimumLevel <= CTLogLevelFatal && self.destinations.count > 0)
  {
    [self writeDetail: detail atLevel: CTLogLevelFatal];
  }
}

- (void) fatalWithFormat: (NSString*) format, ...
{
  if (self.minimumLevel <= CTLogLevelFatal && self.destinations.count > 0)
  {
    va_list args;
    va_start(args, format);
    
    NSString* string = [[NSString alloc] initWithFormat: format arguments: args];
    
    [self writeDetail: string atLevel: CTLogLevelFatal];
    va_end(args);
  }
}

- (void) writeDetail: (NSString*) string atLevel: (CTLogLevel) level
{
  NSString* detail = self.isSecure ? [self encryptString: string] : string;
  CTLogMessage* message = [CTLogMessage messageWithLevel: level
                                                  source: self.source
                                                  detail: detail];
  
  for (id<CTLogDestination> destination in self.destinations)
  {
    [destination writeMessage: message];
  }
}

- (NSString*) encryptString: (NSString*) plainText
{
  NSData* plainTextData = [plainText dataUsingEncoding: NSUTF8StringEncoding];
  NSData* cryptTextData = [self encryptData: plainTextData];
  
  return [cryptTextData base64EncodedStringWithOptions: 0];
}

- (NSData*) encryptData: (NSData*) data
{
  /*
  uint8_t key[] =
  { 0xb4, 0x2a, 0x73, 0x73, 0xc7, 0xf1, 0x4c, 0xa3,
    0x99, 0x09, 0x5b, 0x06, 0xbe, 0xc9, 0xc6, 0x78 };
  
  uint8_t iv[] =
  { 0xd0, 0x7b, 0x6b, 0xaf, 0x86, 0x5d, 0x47, 0x19,
    0xaa, 0x80, 0xef, 0x87, 0xc7, 0x24, 0x19, 0xb };
 */
  
  if (!data)
  {
    return nil;
  }
  
  CCCryptorRef cryptor = NULL;
  CCCryptorStatus status = CCCryptorCreate(kCCEncrypt,
                                           kCCAlgorithmAES,
                                           kCCOptionPKCS7Padding,
                                           [self.key bytes],
                                           self.key.length,
                                           self.initializationVector.length == 16 ? [self.initializationVector bytes] : NULL,
                                           &cryptor);
  
  NSData* outputData = nil;
  
  if (status == kCCSuccess)
  {
    size_t bufsize = CCCryptorGetOutputLength(cryptor,
                                              (size_t) [data length],
                                              true);
    
    void * buf = malloc(bufsize);
    size_t bufused = 0;
    size_t bytesTotal = 0;
    
    status = CCCryptorUpdate(cryptor,
                             [data bytes],
                             (size_t) [data length],
                             buf,
                             bufsize,
                             &bufused);
    
    if (status == kCCSuccess)
    {
      bytesTotal += bufused;
      
      status = CCCryptorFinal( cryptor, buf + bufused, bufsize - bufused, &bufused );
      
      if (status == kCCSuccess)
      {
        bytesTotal += bufused;
        outputData = [NSData dataWithBytesNoCopy: buf length: bytesTotal];
      }
      else
      {
        free(buf);
      }
    }
    else
    {
      free(buf);
    }
    
    CCCryptorRelease(cryptor);
  }
  
  return outputData;
}

@end
