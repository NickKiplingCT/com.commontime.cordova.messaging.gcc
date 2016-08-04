//
//  CTNContentReference.h
//  Notifications
//
//  Created by Gary Meehan on 14/04/2015.
//  Copyright (c) 2015 CommonTime. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CTNContentReference : NSObject

@property (nonatomic, readonly) NSString* path;
@property (nonatomic, readonly) NSString* string;

+ (id) contentReferenceWithPath: (NSString*) path;

+ (id) contentReferenceWithContent: (id) content;

- (id) initWithPath: (NSString*) path;

- (id) initWithContent: (id) content;

@end
