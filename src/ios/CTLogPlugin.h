//
//  CTLogPlugin
//  mDesignShell
//
//  Created by Gary Meehan on 01/10/2012.
//  Copyright (c) 2012 CommonTime Limited. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <Cordova/CDV.h>

@interface CTLogPlugin : CDVPlugin

- (void) log: (CDVInvokedUrlCommand*) command;

- (void) start:  (CDVInvokedUrlCommand*) command;

- (void) stop: (CDVInvokedUrlCommand*) command;

- (void) enable: (CDVInvokedUrlCommand*) command;

- (void) disable: (CDVInvokedUrlCommand*) command;

- (void) upload: (CDVInvokedUrlCommand*) command;

- (void) mail: (CDVInvokedUrlCommand*) command;

- (void) deleteLogFiles:  (CDVInvokedUrlCommand*) command;

@end
