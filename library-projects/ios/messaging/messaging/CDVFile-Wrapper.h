//
//  CDVFile-Wrapper.h
//  messaging
//
//  Created by Gary Meehan on 26/07/2016.
//  Copyright © 2016 CommonTime. All rights reserved.
//

#ifndef CDVFile_Wrapper_h
#define CDVFile_Wrapper_h

// Minimal declaration of the functions we need from the cordova file plugin
// so we avoid duplicate symbols when linking this library with a Cordova app

#import <Foundation/Foundation.h>
#import <Cordova/CDVPlugin.h>

@interface CDVFilesystemURL : NSObject

+ (CDVFilesystemURL*) fileSystemURLWithString: (NSString*) strURL;

@end

@interface CDVFile : CDVPlugin

- (NSString *)filesystemPathForURL:( CDVFilesystemURL*) URL;

@end

#endif /* CDVFile_Wrapper_h */
