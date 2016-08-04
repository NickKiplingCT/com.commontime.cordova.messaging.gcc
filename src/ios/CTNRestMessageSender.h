//
//  CTNRestMessageSender.h
//  MessagingTest
//
//  Created by Gary Meehan on 09/05/2016.
//
//

#import <Foundation/Foundation.h>

#import "CTNMessageSender.h"

@interface CTNRestMessageSender : CTNMessageSender<NSURLSessionDataDelegate, NSURLSessionTaskDelegate>

@end
