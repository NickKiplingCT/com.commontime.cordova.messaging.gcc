//
//  CTFileDestination.m
//  Logging
//
//  Created by Gary Meehan on 26/04/2013.
//  Copyright (c) 2013 CommonTime. All rights reserved.
//

#import "CTFileLogDestination.h"

#import "ZipArchive.h"

#import "CTLogLevel.h"
#import "CTLogMessage.h"

@interface  CTFileLogDestination()

@property (nonatomic, readwrite, strong) NSOutputStream* stream;
@property (nonatomic, readwrite, strong) NSString* logDirectory;
@property (nonatomic, readwrite, strong) NSString* pathFormat;
@property (nonatomic, readwrite, assign) unsigned long long currentSize;
@property (nonatomic, readwrite, strong) NSDateFormatter* dateFormatter;

@property (nonatomic, readwrite, assign) unsigned long long maximumFileSize;
@property (nonatomic, readwrite, assign) unsigned int componentCount;
@property (nonatomic, readonly) unsigned long long componentSize;

@end

@implementation CTFileLogDestination

- (id) initWithDirectory: (NSString*) directory
{
  if (directory)
  {  
    if ((self = [super init]))
    {
      self.logDirectory = directory;
      self.pathFormat = [self.logDirectory stringByAppendingPathComponent: @"log-%u.log"];
      
      self.maximumFileSize = 1024 * 1024;
      self.componentCount = 8;
      
      self.currentSize = 0;
      
      self.dateFormatter = [[NSDateFormatter alloc] init];
      self.dateFormatter.dateFormat = @"yyyy-MM-dd HH:mm:ss.SSS";
    }
  }
  else
  {
    self = nil;
  }

  return self;
}

- (void) dealloc
{
  [self close];
}

- (unsigned long long) componentSize
{
  return self.maximumFileSize / self.componentCount;
}

- (void) rollover
{
  [self close];
  
  NSFileManager* fileManager = [NSFileManager defaultManager];
  NSString* discardedPath = [NSString stringWithFormat: self.pathFormat, self.componentCount - 1];
  
  if ([fileManager fileExistsAtPath: discardedPath])
  {
    [fileManager removeItemAtPath: discardedPath error: NULL];
  }
  
  for (unsigned int i = self.componentCount - 1; i > 0; --i)
  {
    NSString* oldPath = [NSString stringWithFormat: self.pathFormat, i - 1];
    NSString* newPath = [NSString stringWithFormat: self.pathFormat, i];
    
    if ([fileManager fileExistsAtPath: oldPath])
    {
      [fileManager moveItemAtPath: oldPath toPath: newPath error: NULL];
    }
  }

  NSString* currentPath = [NSString stringWithFormat: self.pathFormat, 0];
  
  [fileManager removeItemAtPath: currentPath error: NULL];  
  
  self.currentSize = 0;
}

- (void) writeMessage: (CTLogMessage*) message
{
  if (!self.logDirectory)
  {
    return;
  }
  
  NSString* line = [NSString stringWithFormat: @"%@ %@ %@ - %@\r\n",
                    [self.dateFormatter stringFromDate: message.date],
                    message.source,
                    CTLogLevelPaddedDescription(message.level),
                    message.detail];
  
  NSData* data = [line dataUsingEncoding: NSUTF8StringEncoding];
  NSUInteger size = [data length];
  
  if (!self.stream)
  {
    [self open];
  }

  if (self.currentSize + size > self.componentSize)
  {
    [self rollover];
  }
  
  [self.stream write: [data bytes] maxLength: [data length]];
  self.currentSize += size;
}

