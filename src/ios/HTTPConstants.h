//
//  HTTPConstants.h
//  AzureTester
//
//  Created by Gary Meehan on 30/10/2012.
//  Copyright (c) 2012 CommonTime. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum
{
  HTTPStatusOkay = 200,
  HTTPStatusCreated = 201,
  HTTPStatusNoContent = 204,
  
  HTTPStatusUnauthorized = 401,
  HTTPStatusNotFound = 404,
  HTTPStatusRequestTimeout = 408,
  HTTPStatusConflict = 409,
  
  HTTPStatusBadGateway = 502,
  HTTPStatusServiceUnavailable = 503,
} HTTPStatusCode;

extern NSString* HTTPDeleteMethod;
extern NSString* HTTPGetMethod;
extern NSString* HTTPPostMethod;
extern NSString* HTTPPutMethod;

extern NSString* HTTPAuthorizationField;
extern NSString* HTTPContentTypeField;