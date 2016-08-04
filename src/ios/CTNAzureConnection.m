//
//  CTNAzureConnection
//  Notifications
//
//  Created by Gary Meehan on 05/11/2012.
//  Copyright (c) 2012 CommonTime. All rights reserved.
//

#import "CTNAzureConnection.h"

#import <CommonCrypto/CommonDigest.h>
#import <CommonCrypto/CommonCrypto.h>

#import "CTLogger.h"

#import "CTNAzureConstants.h"
#import "CTNAzureNotificationProvider.h"

#import "CTNConstants.h"
#import "CTNMessage.h"
#import "CTNNotificationProviderManager.h"
#import "CTNUtility.h"

#import "HTTPConstants.h"

#import "NSDictionary+JSON.h"

typedef enum
{
  CTNAzureConnectionInitialized,
  CTNAzureConnectionCreatingQueue,
  CTNAzureConnectionCreatingTopic,
  CTNAzureConnectionCreatingSubscription,
  CTNAzureConnectionSendingMessage,
  CTNAzureConnectionReceivingMessage,
  CTNAzureConnectionDeletingMessage,
  CTNAzureConnectionFailed,
  CTNAzureConnectionFinished,
  CTNAzureConnectionStopped
} CTNAzureConnectionState;

/*
static NSString* CTNAzureConnectionStateDescription(CTNAzureConnectionState state)
{
  switch (state)
  {
    case CTNAzureConnectionInitialized:
    {
      return @"intialized";
    }
    case CTNAzureConnectionCreatingTopic:
    {
      return @"creating topic";
    }
    case CTNAzureConnectionCreatingSubscription:
    {
      return @"creating subscription";
    }
    case CTNAzureConnectionCreatingQueue:
    {
      return @"creating queue";
    }
    case CTNAzureConnectionDeletingMessage:
    {
      return @"deleting message";
    }
    case CTNAzureConnectionReceivingMessage:
    {
      return @"receiving message";
    }
    case CTNAzureConnectionSendingMessage:
    {
      return @"sending message";
    }
    case CTNAzureConnectionFailed:
    {
      return @"failed";
    }
    case CTNAzureConnectionFinished:
    {
      return @"finished";
    }
    case CTNAzureConnectionStopped:
    {
      return @"stopped";
    }
  }
  
  return nil;
}
*/

@interface CTNAzureConnection()

@property (nonatomic, readonly) CTLogger* logger;

@property (nonatomic, readwrite, assign) CTNAzureConnectionState state;
@property (nonatomic, readwrite, strong) NSString* channel;
@property (nonatomic, readwrite, strong) NSString* topicName;
@property (nonatomic, readwrite, strong) NSString* subscriptionName;
@property (nonatomic, readwrite, strong) NSString* subscriptionPath;
@property (nonatomic, readwrite, strong) CTNAzureNotificationProvider* provider;
@property (nonatomic, readwrite, strong) CTNMessage* messageToSend;
@property (nonatomic, readwrite, strong) NSString* lockToken;
@property (nonatomic, readwrite, strong) NSHTTPURLResponse* response;
@property (nonatomic, readwrite, strong) NSMutableData* responseData;
@property (nonatomic, readwrite, strong) NSString* azureMessageId;
@property (nonatomic, readwrite, strong) NSString* sessionIdentifier;
@property (nonatomic, readwrite, strong) NSURLSession* session;
@property (nonatomic, readwrite, strong) NSURLSessionTask* currentTask;
@property (nonatomic, readwrite, strong) NSURL* messageDataURL;
@property (nonatomic, readwrite, strong) NSMutableDictionary* sharedAccessSignatures;
@property (nonatomic, readonly) NSString* baseAddress;

@end

#if DEBUG
static NSTimeInterval CTNAzureRequestTimeout = 30.0;
#else
static NSTimeInterval CTNAzureRequestTimeout = 300.0;
#endif

@implementation CTNAzureConnection

