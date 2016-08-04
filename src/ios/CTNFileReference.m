//
//  CTNFileReference.m
//  Notifications
//
//  Created by Gary Meehan on 10/04/2015.
//  Copyright (c) 2015 CommonTime. All rights reserved.
//

#import "CTNFileReference.h"

#ifdef STATIC_LIBRARY
#import "CDVFile-Wrapper.h"
#else 
#import "CDVFile.h"
#endif

#import "CTNConstants.h"
#import "CTNUtility.h"

static NSString* CTNFileReferenceSeparator = @"#";

@interface CTNFileReference()

@property (nonatomic, readwrite, strong) NSString* path;
@property (nonatomic, readwrite, strong) id context;
@property (nonatomic, readwrite, strong) NSString* string;

@end

@implementation CTNFileReference

+ (id) fileReferenceWithString: (NSString*) string
{
  return [[CTNFileReference alloc] initWithString: string];
}

+ (id) fileReferenceWithPath: (NSString*) path
{
  return [self fileReferenceWithPath: path context: nil];
}

+ (id) fileReferenceWithPath: (NSString*) path context: (id) context
{
  return [[self alloc] initWithPath: path context: context];
}

- (id) initWithString: (NSString*) string
{
  NSString* path = nil;
  id context = nil;
  
  if ([string hasPrefix: CTNFileReferencePrefix])
  {
    NSInteger startIndex = CTNFileReferencePrefix.length;
    NSRange separatorRange = [string rangeOfString: CTNFileReferenceSeparator
                                           options: 0
                                             range: NSMakeRange(startIndex, string.length - startIndex)];
    
    if (separatorRange.location == NSNotFound)
    {
      path = [string substringFromIndex: startIndex];
    }
    else
    {
      path = [string substringWithRange: NSMakeRange(startIndex, separatorRange.location - startIndex)];
      context = CTNJSONObjectFromString([string substringFromIndex: separatorRange.location + separatorRange.length]);
    }
    
    if ([path hasPrefix: @"file://"])
    {
      NSURL* URL = [NSURL URLWithString: path];
      
      path = [URL path];
    }
    else if ([path hasPrefix: @"cdvfile://"])
    {
      CDVFile* filePlugin = [[CDVFile alloc] init];
      
      [filePlugin pluginInitialize];
      
      CDVFilesystemURL* URL = [CDVFilesystemURL fileSystemURLWithString: path];
      
      path = [filePlugin filesystemPathForURL: URL];
    }
  }
  
  if (path)
  {
    NSString* documentsDirectory = CTNDocumentsDirectory();
    NSString* rootDirectory = [documentsDirectory stringByDeletingLastPathComponent];
    
    if (![path hasPrefix: documentsDirectory] &&
        ![path hasPrefix: rootDirectory])
    {
      path = [documentsDirectory stringByAppendingString: path];
    }

    return [self initWithPath: path context: context string: string];
  }
  else
  {
    self = nil;
    
    return self;
  }
}

- (id) initWithPath: (NSString*) path
            context: (id) context
{
  NSString* documentsDirectory = CTNDocumentsDirectory();
  NSString* subPath = [path hasPrefix: documentsDirectory]
  ? [path substringFromIndex: documentsDirectory.length]
  : path;
  
  NSString* string = context
  ? [NSString stringWithFormat: @"%@%@%@%@", CTNFileReferencePrefix, subPath, CTNFileReferenceSeparator, CTNStringFromJSONObject(context)]
  : [NSString stringWithFormat: @"%@%@", CTNFileReferencePrefix, subPath];

  return [self initWithPath: path context: context string: string];
}

- (id) initWithPath: (NSString*) path
            context: (id) context
             string: string
{
  if ((self = [super init]))
  {
    if (path)
    {
      self.path = path;
      self.context = context;
      self.string = string;
    }
    else
    {
      self = nil;
    }
  }
  
  return self;
}

- (NSString*) description
{
  return self.string;
}

- (BOOL) isEqual: (id) object
{
  return [object isKindOfClass: [CTNFileReference class]] && [self isEqualToFileReference: object];
}

- (BOOL) isEqualToFileReference: (CTNFileReference*) fileReference
{
  return [self.path isEqualToString: fileReference.path];
}

- (NSUInteger) hash
{
  return [self.path hash];
}

#pragma mark - NSCopying

- (id) copyWithZone:( NSZone*) zone
{
  return [[CTNFileReference alloc] initWithPath: self.path context: self.context string: self.string];
}

@end
