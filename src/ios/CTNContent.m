//
//  CTNContent.m
//  Notifications
//
//  Created by Gary Meehan on 14/04/2015.
//  Copyright (c) 2015 CommonTime. All rights reserved.
//

#import "CTNContent.h"

#import "CTLogger.h"

#import "CTNAzureStorageBlobReference.h"
#import "CTNConstants.h"
#import "CTNFileReference.h"
#import "CTNNotificationProviderManager.h"
#import "CTNUtility.h"

@implementation NSObject(CTNContent)

- (id) copyByApplyingBlock: (id (^)(id object, NSError** error)) block
                     error: (NSError**) error
{
  return block(self, error);
}

- (BOOL) applyBlock: (BOOL (^)(id object, NSError** error)) block
              error: (NSError**) error
{
  return block(self, error);
}

- (BOOL) anyMemberSatisfiesPredicate: (BOOL (^)(id object)) predicate
{
  return predicate(self);
}

- (BOOL) containsFileData
{
  BOOL (^isFileData)(id) = ^BOOL(id object)
  {
    return [object isKindOfClass: [NSString class]] && [object hasPrefix: CTNFileDataPrefix];
  };
  
  return [self anyMemberSatisfiesPredicate: isFileData];
}

- (BOOL) containsFileReferences
{
  BOOL (^isFileReference)(id) = ^BOOL(id object)
  {
    return [object isKindOfClass: [NSString class]] && [object hasPrefix: CTNFileReferencePrefix];
  };
  
  return [self anyMemberSatisfiesPredicate: isFileReference];
}

- (NSArray*) allFileReferences
{
  NSMutableArray* references = [NSMutableArray array];
  
  BOOL (^aggregateFileReferences)(id, NSError**) = ^(id object, NSError** error)
  {
    if ([object isKindOfClass: [NSString class]])
    {
      CTNFileReference* fileReference = [CTNFileReference fileReferenceWithString: object];
      
      if (fileReference)
      {
        [references addObject: fileReference];
      }
    }
    
    return YES;
  };
  
  [self applyBlock: aggregateFileReferences error: NULL];
  
  return references;
}

- (id) copyByExpandingFileReferencesWithError: (NSError**) error
{
  id (^expandFileReference)(id, NSError**) = ^id(id object, NSError** error)
  {
    if ([object isKindOfClass: [NSString class]])
    {
      CTNFileReference* fileReference = [CTNFileReference fileReferenceWithString: object];
      
      if (fileReference)
      {
        NSData* data = [NSData dataWithContentsOfFile: fileReference.path options: 0 error: error];
        
        if (!data)
        {
          [[CTNNotificationProviderManager sharedManager].logger warnWithFormat: @"Cannot load data referred to by %@: %@", object, [*error localizedDescription]];
          
          return nil;
        }
        
        NSString* base64 = [data base64EncodedStringWithOptions: 0];
        
        [[CTNNotificationProviderManager sharedManager].logger traceWithFormat: @"Expanded %@ to Base64 data of size %@", object, CTNFormatBytes([base64 length])];
        
        return [[NSString alloc] initWithFormat: @"%@%@", CTNFileDataPrefix, base64];
      }
    }

    return [object copy];
  };
  
  return [self copyByApplyingBlock: expandFileReference error: error];
}

- (id) copyByExtractingFileDataWithError: (NSError**) error
{
  id (^extractFileData)(id, NSError**) = ^id(id object, NSError** error)
  {
    if ([object isKindOfClass: [NSString class]])
    {
      NSRange range = [object rangeOfString: CTNFileDataPrefix];
      
      if (range.location != 0)
      {
        return [object copy];
      }
      
      NSString* path = CTNUniquePathWithExtension(@"bin");
      
      if (!path)
      {
        return nil;
      }
      
      NSString* substring = [object substringFromIndex: range.length];
      NSData* data = [[NSData alloc] initWithBase64EncodedString: substring options: 0];
      
      if (![data writeToFile: path options: NSDataWritingAtomic error: error])
      {
        return nil;
      }
      
      CTNFileReference* fileReference = [CTNFileReference fileReferenceWithPath: path];
      
      return [fileReference.description copy];
    }
    else
    {
      return [object copy];
    }
  };
  
  return [self copyByApplyingBlock: extractFileData error: error];
}

- (BOOL) deleteFilesWithError: (NSError**) error
{
  BOOL (^deleteFile)(id, NSError**) = ^BOOL(id object, NSError** error)
  {
    if ([object isKindOfClass: [NSString class]])
    {
      CTNFileReference* fileReference = [CTNFileReference fileReferenceWithString: object];
      
      if (fileReference)
      {
        [[CTNNotificationProviderManager sharedManager].logger traceWithFormat: @"Removing file referred to by %@", object];
        
        [[NSFileManager defaultManager] removeItemAtPath: fileReference.path error: NULL];
      }
    }
    
    return YES;
  };
  
  return [self applyBlock: deleteFile error: error];
}