- (id) initWithProvider: (CTNAzureNotificationProvider*) provider
      sessionIdentifier: (NSString*) sessionIdentifier
                channel: (NSString*) channel
{
  return [self initWithProvider: provider
              sessionIdentifier: sessionIdentifier
                        channel: channel
                        message: nil
                 messageDataURL: nil];
}

- (id) initWithProvider: (CTNAzureNotificationProvider*) provider
      sessionIdentifier: (NSString*) sessionIdentifier
                message: (CTNMessage*) message
         messageDataURL: (NSURL*) messageDataURL
{
  return [self initWithProvider: provider
              sessionIdentifier: sessionIdentifier
                        channel: message.channel
                        message: message
                 messageDataURL: messageDataURL];
}

- (id) initWithProvider: (CTNAzureNotificationProvider*) provider
      sessionIdentifier: (NSString*) sessionIdentifier
                channel: (NSString*) channel
                message: (CTNMessage*) message
         messageDataURL: (NSURL*) messageDataURL
{
  if ((self = [super init]))
  {
    self.channel = channel;
    self.sessionIdentifier = sessionIdentifier;
    self.provider = provider;
    self.messageToSend = message;
    self.messageDataURL = messageDataURL;
    self.sharedAccessSignatures = [NSMutableDictionary dictionary];
    
    if (provider.useTopics)
    {
      NSRange range = [channel rangeOfString: @"/"];
      
      if (range.location == NSNotFound)
      {
        self.topicName = channel;
        self.subscriptionName = channel;
      }
      else
      {
        self.topicName = [channel substringToIndex: range.location];
        self.subscriptionName = [channel substringFromIndex: range.location + 1];
      }
      
      self.subscriptionPath = [NSString stringWithFormat: @"%@/subscriptions/%@", self.topicName, self.subscriptionName];
    }
  
    self.state = CTNAzureConnectionInitialized;
  }
  
  return self;
}

- (void) dealloc
{
  [self cleanup];
}

- (CTLogger*) logger
{
  return [CTNNotificationProviderManager sharedManager].logger;
}

- (NSString*) baseAddress
{
  return [NSString stringWithFormat: @"https://%@.%@/",
          self.provider.serviceNamespace, self.provider.serviceBusHostname];
}

- (NSString*) authorizationForPath: (NSString*) path
{
  return [self sharedAccessSignatureForPath: path];
}

- (NSString*) sharedAccessSignatureForPath: (NSString*) path
{
  NSString* signature = [self.sharedAccessSignatures objectForKey: path];
  
  if (!signature)
  {
    signature = [self generateSharedAccessSignatureForPath: path];
    [self.sharedAccessSignatures setObject: signature forKey: path];
  }
  
  return signature;
}

- (NSString*) generateSharedAccessSignatureForPath: (NSString*) path
{
  NSString* URL = [NSString stringWithFormat: @"%@%@",self.baseAddress, path];
  NSString* encodedURL = CTNURLEncodeString(URL);
  long expiry = (long) [[NSDate dateWithTimeIntervalSinceNow: 60 * 60.0] timeIntervalSince1970];
  NSString* stringToSign = [NSString stringWithFormat: @"%@\n%ld", encodedURL, expiry];
  NSData* data = [stringToSign dataUsingEncoding: NSUTF8StringEncoding];
  NSData* key = [self.provider.sharedAccessKey dataUsingEncoding: NSUTF8StringEncoding];
  NSMutableData* hash = [NSMutableData dataWithLength: CC_SHA256_DIGEST_LENGTH];
  
  CCHmac(kCCHmacAlgSHA256, [key bytes], [key length], [data bytes], [data length], [hash mutableBytes]);
  
  NSString* signature = [hash base64EncodedStringWithOptions: 0];
  
  return [NSString stringWithFormat: @"SharedAccessSignature sig=%@&se=%ld&skn=%@&sr=%@",
          CTNURLEncodeString(signature),
          expiry,
          self.provider.sharedAccessKeyName,
          encodedURL];
}

- (void) clearSharedAccessSignatures
{
  [self.sharedAccessSignatures removeAllObjects];
}

