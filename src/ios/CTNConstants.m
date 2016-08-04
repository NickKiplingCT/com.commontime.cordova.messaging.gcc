//
//  CTNConstants.m
//  AzureTester
//
//  Created by Gary Meehan on 30/10/2012.
//  Copyright (c) 2012 CommonTime. All rights reserved.
//

#import "CTNConstants.h"

NSString* CTNChannelKey = @"channel";
NSString* CTNContentKey = @"content";
NSString* CTNExpiryDateKey = @"expiry";
NSString* CTNIdentifierKey = @"id";
NSString* CTNNotificationKey = @"notification";
NSString* CTNSentDateKey = @"date";
NSString* CTNSubchannelKey = @"subchannel";
NSString* CTNLastTriedToSendDateKey = @"lastTriedToSend";
NSString* CTNIsDeletedKey = @"isDeleted";
NSString* CTNProviderKey = @"provider";

NSTimeInterval CTNMessageTimeToLive = 24 * 60 * 60.0;

NSString* CTNNotificationPluginTypeKey = @"Type";
NSString* CTNNotificationUseSSLKey = @"UseSSL";

NSString* CTNNotificationPluginTypeAzure = @"azure.servicebus";
NSString* CTNNotificationPluginTypeRest = @"rest";
NSString* CTNNotificationPluginTypeZumo = @"azure.appservices";

NSString* CTNAzureStorage = @"azureStorage";

NSString* CTNErrorDomain = @"CTN";
NSString* CTNMessageKey = @"message";

NSString* CTNSendMessageNotification = @"CTNSendMessage";
NSString* CTNSendMessageNotificationMessageKey = @"message";
NSString* CTNSendMessageNotificationStatusKey = @"status";

NSString* CTNMessageSending = @"SENDING";
NSString* CTNMessageSent = @"SENT";
NSString* CTNMessageFailedToSend = @"FAILED";
NSString* CTNMessageFailedToSendAndWillRetry = @"FAILED_WILL_RETRY";

NSString* CTNContentReferencePrefix = @"#contentref:";
NSString* CTNFileDataPrefix = @"#file:";
NSString* CTNFileReferencePrefix = @"#fileref:";

#ifdef DEBUG
NSTimeInterval CTNTimeIntervalBetweenRetries = 30.0;
#else
NSTimeInterval CTNTimeIntervalBetweenRetries = 5 * 60.0;
#endif