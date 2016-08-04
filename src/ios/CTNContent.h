//
//  CTNContent.h
//  Notifications
//
//  Created by Gary Meehan on 14/04/2015.
//  Copyright (c) 2015 CommonTime. All rights reserved.
//

#import <Foundation/Foundation.h>

@class CTNAzureStorageBlobReference;
@class CTNFileReference;

@interface NSObject(CTNContent)

- (BOOL) containsFileData;

- (BOOL) containsFileReferences;

- (NSArray*) allFileReferences;

- (id) copyByExpandingFileReferencesWithError: (NSError**) error;

- (id) copyByExtractingFileDataWithError: (NSError**) error;

- (id) copyByCopyingFileReferencesWithError: (NSError**) error;

- (id) copyByReplacingFileReference: (CTNFileReference*) sourceFileReference
      withAzureStorageBlobReference: (CTNAzureStorageBlobReference*) destinationStorageReference
                              error: (NSError**) error;

- (BOOL) deleteFilesWithError: (NSError**) error;

- (BOOL) containsNonStandardJSON;

- (id) copyByConvertingToStandardJSONWithError: (NSError**) error;

- (id) copyByApplyingBlock: (id (^)(id object, NSError** error)) block
                     error: (NSError**) error;

- (BOOL) applyBlock: (BOOL (^)(id object, NSError** error)) block
              error: (NSError**) error;

- (BOOL) anyMemberSatisfiesPredicate: (BOOL (^)(id object)) predicate;

@end

@interface NSArray(CTNContent)

- (id) copyByApplyingBlock: (id (^)(id object, NSError** error)) block
                     error: (NSError**) error;

- (BOOL) applyBlock: (BOOL (^)(id object, NSError** error)) block
              error: (NSError**) error;

- (BOOL) anyMemberSatisfiesPredicate: (BOOL (^)(id object)) predicate;

@end

@interface NSDictionary(CTNContent)

- (id) copyByApplyingBlock: (id (^)(id object, NSError** error)) block
                     error: (NSError**) error;

- (BOOL) applyBlock: (BOOL (^)(id object, NSError** error)) block
              error: (NSError**) error;

- (BOOL) anyMemberSatisfiesPredicate: (BOOL (^)(id object)) predicate;

@end