- (void) start
{
  if (self.provider.sharedAccessKey)
  {
    if (self.provider.autoCreate)
    {
      if (self.provider.useQueues)
      {
        self.state = CTNAzureConnectionCreatingQueue;
      }
      else
      {
        self.state = CTNAzureConnectionCreatingTopic;
      }
    }
    else
    {
      [self startRunning];
    }
  }
  else
  {
    [self.logger error: @"Cannot use the Azure Service Buse: no shared-access key"];
    
    self.state = CTNAzureConnectionFailed;
  }
  
  [self processState];
}

- (void) cleanup
{
  self.channel = nil;
  self.topicName = nil;
  self.subscriptionName = nil;
  self.subscriptionPath = nil;
  self.provider = nil;
  self.messageToSend = nil;
  self.lockToken = nil;
  self.response = nil;
  self.responseData = nil;
  self.azureMessageId = nil;
  self.sessionIdentifier = nil;
  self.session = nil;
  self.currentTask = nil;
  self.messageDataURL = nil;
  self.sharedAccessSignatures = nil;
}

- (void) stop
{
  [self terminateSession];
  [self cleanup];
  
  self.state = CTNAzureConnectionStopped;
}

- (void) retry
{
  [self processState];
}

- (NSString*) description
{
  return [NSString stringWithFormat: @"Azure connection for %@", self.delegate];
}

- (void) processState
{
  switch (self.state)
  {
    case CTNAzureConnectionCreatingQueue:
    {
      [self createQueue];
      
      break;
    }
    case CTNAzureConnectionCreatingTopic:
    {
      [self createTopic];
      
      break;
    }
    case CTNAzureConnectionCreatingSubscription:
    {
      [self createSubscription];
      
      break;
    }
    case CTNAzureConnectionSendingMessage:
    {
      [self sendMessage];
      
      break;
    }
    case CTNAzureConnectionReceivingMessage:
    {
      [self receiveMessage];
      
      break;
    }
    case CTNAzureConnectionDeletingMessage:
    {
      [self deleteMessage];
      
      break;
    }
    default:
    {
      break;
    }
  }
}

- (void) sendRequest: (NSURLRequest*) request
{
  [self.logger traceWithFormat: @"Sending %@ request for %@ on %@", request.HTTPMethod, request.URL, self];
  
  [self initializeSession];
  
  switch (self.state)
  {
    case CTNAzureConnectionCreatingQueue:
    case CTNAzureConnectionCreatingTopic:
    case CTNAzureConnectionCreatingSubscription:
    case CTNAzureConnectionReceivingMessage:
    case CTNAzureConnectionDeletingMessage:
    {
      self.currentTask = [self.session downloadTaskWithRequest: request];
      
      break;
    }
    case CTNAzureConnectionSendingMessage:
    {
      self.currentTask = [self.session uploadTaskWithRequest: request fromFile: self.messageDataURL];
      
      break;
    }
    default:
    {
      self.currentTask = nil;
      
      break;
    }
  }
  
  [self.logger traceWithFormat: @"Created task %lu for %@", (unsigned long) self.currentTask.taskIdentifier, self];
  
  [self.currentTask resume];
}

- (void) initializeSession
{
  if (self.session)
  {
    return;
  }
  else
  {
    self.session = [NSURLSession sessionWithConfiguration: [self sessionConfiguration]
                                                 delegate: self
                                            delegateQueue: [NSOperationQueue mainQueue]];
    
    [self.logger traceWithFormat: @"Started session for %@ with ID %@", self, self.session.configuration.identifier];
  }
}

- (void) terminateSession
{
  if (!self.session)
  {
    return;
  }
  
  [self.session invalidateAndCancel];
  self.session = nil;
}

- (NSURLSessionConfiguration*) sessionConfiguration
{
  NSURLSessionConfiguration* config = nil;
  
  if ([NSURLSessionConfiguration respondsToSelector: @selector(backgroundSessionConfigurationWithIdentifier:)])
  {
    config = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier: self.sessionIdentifier];
  }
  else
  {
    config = [NSURLSessionConfiguration ephemeralSessionConfiguration];
  }
  
  config.discretionary = NO;
  config.requestCachePolicy = NSURLCacheStorageNotAllowed;
  config.timeoutIntervalForRequest = 60.0;
  config.timeoutIntervalForResource = CTNAzureRequestTimeout + 5.0;
  
  return config;
}

