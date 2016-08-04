//
//  CTNAttachment.m
//  Notifications
//
//  Created by Gary Meehan on 01/04/2015.
//  Copyright (c) 2015 CommonTime. All rights reserved.
//

#import "CTNAttachment.h"

#import "CTNMessage.h"

@interface CTNAttachment()

@property (nonatomic, readwrite, strong) NSString* identifier;
@property (nonatomic, readwrite, strong) CTNMessage* message;

@end

@implementation CTNAttachment

- (id) initWithIdentifier: (NSString*) identifier
                  message: (CTNMessage*) message
                   status: (CTNAttachmentStatus) status
        sessionIdentifier: (NSString*) sessionIdentifier
{
  if ((self = [super init]))
  {
    self.identifier = identifier;
    self.message = message;
    self.status = status;
    self.sessionIdentifier = sessionIdentifier;
  }
  
  return self;
}

- (NSString*) description
{
  return [NSString stringWithFormat: @"Attachment %@", self.identifier];
}

- (NSString*) localReference
{
  return nil;
}

- (NSString*) remoteReference
{
  return nil;
}

@end