- (void) open
{
  NSFileManager* fileManager = [[NSFileManager alloc] init];
  NSError* error = nil;
  
  if (![fileManager fileExistsAtPath: self.logDirectory])
  {
    if (![fileManager createDirectoryAtPath: self.logDirectory
                withIntermediateDirectories: NO
                                 attributes: nil
                                      error: &error])
    {
      NSLog(@"Cannot create log directory at %@: %@", self.logDirectory, error);
      
      return;
    }
  }
  
  NSString* path = [NSString stringWithFormat: self.pathFormat, 0];
  
  self.stream = [[NSOutputStream alloc] initToFileAtPath: path append: YES];
  [self.stream open];
  
  NSDictionary* attributes = [fileManager attributesOfItemAtPath: path error: &error];
  
  if (!attributes)
  {
    NSLog(@"Cannot create log file at %@: %@", path, error);
    
    return;
  }
  
  self.currentSize = [attributes fileSize];
}

- (void) close
{
  [self.stream close];
  self.stream = nil;
}

- (NSString*) concatenateLogsToFile: (NSString*) filename
{
  NSString* path = [self.logDirectory stringByAppendingPathComponent: filename];
  NSOutputStream* outputStream = [NSOutputStream outputStreamToFileAtPath: path append: NO];
  
  if (outputStream)
  {
    [outputStream open];
    [self concatenateLogsToStream: outputStream];
    [outputStream close];
    
    return path;
  }
  else
  {
    return nil;
  }
}

- (NSData*) concatenateLogsToData
{
  NSOutputStream* outputStream = [NSOutputStream outputStreamToMemory];
  
  if (outputStream)
  {
    [outputStream open];
    [self concatenateLogsToStream: outputStream];
    [outputStream close];

    return [outputStream propertyForKey: NSStreamDataWrittenToMemoryStreamKey];
  }
  else
  {
    return nil;
  }
}

- (void) concatenateLogsToStream: (NSOutputStream*) outputStream
{
  for (unsigned int i = self.componentCount; i > 0; --i)
  {
    NSString* path = [NSString stringWithFormat: self.pathFormat, i - 1];
    
    [self copyFileAtPath: path toStream: outputStream];
  }
}

- (void) copyFileAtPath: (NSString*) path
               toStream: (NSOutputStream*) outputStream
{
  NSInputStream* inputStream = [NSInputStream inputStreamWithFileAtPath: path];
  
  if (inputStream)
  {
    [inputStream open];
    [self copyStream: inputStream toStream: outputStream];
    [inputStream close];
  }
}

- (void) copyStream: (NSInputStream*) inputStream
           toStream: (NSOutputStream*) outputStream
{
  for (;;)
  {
    uint8_t buffer[64 * 1024];
    NSInteger bytesRead = [inputStream read: buffer maxLength: sizeof(buffer)];
    
    if (bytesRead > 0)
    {
      [self copyBytes: buffer length: bytesRead toStream: outputStream];
    }
    else
    {
      break;
    }
  }
}

- (void) copyBytes: (uint8_t*) bytes
            length: (NSInteger) length
          toStream: (NSOutputStream*) outputStream
{
  while (length > 0)
  {
    NSInteger bytesWritten = [outputStream write: bytes maxLength: length];
    
    if (bytesWritten > 0)
    {
      length -= bytesWritten;
      bytes += bytesWritten;
    }
    else
    {
      break;
    }
  }
}

- (NSString*) compressLogsToFile: (NSString*) filename
{
  NSString* path = [self.logDirectory stringByAppendingPathComponent: filename];
  ZipArchive* zipArchive = [[ZipArchive alloc] initWithFileManager: [NSFileManager defaultManager]];
  
  [zipArchive CreateZipFile2: path];
  
  NSData* data = [self concatenateLogsToData];
  
  [zipArchive addDataToZip: data fileAttributes: nil newname: @"mDesign.log"];
  [zipArchive CloseZipFile2];
  
  return path;
}

- (void) clear
{
  [self close];
  
  NSFileManager* fileManager = [NSFileManager defaultManager];
  
  for (unsigned int i = self.componentCount; i > 0; --i)
  {
    NSString* path = [NSString stringWithFormat: self.pathFormat, i - 1];
    
    [fileManager removeItemAtPath: path error: NULL];
  }
  
  [self open];
}

@end