- (void) createQueue
{
  [self.logger traceWithFormat: @"Creating queue for %@", self];

  NSString* bodyFormat = @"<entry xmlns=\"http://www.w3.org/2005/Atom\">"
  "<title type=\"text\">%@</title>"
  "<content type=\"application/xml\">"
  "<QueueDescription xmlns:i=\"http://www.w3.org/2001/XMLSchema-instance\" "
  "xmlns=\"http://schemas.microsoft.com/netservices/2010/10/servicebus/connect\" />"
  "</content>"
  "</entry>";
  
  NSString* body = [NSString stringWithFormat: bodyFormat, self.channel];
  
  NSURL* URL = [NSURL URLWithString: [NSString stringWithFormat: @"%@%@",
                                      self.baseAddress, self.channel]];
  
  NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL: URL];
  
  [request setHTTPMethod: HTTPPutMethod];
  [request setValue: [self authorizationForPath: self.channel] forHTTPHeaderField: HTTPAuthorizationField];
  [request setValue: @"application/xml; charset=utf-8" forHTTPHeaderField: HTTPContentTypeField];
  [request setHTTPBody: [body dataUsingEncoding: NSUTF8StringEncoding]];
  
  [self sendRequest: request];
}

- (void) createTopic
{
  [self.logger traceWithFormat: @"Creating topic for %@", self];

  NSString* bodyFormat = @"<entry xmlns=\"http://www.w3.org/2005/Atom\">"
  "<title type=\"text\">%@</title>"
  "<content type=\"application/xml\">"
  "<TopicDescription xmlns:i=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns=\"http://schemas.microsoft.com/netservices/2010/10/servicebus/connect\" />"
  "</content>"
  "</entry>";
  
  NSString* body = [NSString stringWithFormat: bodyFormat, self.topicName];
  NSURL* URL = [NSURL URLWithString: [NSString stringWithFormat: @"%@%@",
                                      self.baseAddress, self.topicName]];
  
  NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL: URL];
  
  [request setHTTPMethod: HTTPPutMethod];
  [request setValue: [self authorizationForPath: self.topicName] forHTTPHeaderField: HTTPAuthorizationField];
  [request setValue: @"application/xml; charset=utf-8" forHTTPHeaderField: HTTPContentTypeField];
  [request setHTTPBody: [body dataUsingEncoding: NSUTF8StringEncoding]];
  
  [self sendRequest: request];
}

- (void) createSubscription
{
  [self.logger traceWithFormat: @"Creating subscription for %@", self];

  NSString* bodyFormat = @"<entry xmlns=\"http://www.w3.org/2005/Atom\">"
  "<title type=\"text\">%@</title>"
  "<content type=\"application/xml\">"
  "<SubscriptionDescription xmlns:i=\"http://www.w3.org/2001/XMLSchema-instance\" xmlns=\"http://schemas.microsoft.com/netservices/2010/10/servicebus/connect\" />"
  "<LockDuration>PT5M</LockDuration>"
  "<RequiresSession>false</RequiresSession>"
  "</content>"
  "</entry>";
  
  NSString* body = [NSString stringWithFormat: bodyFormat, self.subscriptionName];
  NSURL* URL = [NSURL URLWithString: [NSString stringWithFormat: @"%@%@",
                                      self.baseAddress, self.subscriptionPath]];
  
  NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL: URL];
  
  [request setHTTPMethod: HTTPPutMethod];
  [request setValue: [self authorizationForPath: self.subscriptionPath] forHTTPHeaderField: HTTPAuthorizationField];
  [request setValue: @"application/xml; charset=utf-8" forHTTPHeaderField: HTTPContentTypeField];
  [request setHTTPBody: [body dataUsingEncoding: NSUTF8StringEncoding]];
  
  [self sendRequest: request];
}

