//
//  CTNAttachment.h
//  Notifications
//
//  Created by Gary Meehan on 01/04/2015.
//  Copyright (c) 2015 CommonTime. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "CTNConstants.h"

@class CTNMessage;

@interface CTNAttachment : NSObject

@property (nonatomic, readonly) NSString* identifier;
@property (nonatomic, readonly) CTNMessage* message;

@property (nonatomic, readwrite, assign) CTNAttachmentStatus status;
@property (nonatomic, readwrite, strong) NSString* sessionIdentifier;

@property (nonatomic, readonly) NSString* localReference;
@property (nonatomic, readonly) NSString* remoteReference;

- (id) initWithIdentifier: (NSString*) identifier
                  message: (CTNMessage*) message
                   status: (CTNAttachmentStatus) status
        sessionIdentifier: (NSString*) sessionIdentifier;

@end
