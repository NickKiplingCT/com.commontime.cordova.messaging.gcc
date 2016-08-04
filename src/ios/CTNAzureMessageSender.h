//
//  CTNAzureMessageSender.h
//  AzureTester
//
//  Created by Gary Meehan on 31/10/2012.
//  Copyright (c) 2012 CommonTime. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "CTNMessageSender.h"

#import "CTNAzureConnection.h"

@interface CTNAzureMessageSender : CTNMessageSender<CTNAzureConnectionDelegate>

@end