- (void) receiveMessage
{
  [self.logger traceWithFormat: @"Receiving next message on %@", self];

  NSString* path = self.provider.useQueues ? self.channel : self.subscriptionPath;
  NSURL* URL = [NSURL URLWithString: [NSString stringWithFormat: @"%@%@/messages/head?timeout=%lu",
                                      self.baseAddress, path, (unsigned long) CTNAzureRequestTimeout]];
  
  NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL: URL];
  
  [request setHTTPMethod: HTTPPostMethod];
  [request setValue: [self authorizationForPath: path] forHTTPHeaderField: HTTPAuthorizationField];
  
  [self sendRequest: request];
}

- (void) deleteMessage
{
  [self.logger traceWithFormat: @"Deleting last read messaage on %@", self];
  
  NSString* path = self.provider.useQueues ? self.channel : self.subscriptionPath;
  NSURL* URL = [NSURL URLWithString: [NSString stringWithFormat: @"%@%@/messages/%@/%@",
                                      self.baseAddress, path, self.azureMessageId, self.lockToken]];
  
  NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL: URL];
  
  [request setHTTPMethod: HTTPDeleteMethod];
  [request setValue: [self authorizationForPath: path] forHTTPHeaderField: HTTPAuthorizationField];
  
  [self sendRequest: request];
}

- (void) sendMessage
{
  [self.logger traceWithFormat: @"Sending message for %@", self];

  NSString* path = self.provider.useQueues ? self.channel : self.topicName;
  NSURL* URL = [NSURL URLWithString: [NSString stringWithFormat: @"%@%@/messages?timeout=%lu",
                                      self.baseAddress, path, (unsigned long) CTNAzureRequestTimeout]];
  
  NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL: URL];
  
  [request setHTTPMethod: @"POST"];
  
  [request setValue: [self authorizationForPath: path] forHTTPHeaderField: HTTPAuthorizationField];
  [request setValue: @"application/json; type=entry; charset=utf-8" forHTTPHeaderField: HTTPContentTypeField];
  
  if (self.messageToSend.timeToLive > 0)
  {
    NSDictionary* brokerProperties = @{ @"TimeToLive": [NSNumber numberWithDouble: self.messageToSend.timeToLive] };
    
    [request setValue: [brokerProperties JSONString] forHTTPHeaderField: @"BrokerProperties"];
  }
  
  [self sendRequest: request];
}

- (void) didCreateQueue
{
  [self startRunning];
}

- (void) didCreateTopic
{
  self.state = CTNAzureConnectionCreatingSubscription;
}

- (void) didCreateSubscription
{
  [self startRunning];
}

- (void) startRunning
{
  if (self.messageToSend)
  {
    self.state = CTNAzureConnectionSendingMessage;
  }
  else if (self.azureMessageId && self.lockToken)
  {
    self.state = CTNAzureConnectionDeletingMessage;
  }
  else
  {
    self.state = CTNAzureConnectionReceivingMessage;
  }
}

- (void) didSendMessage
{
  self.state = CTNAzureConnectionFinished;
  [self.delegate azureConnectionDidSendMessage: self];
}

- (void) didReceiveMessage
{
  NSDictionary* headers = [self.response allHeaderFields];
  NSString* brokerProperties = [headers valueForKey: @"BrokerProperties"];
  NSDictionary* broker = [NSDictionary dictionaryWithJSONString: brokerProperties];
  
  self.azureMessageId = [broker objectForKey: @"MessageId"];
  self.lockToken = [broker objectForKey: @"LockToken"];
  
  NSDictionary* response =
  [NSJSONSerialization JSONObjectWithData: self.responseData
                                  options: 0
                                    error: NULL];
  
  CTNMessage* message = [CTNMessage messageWithJSONObject: response];
  
  [self.delegate azureConnection: self didReceiveMessage: message];
  self.state = CTNAzureConnectionDeletingMessage;
}

- (void) didDeleteMessage
{
  self.azureMessageId = nil;
  self.lockToken = nil;
  
  self.state = CTNAzureConnectionReceivingMessage;
}

