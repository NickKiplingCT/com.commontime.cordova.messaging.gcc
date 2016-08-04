//
//  CTAzureMessageReceiver.h
//  AzureTester
//
//  Created by Gary Meehan on 29/10/2012.
//  Copyright (c) 2012 CommonTime. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "CTNMessageReceiver.h"

#import "CTNAzureConnection.h"

@interface CTNAzureMessageReceiver : CTNMessageReceiver<CTNAzureConnectionDelegate>

@end
