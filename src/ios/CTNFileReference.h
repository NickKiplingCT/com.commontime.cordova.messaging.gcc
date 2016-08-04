//
//  CTNFileReference.h
//  Notifications
//
//  Created by Gary Meehan on 10/04/2015.
//  Copyright (c) 2015 CommonTime. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CTNFileReference : NSObject<NSCopying>

@property (nonatomic, readonly) NSString* path;
@property (nonatomic, readonly) id context;
@property (nonatomic, readonly) NSString* string;

+ (id) fileReferenceWithString: (NSString*) string;

+ (id) fileReferenceWithPath: (NSString*) path;

+ (id) fileReferenceWithPath: (NSString*) path context: (id) context;

- (id) initWithString: (NSString*) string;

- (id) initWithPath: (NSString*) path
            context: (id) context;

- (BOOL) isEqual: (id) object;

- (BOOL) isEqualToFileReference: (CTNFileReference*) fileReference;

@end
