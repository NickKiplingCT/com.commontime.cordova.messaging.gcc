//
//  CTNAzureStorageReference.m
//  Notifications
//
//  Created by Gary Meehan on 10/04/2015.
//  Copyright (c) 2015 CommonTime. All rights reserved.
//

#import "CTNAzureStorageBlobReference.h"

#import "CTNUtility.h"

NSString* CTNAzureStorageBlobReferencePrefix = @"#azureStorageBlobRef:";

static NSString* CTNAzureStorageBlobReferenceSeparator = @"#";

BOOL CTNStringContainsAzureStorageBlobReference(NSString* string)
{
  return [string hasPrefix: CTNAzureStorageBlobReferencePrefix];
}

@interface CTNAzureStorageBlobReference()

@property (nonatomic, readwrite, strong) NSURL* URL;
@property (nonatomic, readwrite, strong) id context;
@property (nonatomic, readwrite, strong) NSString* string;

@end

@implementation CTNAzureStorageBlobReference

+ (id) azureStorageBlobReferenceWithURL: (NSURL*) URL
                                context: (id) context
{
  return [[self alloc] initWithURL: URL context: context];
}

+ (id) azureStorageBlobReferenceWithString: (NSString*) string
{
  return [[self alloc] initWithString: string];
}

- (id) initWithURL: (NSURL*) URL
           context: (id) context
{
  if ((self = [super init]))
  {
    self.URL = URL;
    self.context = context;
    
    if (self.context)
    {
      self.string = [NSString stringWithFormat: @"%@%@%@%@", CTNAzureStorageBlobReferencePrefix, URL, CTNAzureStorageBlobReferenceSeparator, CTNStringFromJSONObject(self.context)];
    }
    else
    {
      self.string = [NSString stringWithFormat: @"%@%@", CTNAzureStorageBlobReferencePrefix, URL];
    }
  }
  
  return self;
}

- (id) initWithString: (NSString*) string
{
  if ((self = [super init]))
  {
    if ([string hasPrefix: CTNAzureStorageBlobReferencePrefix])
    {
      NSInteger startIndex = CTNAzureStorageBlobReferencePrefix.length;
      NSRange separatorRange = [string rangeOfString: CTNAzureStorageBlobReferenceSeparator
                                             options: 0
                                               range: NSMakeRange(startIndex, string.length - startIndex)];
      
      NSString* URLString = nil;
      
      if (separatorRange.location == NSNotFound)
      {
        URLString = [string substringFromIndex: startIndex];
      }
      else
      {
        URLString = [string substringWithRange: NSMakeRange(startIndex, separatorRange.location - startIndex)];
        self.context = CTNJSONObjectFromString([string substringFromIndex: separatorRange.location + separatorRange.length]);
      }
      
      self.URL = [NSURL URLWithString: URLString];
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

@end
