//
//  CTNAzureStorageBlobAttachment.h
//  Notifications
//
//  Created by Gary Meehan on 14/04/2015.
//  Copyright (c) 2015 CommonTime. All rights reserved.
//

#import "CTNAttachment.h"

@class CTNFileReference;
@class CTNAzureStorageBlobReference;

@interface CTNAzureStorageBlobAttachment : CTNAttachment

@property (nonatomic, readwrite, strong) CTNFileReference* fileReference;
@property (nonatomic, readwrite, strong) CTNAzureStorageBlobReference* blobReference;

- (id) initWithIdentifier: (NSString*) identifier
                  message: (CTNMessage*) message
            fileReference: (CTNFileReference*) fileReference;

- (id) initWithIdentifier: (NSString*) identifier
                  message: (CTNMessage*) message
                   status: (CTNAttachmentStatus) status
        sessionIdentifier: (NSString*) sessionIdentifier
            fileReference: (CTNFileReference*) fileReference
            blobReference: (CTNAzureStorageBlobReference*) blobReference;

@end
