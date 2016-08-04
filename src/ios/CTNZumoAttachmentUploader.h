//
//  CTNZumoAttachmentUploader.h
//  Notifications
//
//  Created by Gary Meehan on 02/04/2015.
//  Copyright (c) 2015 CommonTime. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "CTNConstants.h"

@class CTNAzureStorageBlobAttachment;
@class CTNZumoAttachmentUploader;
@class CTNZumoNotificationProvider;

@protocol CTNZumoAttachmentUploaderDelegate

- (void) attachmentUploaderDidSucceed: (CTNZumoAttachmentUploader*) uploader;

- (void) attachmentUploader: (CTNZumoAttachmentUploader*) uploader
           didFailWithError: (NSError*) error
                      retry: (CTNRetryStrategy) retry;

@end

@interface CTNZumoAttachmentUploader : NSObject<NSURLSessionTaskDelegate>

@property (nonatomic, readonly) CTNAzureStorageBlobAttachment* attachment;

@property (nonatomic, readwrite, assign) id<CTNZumoAttachmentUploaderDelegate> delegate;
@property (nonatomic, readwrite, copy) void (^backgroundCompletionHandler)();

- (id) initWithAttachment: (CTNAzureStorageBlobAttachment*) attachment
                 provider: (CTNZumoNotificationProvider*) provider;

- (void) start;

- (void) stop;

- (void) rejoinSession;

@end
