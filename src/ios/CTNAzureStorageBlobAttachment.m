//
//  CTNAzureStorageBlobAttachment.m
//  Notifications
//
//  Created by Gary Meehan on 14/04/2015.
//  Copyright (c) 2015 CommonTime. All rights reserved.
//

#import "CTNAzureStorageBlobAttachment.h"

#import "CTNAzureStorageBlobReference.h"
#import "CTNFileReference.h"

@implementation CTNAzureStorageBlobAttachment

- (id) initWithIdentifier: (NSString*) identifier
                  message: (CTNMessage*) message
            fileReference: (CTNFileReference*) fileReference
{
  return [self initWithIdentifier: identifier
                          message: message
                           status: CTNAttachmentPending
                sessionIdentifier: nil
                    fileReference: fileReference
                    blobReference: nil];
}

- (id) initWithIdentifier: (NSString*) identifier
                  message: (CTNMessage*) message
                   status: (CTNAttachmentStatus) status
        sessionIdentifier: (NSString*) sessionIdentifier
            fileReference: (CTNFileReference*) fileReference
            blobReference: (CTNAzureStorageBlobReference*) blobReference
{
  if ((self = [super initWithIdentifier: identifier message: message status: status sessionIdentifier: sessionIdentifier]))
  {
    self.fileReference = fileReference;
    self.blobReference = blobReference;
  }
  
  return self;
}

- (NSString*) localReference
{
  return self.fileReference.string;
}

- (NSString*) remoteReference
{
  return self.blobReference.string;
}

@end