- (void) didFailWithDescription: (NSString*) description
                           code: (NSUInteger) code
                       canRetry: (BOOL) canRetry
{
  NSMutableDictionary* userInfo = [NSMutableDictionary dictionaryWithCapacity: 2];
  
  [userInfo setObject: description forKey: NSLocalizedDescriptionKey];
  
  NSError* error = [NSError errorWithDomain: CTNErrorDomain
                                       code: code
                                   userInfo: userInfo];
  
  [self didFailWithError: error canRetry: canRetry];
}

- (void) didFailWithError: (NSError*) error canRetry: (BOOL) canRetry
{
  if (!canRetry)
  {
    self.state = CTNAzureConnectionFailed;
  }
  
  [self.delegate azureConnection: self didFailWithError: error canRetry: canRetry];
}

- (void) willNeedToReauthenticate
{
  [self.logger traceWithFormat: @"Need to reauthenticate %@", self];
 
  [self clearSharedAccessSignatures];
}

- (void) createQueueRequestDidComplete
{
  switch (self.response.statusCode)
  {
    case HTTPStatusConflict:
    case HTTPStatusCreated:
    {
      [self didCreateQueue];
      
      break;
    }
    case HTTPStatusUnauthorized:
    {
      NSString* errorMessage = @"Cannot create queue; service is unauthorized.";
      
      [self didFailWithDescription: errorMessage
                              code: CTNServiceUnauthorizedError
                          canRetry: NO];
      
      break;
    }
    default:
    {
      NSString* errorMessage =
      [NSString stringWithFormat: @"Cannot create queue; HTTP status was %ld.", (long) self.response.statusCode];
      
      [self didFailWithDescription: errorMessage
                              code: CTNCannotCreateQueueError
                          canRetry: NO];
      
      break;
    }
  }
}

- (void) createTopicRequestDidComplete
{
  switch (self.response.statusCode)
  {
    case HTTPStatusConflict:
    case HTTPStatusCreated:
    {
      [self didCreateTopic];
      
      break;
    }
    case HTTPStatusUnauthorized:
    {
      NSString* errorMessage = @"Cannot create topic; service is unauthorized.";
      
      [self didFailWithDescription: errorMessage
                              code: CTNServiceUnauthorizedError
                          canRetry: NO];
      
      break;
    }
    default:
    {
      NSString* errorMessage =
      [NSString stringWithFormat: @"Cannot create topic; HTTP status was %ld.", (long) self.response.statusCode];
      
      [self didFailWithDescription: errorMessage
                              code: CTNCannotCreateQueueError
                          canRetry: NO];
      
      break;
    }
  }
}

- (void) createSubscriptionRequestDidComplete
{
  switch (self.response.statusCode)
  {
    case HTTPStatusConflict:
    case HTTPStatusCreated:
    {
      [self didCreateSubscription];
      
      break;
    }
    case HTTPStatusUnauthorized:
    {
      NSString* errorMessage = @"Cannot create subscription; service is unauthorized.";
      
      [self didFailWithDescription: errorMessage
                              code: CTNServiceUnauthorizedError
                          canRetry: NO];
      
      break;
    }
    default:
    {
      NSString* errorMessage =
      [NSString stringWithFormat: @"Cannot create subscription; HTTP status was %ld.", (long) self.response.statusCode];
      
      [self didFailWithDescription: errorMessage
                              code: CTNCannotCreateQueueError
                          canRetry: NO];
      
      break;
    }
  }
}

- (void) receiveMessageRequestDidComplete
{
  switch (self.response.statusCode)
  {
    case HTTPStatusCreated:
    {
      [self didReceiveMessage];
      
      break;
    }
    case HTTPStatusNoContent:
    {
      [self.logger traceWithFormat: @"%@ received no content, will reissue request", self];
      
      break;
    }
    case HTTPStatusUnauthorized:
    {
      [self willNeedToReauthenticate];
      
      break;
    }
    default:
    {
      NSString* errorMessage =
      [NSString stringWithFormat: @"Cannot receive message; HTTP status was %ld.", (long) self.response.statusCode];
      
      [self didFailWithDescription: errorMessage
                              code: CTNCannotReceiveMessageError
                          canRetry: NO];
      
      break;
    }
  }
}

