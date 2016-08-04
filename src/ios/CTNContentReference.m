//
//  CTNContentReference.m
//  Notifications
//
//  Created by Gary Meehan on 14/04/2015.
//  Copyright (c) 2015 CommonTime. All rights reserved.
//

#import "CTNContentReference.h"

#import "CTNConstants.h"
#import "CTNUtility.h"

@interface CTNContentReference()

@property (nonatomic, readwrite, strong) NSString* path;
@property (nonatomic, readwrite, strong) NSString* string;

@end@implementation CTNContentReference

+ (id) contentReferenceWithPath: (NSString*) path
{
  return [[self alloc] initWithPath: path];
}

+ (id) contentReferenceWithContent: (id) content
{
  return [[self alloc] initWithContent: content];
}

- (id) initWithPath: (NSString*) path
{
  if ((self = [super init]))
  {
    NSRange range = [path rangeOfString: CTNDocumentsDirectory()];
    
    if (range.location == 0)
    {
      NSString* subpath = [path substringFromIndex: range.length];
      
      self.string = [NSString stringWithFormat: @"%@%@", CTNContentReferencePrefix, subpath];
    }
    else
    {
      self.string = [NSString stringWithFormat: @"%@%@", CTNContentReferencePrefix, path];
    }
    
    self.path = path;
  }

  return self;
}

- (id) initWithContent: (id) content
{
  if ((self = [super init]))
  {
    if ([content isKindOfClass: [NSString class]] && [content hasPrefix: CTNContentReferencePrefix])
    {
      NSString* subpath = [content substringFromIndex: CTNContentReferencePrefix.length];
     
      if ([subpath hasPrefix: CTNDocumentsDirectory()])
      {
        self.path = subpath;
      }
      else
      {
        self.path = [CTNDocumentsDirectory() stringByAppendingPathComponent: subpath];
      }
      
      self.string = content;
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

@end
