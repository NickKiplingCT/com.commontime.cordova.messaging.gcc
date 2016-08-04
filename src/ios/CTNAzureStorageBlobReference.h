//
//  CTNAzureStorageReference.h
//  Notifications
//
//  Created by Gary Meehan on 10/04/2015.
//  Copyright (c) 2015 CommonTime. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString* CTNAzureStorageBlobReferencePrefix;

@interface CTNAzureStorageBlobReference : NSObject

@property (nonatomic, readonly) NSURL* URL;
@property (nonatomic, readonly) id context;
@property (nonatomic, readonly) NSString* string;

+ (id) azureStorageBlobReferenceWithURL: (NSURL*) URL
                                context: (id) context;

+ (id) azureStorageBlobReferenceWithString: (NSString*) string;

- (id) initWithURL: (NSURL*) URL
           context: (id) context;

- (id) initWithString: (NSString*) string;

@end