- (id) copyByCopyingFileReferencesWithError: (NSError**) error
{
  id (^copyFileReference)(id, NSError**) = ^id(id object, NSError** error)
  {
    if ([object isKindOfClass: [NSString class]])
    {
      CTNFileReference* fileReference = [CTNFileReference fileReferenceWithString: object];
      
      if (fileReference)
      {
        NSString* extension = [fileReference.path pathExtension];
        NSString* destinationPath = CTNUniquePathWithExtension(extension);
        NSFileManager* fileManager = [NSFileManager defaultManager];
        
        if ([fileManager copyItemAtPath: fileReference.path toPath: destinationPath error: error])
        {
          CTNFileReference* newFileReference = [CTNFileReference fileReferenceWithPath: destinationPath context: fileReference.context];
          
          [[CTNNotificationProviderManager sharedManager].logger traceWithFormat: @"Copied resource at %@ to %@", fileReference, newFileReference];
          
          return [newFileReference.string copy];
        }
        else
        {
          return nil;
        }
      }
    }

    return [object copy];
  };
  
  return [self copyByApplyingBlock: copyFileReference error: error];
}

- (id) copyByReplacingFileReference: (CTNFileReference*) sourceFileReference
      withAzureStorageBlobReference: (CTNAzureStorageBlobReference*) destinationStorageReference
                              error: (NSError**) error
{
  id (^replaceFileReference)(id, NSError**) = ^id(id object, NSError** error)
  {
    if ([object isKindOfClass: [NSString class]])
    {
      CTNFileReference* fileReference = [CTNFileReference fileReferenceWithString: object];
      
      if ([fileReference isEqualToFileReference: sourceFileReference])
      {
        return [destinationStorageReference.string copy];
      }
    }
    
    return [object copy];
  };
  
  return [self copyByApplyingBlock: replaceFileReference error: error];
}

- (BOOL) containsNonStandardJSON
{
  return !([self isKindOfClass: [NSString class]] ||
           [self isKindOfClass: [NSNumber class]] ||
           [self isKindOfClass: [NSNull class]] ||
           [self isKindOfClass: [NSDictionary class]] ||
           [self isKindOfClass: [NSArray class]]);
}

- (id) copyByConvertingToStandardJSONWithError: (NSError**) error
{
  id (^convertToJSON)(id, NSError**) = ^id(id object, NSError** error)
  {
    if ([object isKindOfClass: [NSDate class]])
    {
      static NSDateFormatter* dateFormatter = nil;
      static dispatch_once_t onceToken = 0;
      
      dispatch_once(&onceToken, ^{
        dateFormatter = [[NSDateFormatter alloc] init];
        dateFormatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'";
      });
      
      return [dateFormatter stringFromDate: object];
    }
    else if ([object isKindOfClass: [NSString class]] || [object isKindOfClass: [NSNumber class]] || [object isKindOfClass: [NSNull class]])
    {
      return [object copy];
    }
    else
    {
      if (error)
      {
        *error = [NSError errorWithDomain: CTNErrorDomain
                                     code: CTNConversionError
                                 userInfo: @{NSLocalizedDescriptionKey: @"Unexpected type"}];
      }
      
      return nil;
    }
  };
  
  return [self copyByApplyingBlock: convertToJSON error: error];
}
           
@end

@implementation NSArray(CTNContent)

- (id) copyByApplyingBlock: (id (^)(id object, NSError**)) block
                     error: (NSError**) error
{
  NSMutableArray* destination = [[NSMutableArray alloc] initWithCapacity: self.count];
  
  for (id value in self)
  {
    id newValue = [value copyByApplyingBlock: block error: error];
    
    if (newValue)
    {
      [destination addObject: newValue];
    }
    else
    {
      return nil;
    }
  }
  
  return destination;
}

- (BOOL) applyBlock: (BOOL (^)(id object, NSError**)) block
              error: (NSError**) error
{
  for (id value in self)
  {
    if (![value applyBlock: block error: error])
    {
      return NO;
    }
  }
  
  return YES;
}

- (BOOL) anyMemberSatisfiesPredicate: (BOOL (^)(id object)) predicate
{
  for (id value in self)
  {
    if ([value anyMemberSatisfiesPredicate: predicate])
    {
      return YES;
    }
  }
  
  return NO;
}

@end

@implementation NSDictionary(CTNContent)

- (id) copyByApplyingBlock: (id (^)(id content, NSError**)) block
                     error: (NSError**) error
{
  NSMutableDictionary* destination = [[NSMutableDictionary alloc] initWithCapacity: self.count];
  
  for (NSString* key in [self allKeys])
  {
    id value = [self objectForKey: key];
    id newValue = [value copyByApplyingBlock: block error: error];
    
    if (newValue)
    {
      [destination setObject: newValue forKey: key];
    }
    else
    {
      return nil;
    }
  }
  
  return destination;
}

- (BOOL) applyBlock: (BOOL (^)(id object, NSError**)) block
              error: (NSError**) error
{
  for (id value in [self allValues])
  {
    if (![value applyBlock: block error: error])
    {
      return NO;
    }
  }
  
  return YES;
}

- (BOOL) anyMemberSatisfiesPredicate: (BOOL (^)(id object)) predicate
{
  for (id value in [self allValues])
  {
    if ([value anyMemberSatisfiesPredicate: predicate])
    {
      return YES;
    }
  }
  
  return NO;
}

@end