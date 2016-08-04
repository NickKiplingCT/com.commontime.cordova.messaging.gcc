//
//  CTNConstants.h
//  AzureTester
//
//  Created by Gary Meehan on 30/10/2012.
//  Copyright (c) 2012 CommonTime. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString* CTNChannelKey;
extern NSString* CTNContentKey;
extern NSString* CTNExpiryDateKey;
extern NSString* CTNIdentifierKey;
extern NSString* CTNNotificationKey;
extern NSString* CTNSentDateKey;
extern NSString* CTNSubchannelKey;
extern NSString* CTNLastTriedToSendDateKey;
extern NSString* CTNIsDeletedKey;
extern NSString* CTNProviderKey;

extern NSString* CTNNotificationPluginTypeKey;
extern NSString* CTNNotificationUseSSLKey;

extern NSString* CTNNotificationPluginTypeAzure;
extern NSString* CTNNotificationPluginTypeRest;
extern NSString* CTNNotificationPluginTypeZumo;

extern NSString* CTNAzureStorage;

extern NSTimeInterval CTNMessageTimeToLive;

extern NSString* CTNErrorDomain;
extern NSString* CTNMessageKey;

extern NSTimeInterval CTNTimeIntervalBetweenRetries;

extern NSString* CTNSendMessageNotification;
extern NSString* CTNSendMessageNotificationMessageKey;
extern NSString* CTNSendMessageNotificationStatusKey;

extern NSString* CTNMessageSending;
extern NSString* CTNMessageSent;
extern NSString* CTNMessageFailedToSend;
extern NSString* CTNMessageFailedToSendAndWillRetry;

extern NSString* CTNContentReferencePrefix;
extern NSString* CTNFileDataPrefix;
extern NSString* CTNFileReferencePrefix;

enum
{
  CTNCannotCreateQueueError = 1,
  CTNCannotReceiveMessageError = 2,
  CTNCannotGetTokenError = 3,
  CTNCannotDeleteMessageError = 4,
  CTNCannotSendMessageError = 5,
  CTNServiceNotReady = 6,
  CTNServiceUnauthorizedError = 7,
  CTNCannotMakeProvider = 8,
  CTNFileNotFound = 9,
  CTNNoContent = 10,
  CTNServerError = 11,
  CTNTypeError = 12,
  CTNCannotFindMessage = 13,
  CTNHTTPError = 14,
  CTNAttachmentUploadError = 15,
  CTNLocationWouldBeUnused = 16,
  CTNBadRegion = 17,
  CTNConversionError = 18,
  CTNBadArgument = 19
};

typedef NS_ENUM(NSInteger, CTNAttachmentStatus)
{
  CTNAttachmentPending = 0,
  CTNAttachmentUploading = 1,
  CTNAttachmentDownloading = 2,
  CTNAttachmentFailed = 3,
  CTNAttachmentSucceeded = 4
};

typedef NS_ENUM(NSInteger, CTNRetryStrategy)
{
  CTNRetryNever,
  CTNRetryWhenAuthenticated,
  CTNRetryImmediately,
  CTNRetryAfterDefaultPeriod,
};
