//
//  CTNZumoNotificationPlugin.h
//  MessagingTest
//
//  Created by Gary Meehan on 19/05/2016.
//
//

#import <Foundation/Foundation.h>

#import <Cordova/CDV.h>

#import "CTNNotificationProvider.h"

@interface CTNZumoNotificationPlugin : CDVPlugin<CTNNotificationProviderDelegate>

- (void) start: (CDVInvokedUrlCommand*) command;

- (void) logout: (CDVInvokedUrlCommand*) command;

@end
