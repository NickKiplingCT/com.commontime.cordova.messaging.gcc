//
//  CTNZumoMessageSender.h
//  Notifications
//
//  Created by Gary Meehan on 02/07/2014.
//  Copyright (c) 2014 CommonTime. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "CTNMessageSender.h"
#import "CTNZumoAttachmentUploader.h"

@class CTNZumoNotificationProvider;

@interface CTNZumoMessageSender : CTNMessageSender<CTNZumoAttachmentUploaderDelegate>

@end