- (void) deleteMessageRequestDidComplete
{
  switch (self.response.statusCode)
  {
    case HTTPStatusOkay:
    case HTTPStatusNoContent:
    case HTTPStatusNotFound:
    {
      [self didDeleteMessage];
      
      break;
    }
    case HTTPStatusUnauthorized:
    {
      [self willNeedToReauthenticate];
      
      break;
    }
    default:
    {
      NSString* errorMessage =
      [NSString stringWithFormat: @"Cannot delete message; HTTP status was %ld.", (long) self.response.statusCode];
      
      [self didFailWithDescription: errorMessage
                              code: CTNCannotDeleteMessageError
                          canRetry: YES];
      
      self.state = CTNAzureConnectionReceivingMessage;
      
      break;
    }
  }
}

- (void) sendMessageRequestDidComplete
{
  switch (self.response.statusCode)
  {
    case HTTPStatusCreated:
    {
      [self didSendMessage];
      
      break;
    }
    case HTTPStatusUnauthorized:
    {
      [self willNeedToReauthenticate];
      
      break;
    }
    default:
    {
      NSString* errorMessage =
      [NSString stringWithFormat: @"Cannot send message; HTTP status was %ld.", (long) self.response.statusCode];
      
      [self didFailWithDescription: errorMessage
                              code: CTNCannotSendMessageError
                          canRetry: NO];
      
      break;
    }
  }
}

- (void) requestDidComplete
{
  [self.logger traceWithFormat: @"%@ received response with status code %ld and data of length %lu bytes", self, (long) self.response.statusCode, (unsigned long) [self.responseData length]];
  
  switch (self.state)
  {
    case CTNAzureConnectionCreatingQueue:
    {
      [self createQueueRequestDidComplete];
    
      break;
    }
    case CTNAzureConnectionCreatingTopic:
    {
      [self createTopicRequestDidComplete];
      
      break;
    }
    case CTNAzureConnectionCreatingSubscription:
    {
      [self createSubscriptionRequestDidComplete];
      
      break;
    }
    case CTNAzureConnectionReceivingMessage:
    {
      [self receiveMessageRequestDidComplete];
      
      break;
    }
    case CTNAzureConnectionDeletingMessage:
    {
      [self deleteMessageRequestDidComplete];
      
      break;
    }
    case CTNAzureConnectionSendingMessage:
    {
      [self sendMessageRequestDidComplete];
      
      break;
    }
    default:
    {
      break;
    }
  }
  
  self.response = nil;
  self.responseData = nil;
  self.currentTask = nil;
  
  [self processState];
}

#pragma mark - NSURLSessionDataDelegate

- (void) URLSession: (NSURLSession*) session
           dataTask: (NSURLSessionDataTask*) task
     didReceiveData: (NSData*) data
{
  if (task.taskIdentifier != self.currentTask.taskIdentifier)
  {
    [self.logger traceWithFormat: @"Ignoring did-receive-data event on task %lu for %@", (unsigned long) task.taskIdentifier, self];
    
    return;
  }
  
  if (self.responseData)
  {
    [self.responseData appendData: data];
  }
  else
  {
    self.responseData = [NSMutableData dataWithData: data];
  }
}

#pragma mark - NSURLSessionTaskDelegate

- (void) URLSession: (NSURLSession*) session
               task: (NSURLSessionTask*) task
didCompleteWithError: (NSError*) error
{
  if (task.taskIdentifier != self.currentTask.taskIdentifier)
  {
    [self.logger traceWithFormat: @"Ignoring completion event on task %lu for %@", (unsigned long) task.taskIdentifier, self];
    
    return;
  }

  if (error && !task.response)
  {
    [self.logger traceWithFormat: @"Task %lu did complete for for %@ with error %@", (unsigned long) task.taskIdentifier, self, [error localizedDescription]];

    self.response = nil;
    self.responseData = nil;
    [self didFailWithError: error canRetry: YES];
  }
  else
  {
    [self.logger traceWithFormat: @"Task %lu did complete for for %@", (unsigned long) task.taskIdentifier, self];

    self.response = (NSHTTPURLResponse*) task.response;
    [self requestDidComplete];
  }
}

