//
//  CTUtility.h
//  AzureTester
//
//  Created by Gary Meehan on 29/10/2012.
//  Copyright (c) 2012 CommonTime. All rights reserved.
//

#import <Foundation/Foundation.h>

NSString* CTNURLEncodeString(NSString* string);

NSString* CTNURLDecodeString(NSString* string);

NSData* CTNURLEncodeForm(NSDictionary* form);

NSDictionary* CTNURLDecodeForm(NSData* data);

NSString* CTNURLEncodeQueryParameters(NSDictionary* parameters);

NSString* CTNFormatBytes(unsigned long long bytes);

NSString* CTNMIMETypeFromPath(NSString* path);

NSString* CTNMIMETypeFromExtension(NSString* extension);

NSString* CTNMIMETypeFromData(NSData* data);

NSString* CTNMIMETypeFromBytes(const uint8_t* bytes, NSInteger length);

NSString* CTNExtensionFromMIMEType(NSString* MIMEType);

NSString* CTNStringFromJSONObject(id object);

id CTNJSONObjectFromString(NSString* string);

NSData* CTNDataFromJSONObject(id object);

id CTNJSONObjectFromData(NSData* data);

NSString* CTNDocumentsDirectory();

NSString* CTNUniquePathWithExtension(NSString* extension);