- (void) URLSession: (NSURLSession*) session
               task: (NSURLSessionTask*) task
    didSendBodyData: (int64_t) bytesSent
     totalBytesSent: (int64_t) totalBytesSent
totalBytesExpectedToSend: (int64_t) totalBytesExpectedToSend
{
  if (task.taskIdentifier != self.currentTask.taskIdentifier)
  {
    [self.logger traceWithFormat: @"Ignoring did-send event on task %lu for %@", (unsigned long) task.taskIdentifier, self];
    
    return;
  }

  if (totalBytesExpectedToSend == NSURLSessionTransferSizeUnknown)
  {
    [self.logger traceWithFormat: @"%@ wrote %@", self, CTNFormatBytes(bytesSent)];
  }
  else
  {
    [self.logger traceWithFormat: @"%@ wrote %@ (%.1lf%%)", self, CTNFormatBytes(bytesSent), 100.0 * totalBytesSent / totalBytesExpectedToSend];
  }
}

- (void) URLSession: (NSURLSession*) session
               task: (NSURLSessionTask*) task
didReceiveChallenge: (NSURLAuthenticationChallenge*) challenge
  completionHandler: (void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential*)) completionHandler
{
  if (task.taskIdentifier != self.currentTask.taskIdentifier)
  {
    [self.logger traceWithFormat: @"Ignoring did-receive-challenge event on task %lu for %@", (unsigned long) task.taskIdentifier, self];
    
    return;
  }
  
  completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
}

- (void) URLSessionDidFinishEventsForBackgroundURLSession: (NSURLSession*) session
{
  [self.logger traceWithFormat: @"Background events did finish for %@", self];
  
  [self.delegate azureConnection: self didFinishEventsForBackgroundURLSession: session];
}

#pragma mark - NSURLSessionDownloadDelegate

- (void) URLSession: (NSURLSession*) session
       downloadTask: (NSURLSessionDownloadTask*) task
  didResumeAtOffset: (int64_t) fileOffset
 expectedTotalBytes: (int64_t) expectedTotalBytes
{
  if (task.taskIdentifier != self.currentTask.taskIdentifier)
  {
    [self.logger traceWithFormat: @"Ignoring did-resume event on task %lu for %@", (unsigned long) task.taskIdentifier, self];
    
    return;
  }
}

- (void) URLSession: (NSURLSession*) session
       downloadTask: (NSURLSessionDownloadTask*) task
       didWriteData: (int64_t) bytesWritten
  totalBytesWritten: (int64_t) totalBytesWritten
totalBytesExpectedToWrite: (int64_t) totalBytesExpectedToWrite
{
  if (task.taskIdentifier != self.currentTask.taskIdentifier)
  {
    [self.logger traceWithFormat: @"Ignoring did-receive event on task %lu for %@", (unsigned long) task.taskIdentifier, self];
    
    return;
  }
  
  if (totalBytesExpectedToWrite == NSURLSessionTransferSizeUnknown)
  {
    [self.logger traceWithFormat: @"%@ received %@", self, CTNFormatBytes(bytesWritten)];
  }
  else
  {
    [self.logger traceWithFormat: @"%@ received %@ (%.1lf%%)", self, CTNFormatBytes(bytesWritten), 100.0 * totalBytesWritten / totalBytesExpectedToWrite];
  }
}

- (void) URLSession: (NSURLSession*) session
       downloadTask: (NSURLSessionDownloadTask*) task
didFinishDownloadingToURL: (NSURL*) location
{
  if (task.taskIdentifier != self.currentTask.taskIdentifier)
  {
    [self.logger traceWithFormat: @"Ignoring did-finish event on task %lu for %@", (unsigned long) task.taskIdentifier, self];
    
    return;
  }
  
  [self.logger traceWithFormat: @"Download task %lu did finish for %@", (unsigned long) task.taskIdentifier, self];
  
  self.responseData = [NSMutableData dataWithContentsOfURL: location];
}

@end
