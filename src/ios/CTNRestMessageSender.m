//
//  CTNRestMessageSender.m
//  MessagingTest
//
//  Created by Gary Meehan on 09/05/2016.
//
//

#import "CTNRestMessageSender.h"

#ifdef STATIC_LIBRARY
#import "CDVFile-Wrapper.h"
#else
#import "CDVFile.h"
#endif

#import "CTLogger.h"

#import "CTNConstants.h"
#import "CTNContent.h"
#import "CTNFileReference.h"
#import "CTNMessage.h"
#import "CTNMessageStore.h"
#import "CTNRestNotificationProvider.h"
#import "CTNUtility.h"

static NSString* CTNBase64EncodeRequestContentKey = @"base64encode";
static NSString* CTNConfigKey = @"config";
static NSString* CTNDataKey = @"data";
static NSString* CTNDownloadAsFileKey = @"downloadAsFile";
static NSString* CTNFormPartNameKey = @"formPartName";
static NSString* CTNFormPartFilenameKey = @"formPartFilename";
static NSString* CTNHeadersKey = @"headers";
static NSString* CTNInternalFileReferenceKey = @"internalFileReference";
static NSString* CTNQueryParametersKey = @"params";
static NSString* CTNStatusKey = @"status";
static NSString* CTNStatusTextKey = @"statusText";
static NSString* CTNUploadAsFileKey = @"uploadAsFile";
static NSString* CTNUploadAsMultipartFormKey = @"uploadAsMultipartForm";
static NSString* CTNURLKey = @"url";

@interface CTNRestMessageSender()

@property (nonatomic, readonly) CTNRestNotificationProvider* restProvider;

@property (nonatomic, readwrite, strong) NSString* method;
@property (nonatomic, readwrite, strong) NSURL* URL;
@property (nonatomic, readwrite, strong) NSDictionary* queryParameters;
@property (nonatomic, readwrite, strong) NSDictionary* headers;

@property (nonatomic, readwrite, assign) BOOL downloadAsFile;
@property (nonatomic, readwrite, assign) BOOL uploadAsFile;
@property (nonatomic, readwrite, assign) BOOL base64EncodeRequestContent;
@property (nonatomic, readwrite, assign) BOOL uploadAsMultipartForm;
@property (nonatomic, readwrite, strong) NSString* formPartName;
@property (nonatomic, readwrite, strong) NSString* formPartFilename;
@property (nonatomic, readwrite, strong) NSString* formPartContentType;

@property (nonatomic, readwrite, strong) NSURL* dataURL;
@property (nonatomic, readwrite, strong) NSString* boundary;

@property (nonatomic, readwrite, strong) NSURLSession* session;
@property (nonatomic, readwrite, strong) NSURLSessionTask* currentTask;
@property (nonatomic, readwrite, strong) NSError* fileError;
@property (nonatomic, readwrite, strong) NSData* responseData;
@property (nonatomic, readwrite, strong) NSString* responsePath;
@property (nonatomic, readwrite, strong) NSMutableData* responseBuffer;

@end

@implementation CTNRestMessageSender

- (CTNRestNotificationProvider*) restProvider
{
  return (CTNRestNotificationProvider*) self.provider;
}

- (void) start
{
  [super start];

  NSError* error = nil;
  
  if (!([self setOptionsWithError: &error] &&
        [self setQueryParametersWithError: &error] &&
        [self setURLWithError: &error] &&
        [self setHeadersWithError: &error] &&
        [self setDataURLWithError: &error] &&
        [self setMethodWithError: &error]))
  {
    [self didFailWithError: error retry: CTNRetryNever];
    
    return;
  }
  
  NSURLRequest* request = [self makeRequest];
 
  [self initializeSession];

  @try
  {
    if (self.dataURL)
    {
      self.currentTask = [self.session uploadTaskWithRequest: request fromFile: self.dataURL];
    }
    else
    {
      self.currentTask = [self.session downloadTaskWithRequest: request];
    }
  }
  @catch (NSException* exception)
  {
    [self didFailWithError: [NSError errorWithDomain: @"" code: -1 userInfo: exception.userInfo] retry: CTNRetryNever];
    
    return;
  }
  
  [self.logger traceWithFormat: @"Will issue %@ request for %@", request.HTTPMethod, request.URL];
  
  [self.currentTask resume];
  [self didStartSending];
  
  [self.logger traceWithFormat: @"Started %@", self];
}

- (BOOL) setOptionsWithError: (NSError**) error
{
  id uploadAsFile = self.message.content[CTNUploadAsFileKey];
  
  if ([uploadAsFile isKindOfClass: [NSNumber class]])
  {
    self.uploadAsFile = [uploadAsFile boolValue];
  }
  
  id downloadAsFile = self.message.content[CTNDownloadAsFileKey];
  
  if ([downloadAsFile isKindOfClass: [NSNumber class]])
  {
    self.downloadAsFile = [downloadAsFile boolValue];
  }
  
  id base64Encode = self.message.content[CTNBase64EncodeRequestContentKey];
  
  if ([base64Encode isKindOfClass: [NSNumber class]])
  {
    self.base64EncodeRequestContent = [base64Encode boolValue];
  }
  
  id uploadAsMultipartForm = self.message.content[CTNUploadAsMultipartFormKey];
  
  if ([uploadAsMultipartForm isKindOfClass: [NSNumber class]])
  {
    self.uploadAsMultipartForm = [uploadAsMultipartForm boolValue];
    self.boundary = [[NSUUID UUID] UUIDString];
  }
  
  id formPartName = self.message.content[CTNFormPartNameKey];
  
  if ([formPartName isKindOfClass: [NSString class]])
  {
    self.formPartName = formPartName;
  }
  
  id formPartFilename = self.message.content[CTNFormPartFilenameKey];
  
  if ([formPartFilename isKindOfClass: [NSString class]])
  {
    self.formPartFilename = formPartFilename;
  }
  
  return YES;
}

- (BOOL) setQueryParametersWithError: (NSError**) error
{
  id parameters = self.message.content[CTNQueryParametersKey];
  
  if (parameters && ![parameters isKindOfClass: [NSNull class]])
  {
    if ([parameters isKindOfClass: [NSDictionary class]])
    {
      self.queryParameters = parameters;
      
      return YES;
    }
    else
    {
      if (error)
      {
        *error = [NSError errorWithDomain: CTNErrorDomain
                                     code: CTNBadArgument
                                 userInfo: @{NSLocalizedDescriptionKey: @"bad type for params"}];
      }
      
      return NO;
    }
  }
  else
  {
    self.queryParameters = nil;
    
    return YES;
  }
}

- (BOOL) setURLWithError: (NSError**) error
{
  id URLString = self.message.content[CTNURLKey];
  
  if ([URLString isKindOfClass: [NSString class]])
  {
    if (self.queryParameters.count > 0)
    {
      URLString = [URLString stringByAppendingString: @"?"];
      URLString = [URLString stringByAppendingString: CTNURLEncodeQueryParameters(self.queryParameters)];
    }

    self.URL = [NSURL URLWithString: URLString];
    
    if (self.URL)
    {
      return YES;
    }
    else
    {
      if (error)
      {
        *error = [NSError errorWithDomain: CTNErrorDomain
                                     code: CTNBadArgument
                                 userInfo: @{NSLocalizedDescriptionKey: @"invalid URL"}];
      }
      
      return NO;
    }
  }
  else
  {
    if (error)
    {
      *error = [NSError errorWithDomain: CTNErrorDomain
                                   code: CTNBadArgument
                               userInfo: @{NSLocalizedDescriptionKey: @"bad/missing type for url"}];
    }
    
    return NO;
  }
}

- (BOOL) setHeadersWithError: (NSError**) error
{
  id headers = self.message.content[CTNHeadersKey];
  
  if (headers && ![headers isKindOfClass: [NSNull class]])
  {
    if ([headers isKindOfClass: [NSDictionary class]])
    {
      self.headers = headers;
      
      return YES;
    }
    else
    {
      if (error)
      {
        *error = [NSError errorWithDomain: CTNErrorDomain
                                     code: CTNBadArgument
                                 userInfo: @{NSLocalizedDescriptionKey: @"bad type for headers"}];
      }
      
      return NO;
    }
  }
  else
  {
    self.headers = nil;
    
    return YES;
  }
}

- (NSString*) normalizedPathFromPath: (NSString*) path
{
  if ([path hasPrefix: @"file://"])
  {
    return [NSURL URLWithString: path].path;
  }
  else if ([path hasPrefix: @"cdvfile://"])
  {
    CDVFile* filePlugin = [[CDVFile alloc] init];
    
    [filePlugin pluginInitialize];
    
    CDVFilesystemURL* URL = [CDVFilesystemURL fileSystemURLWithString: path];
    
    return [filePlugin filesystemPathForURL: URL];
  }
  else
  {
    return path;
  }
}

- (BOOL) setDataURLWithError: (NSError**) error
{
  NSString* internalFileReference = self.message.content[CTNInternalFileReferenceKey];
  
  if (internalFileReference)
  {
    CTNFileReference* fileReference = [CTNFileReference fileReferenceWithString: (NSString*) internalFileReference];
  
    self.dataURL = [NSURL fileURLWithPath: fileReference.path];
    
    return YES;
  }
  
  id dataObject = self.message.content[@"data"];
  
  if (!dataObject ||
      [dataObject isKindOfClass: [NSNull class]] ||
      ([dataObject isKindOfClass: [NSString class]] && [dataObject length] == 0))
  {
    return YES;
  }
  
  NSString* sourcePath = nil;
  NSString* destinationPath = nil;
  
  if (self.uploadAsFile)
  {
    if ([dataObject isKindOfClass: [NSString class]])
    {
      sourcePath = [self normalizedPathFromPath: (NSString*) dataObject];
      destinationPath = CTNUniquePathWithExtension([sourcePath pathExtension]);
    }
    else
    {
      *error = [NSError errorWithDomain: CTNErrorDomain
                                   code: CTNBadArgument
                               userInfo: @{NSLocalizedDescriptionKey: @"wrong type for path"}];
      
      return NO;
    }
  }
  else
  {
    destinationPath = CTNUniquePathWithExtension(@"bin");
  }
  
  bool wroteData = NO;
  
  if (self.uploadAsMultipartForm)
  {
    self.formPartContentType = [self contentType];

    if (self.formPartContentType.length == 0)
    {
      if (self.formPartFilename.length > 0)
      {
        self.formPartContentType = CTNMIMETypeFromPath(self.formPartFilename);
      }
    }
    
    if (self.uploadAsFile)
    {
      if (self.formPartContentType.length == 0)
      {
        self.formPartContentType = CTNMIMETypeFromPath(sourcePath);
      }
      
      wroteData = [self copyMultipartFormDataWithPath: sourcePath toPath: destinationPath error: error];
    }
    else
    {
      wroteData = [self writeMultipartFormData: dataObject toPath: destinationPath error: error];
    }
  }
  else
  {
    if (self.uploadAsFile)
    {
      wroteData = [self copyDataAtPath: sourcePath toPath: destinationPath error: error];
    }
    else
    {
      wroteData = [self writeContent: dataObject toPath: destinationPath error: error];
    }
  }
  
  if (!wroteData)
  {
    return NO;
  }

  CTNFileReference* fileReference = [CTNFileReference fileReferenceWithPath: destinationPath];
  NSMutableDictionary* content = [NSMutableDictionary dictionaryWithDictionary: self.message.content];
  
  content[CTNInternalFileReferenceKey] = [fileReference description];
  self.message.content = content;
  [[CTNMessageStore outboxMessageStore] saveMessage: self.message allowUpdate: YES];
  
  self.dataURL = [NSURL fileURLWithPath: destinationPath];
  
  return YES;
}

- (BOOL) copyDataAtPath: (NSString*) sourcePath
                 toPath: (NSString*) destinationPath
                  error: (NSError**) error
{
  
  return [[NSFileManager defaultManager] copyItemAtPath:  [self normalizedPathFromPath: sourcePath] toPath: destinationPath error: error];
}

- (BOOL) writeContent: (NSString*) content
               toPath: (NSString*) destinationPath
                error: (NSError**) error
{
  NSString* contentType = [self contentType];
  NSData* data = nil;
  
  if ([contentType isEqualToString: @"application/json"])
  {
    data = CTNDataFromJSONObject(content);
  }
  else if ([contentType rangeOfString: @"text/"].location == 0 && [content isKindOfClass: [NSString class]])
  {
    data = [(NSString*) content dataUsingEncoding: NSUTF8StringEncoding];
  }
  else if ([content isKindOfClass: [NSString class]])
  {
    if (self.base64EncodeRequestContent)
    {
      data = [(NSString*) content dataUsingEncoding: NSUTF8StringEncoding];
    }
    else
    {
      data = [[NSData alloc] initWithBase64EncodedString: (NSString*) content options: 0];
    }
  }
  else
  {
    if (error)
    {
      *error = [NSError errorWithDomain: CTNErrorDomain
                                   code: CTNBadArgument
                               userInfo: @{NSLocalizedDescriptionKey: @"cannot handle data"}];
    }
    
    return NO;
  }
  
  if (data)
  {
    return [data writeToFile: destinationPath options: NSDataWritingAtomic error: error];
  }
  else
  {
    if (error)
    {
      *error = [NSError errorWithDomain: CTNErrorDomain
                                   code: CTNBadArgument
                               userInfo: @{NSLocalizedDescriptionKey: @"cannot handle data"}];
    }
    
    return NO;
  }
}

- (BOOL) writeMultipartFormData: (NSString*) data
                         toPath: (NSString*) destinationPath
                          error: (NSError**) error
{
  NSOutputStream* outputStream = [NSOutputStream outputStreamToFileAtPath: destinationPath append: NO];
  
  if (outputStream)
  {
    [outputStream open];
    
    BOOL success =
    [self writeString: [self multipartFormHeader] toOutputStream: outputStream] &&
    [self writeString: data toOutputStream: outputStream] &&
    [self writeString: [self mulitpartFormFooter] toOutputStream: outputStream];
    
    [outputStream close];
    
    if (!success && error)
    {
      *error = outputStream.streamError;
    }
    
    return success;
  }
  else
  {
    *error = [NSError errorWithDomain: CTNErrorDomain
                                 code: CTNBadArgument
                             userInfo: @{NSLocalizedDescriptionKey: @"could not open file to store content"}];
    
    return NO;
  }
}

- (BOOL) copyMultipartFormDataWithPath: (NSString*) path
                                toPath: (NSString*) destinationPath
                                 error: (NSError**) error
{
  NSOutputStream* outputStream = [NSOutputStream outputStreamToFileAtPath: destinationPath append: NO];
  
  if (outputStream)
  {
    [outputStream open];
    
    BOOL success =
    [self writeString: [self multipartFormHeader] toOutputStream: outputStream] &&
    [self copyFileAtPath: path toOutputStream: outputStream] &&
    [self writeString: [self mulitpartFormFooter] toOutputStream: outputStream];
    
    [outputStream close];

    if (!success && error)
    {
      *error = outputStream.streamError;
    }
    
    return success;
  }
  else
  {
    *error = [NSError errorWithDomain: CTNErrorDomain
                                 code: CTNBadArgument
                             userInfo: @{NSLocalizedDescriptionKey: @"could not open file to store content"}];
    
    return NO;
  }
}

- (NSString*) contentDispositon
{
  NSMutableString* contentDisposition = [NSMutableString stringWithString: @"Content-Disposition: form-data"];
  
  if (self.formPartName.length > 0)
  {
    [contentDisposition appendFormat: @"; name=\"%@\"", self.formPartName];
  }
  
  if (self.formPartFilename.length > 0)
  {
    [contentDisposition appendFormat: @"; filename=\"%@\"", self.formPartFilename];
  }
  
  return contentDisposition;
}

- (NSString*) multipartFormHeader
{
  NSMutableString* header =  [NSMutableString string];
  
  [header appendFormat: @"--%@\r\n", self.boundary];
  [header appendFormat: @"%@\r\n", [self contentDispositon]];
  [header appendFormat: @"Content-Type: %@\r\n", self.formPartContentType];

  if (self.base64EncodeRequestContent)
  {
    [header appendString: @"Content-Transfer-Encoding: base64\r\n"];
  }
  
  [header appendString: @"\r\n"];

  return header;
}

- (NSString*) mulitpartFormFooter
{
  return [NSString stringWithFormat: @"\r\n--%@--\r\n", self.boundary];
}

- (BOOL) writeString: (NSString*) string toOutputStream: (NSOutputStream*) outputStream
{
  return [self writeData: [string dataUsingEncoding: NSUTF8StringEncoding] toOutputStream: outputStream];
}

- (BOOL) writeData: (NSData*) data toOutputStream: (NSOutputStream*) outputStream
{
  return [self writeBytes: data.bytes length: data.length toOutputStream: outputStream];
}

- (BOOL) writeBytes: (const uint8_t*) buffer length: (NSUInteger) length toOutputStream: (NSOutputStream*) outputStream
{
  const uint8_t* start = buffer;
  NSUInteger toWrite = length;
  
  while (toWrite > 0)
  {
    NSInteger bytesWritten = [outputStream write: buffer maxLength: length];
    
    if (bytesWritten > 0)
    {
      toWrite -= bytesWritten;
      start += bytesWritten;
    }
    else
    {
      return NO;
    }
  }
  
  return YES;
}

- (BOOL) copyFileAtPath: (NSString*) path toOutputStream: (NSOutputStream*) outputStream
{
  if (self.base64EncodeRequestContent)
  {
    NSData* data = [NSData dataWithContentsOfFile: path];
    
    if (data)
    {
      NSString* base64 = [data base64EncodedStringWithOptions: NSDataBase64Encoding76CharacterLineLength];
      
      return [self writeString: base64 toOutputStream: outputStream];
    }
    else
    {
      return NO;
    }
  }
  else
  {
    NSInputStream* inputStream = [NSInputStream inputStreamWithFileAtPath: path];
    
    if (inputStream)
    {
      [inputStream open];
      
      [self copyStream: inputStream toStream: outputStream];
      [inputStream close];
      
      return YES;
    }
    else
    {
      return NO;
    }
  }
}

- (BOOL) copyStream: (NSInputStream*) inputStream toStream: (NSOutputStream*) outputStream
{
  for (;;)
  {
    uint8_t buffer[64 * 1024];
    NSInteger bytesRead = [inputStream read: buffer maxLength: sizeof(buffer)];
    
    if (bytesRead > 0)
    {
      [self writeBytes: buffer length: bytesRead toOutputStream: outputStream];
    }
    else if (bytesRead == 0)
    {
      return YES;
    }
    else
    {
      return NO;
    }
  }
}

- (BOOL) setMethodWithError: (NSError**) error
{
  id method = self.message.content[@"method"];
  
  if (method && ![method isKindOfClass: [NSNull class]])
  {
    if ([method isKindOfClass: [NSString class]])
    {
      self.method = method;
      
      return YES;
    }
    else
    {
      if (error)
      {
        *error = [NSError errorWithDomain: CTNErrorDomain
                                     code: CTNBadArgument
                                 userInfo: @{NSLocalizedDescriptionKey: @"bad type for method"}];
      }
      
      return NO;
    }
  }
  else
  {
    self.method = self.dataURL ? @"POST" : @"GET";
    
    return YES;
  }
}

- (NSString*) contentType
{
  return [self headerValueForField: @"Content-Type"];
}

- (NSString*) headerValueForField: (NSString*) field
{
  for (id key in self.headers)
  {
    if ([key isKindOfClass: [NSString class]] && [field compare: key options: NSCaseInsensitiveSearch] == NSOrderedSame)
    {
      return self.headers[key];
    }
  }
 
  return nil;
}

- (NSURLRequest*) makeRequest
{
  NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL: self.URL];
  
  [request setHTTPMethod: self.method];
  [self addHeaders: self.headers toRequest: request];
  
  return request;
}

- (void) addHeaders: (NSDictionary*) headers toRequest: (NSMutableURLRequest*) request
{
  BOOL addedContentType = NO;
  
  for (id key in headers)
  {
    if ([key isKindOfClass: [NSString class]])
    {
      BOOL isContentType = [key compare: @"Content-Type" options: NSCaseInsensitiveSearch] == NSOrderedSame;
      
      if (isContentType && self.uploadAsMultipartForm)
      {
        continue;
      }

      id value = headers[key];
      
      if ([value isKindOfClass: [NSString class]])
      {
        [request setValue: value forHTTPHeaderField: key];
        
        if (isContentType)
        {
          addedContentType = YES;
        }
      }
    }
  }
  
  if (!addedContentType)
  {
    NSString* contentType = nil;
    
    if (self.uploadAsMultipartForm)
    {
      contentType = [NSString stringWithFormat: @"multipart/form-data; boundary=%@", self.boundary];
    }
    else if (self.uploadAsFile)
    {
      contentType = CTNMIMETypeFromPath(self.dataURL.path);
    }
    
    if (contentType)
    {
      [request setValue: contentType forHTTPHeaderField: @"Content-Type"];
    }
  }
}

- (void) stop
{
  if (self.isStopped)
  {
    return;
  }
  
  [self.logger traceWithFormat: @"Stopping %@", self];
  
  [self terminateSession];
  
  [super stop];
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

  NSURLSession* session = self.session;
  
  self.session = nil;
  [session invalidateAndCancel];
  self.currentTask = nil;
}

- (NSURLSessionConfiguration*) sessionConfiguration
{
  NSURLSessionConfiguration* config = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier: self.sessionIdentifier];

  config.requestCachePolicy = NSURLCacheStorageNotAllowed;
  config.timeoutIntervalForRequest = 60.0;
  
#ifdef DEBUG_DISABLED
  config.timeoutIntervalForResource = 30.0;
#else
  config.timeoutIntervalForResource = 10 * 60.0;
#endif
  
  [self.logger traceWithFormat: @"Request timeout is %ld, resource timeout is %ld", (long) config.timeoutIntervalForRequest, (long) config.timeoutIntervalForResource];
  
  return config;
}

- (void) postResponse: (NSHTTPURLResponse*) response
{
  NSMutableDictionary* content = [NSMutableDictionary dictionary];

  content[CTNStatusKey] = [NSNumber numberWithInteger: response.statusCode];

  // Remove any internal file reference for the file the outbox message
  // used so we don't try to delete it when we delete this inbox message.
  NSMutableDictionary* config = [NSMutableDictionary dictionaryWithDictionary: self.message.content];
  
  [config removeObjectForKey: CTNInternalFileReferenceKey];
  content[CTNConfigKey] = config;
  
  NSString* statusText = [NSHTTPURLResponse localizedStringForStatusCode: response.statusCode];
  
  if (statusText)
  {
    content[CTNStatusTextKey] = statusText;
  }
  
  if (response.allHeaderFields)
  {
    content[CTNHeadersKey] = response.allHeaderFields;
  }
  
  if (self.responseData)
  {
    NSString* MIMEType = response.MIMEType;
    
    if ([MIMEType isEqualToString: @"application/json"])
    {
      NSError* error = nil;
      id JSON = [NSJSONSerialization JSONObjectWithData: self.responseData options: NSJSONReadingAllowFragments error: &error];
      
      if (JSON)
      {
        content[CTNDataKey] = JSON;
      }
      else
      {
        [self.logger warnWithFormat: @"Cannot parse JSON in response: %@", [error localizedDescription]];
      }
    }
    else if ([MIMEType rangeOfString: @"text/"].location == 0)
    {
      NSString* contentType = [response.allHeaderFields objectForKey: @"Content-Type"];
      NSStringEncoding encoding = [self stringEncodingFromContentType: contentType];
      
      content[CTNDataKey] = [[NSString alloc] initWithData: self.responseData encoding: encoding];
    }
    else
    {
      content[CTNDataKey] = [self.responseData base64EncodedStringWithOptions: 0];
    }
  }
  else if (self.responsePath)
  {
    content[CTNDataKey] = self.responsePath;
    
    // This is added to the content so the file gets cleaned up once the
    // message is deleted.
    content[CTNInternalFileReferenceKey] = [[CTNFileReference fileReferenceWithPath: self.responsePath] description];
  }
  
  CTNMessage* message = [CTNMessage message];
  
  message.content = content;
  message.channel = self.message.channel;
  message.subchannel = self.message.subchannel;
  message.provider = self.provider.name;
  
  [[CTNMessageStore inboxMessageStore] addMessage: message];
}

- (NSStringEncoding) stringEncodingFromContentType: (NSString*) contentType
{
  if (contentType)
  {
    NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern: @"charset=([^;\\s]+)"
                                                                           options: 0
                                                                             error: NULL];
    
    NSTextCheckingResult* result = [regex firstMatchInString: contentType options: 0 range: NSMakeRange(0, contentType.length)];
    
    if (result)
    {
      NSString* charset = [contentType substringWithRange: [result rangeAtIndex: 1]];
      
      return CFStringConvertEncodingToNSStringEncoding(CFStringConvertIANACharSetNameToEncoding((CFStringRef) charset));
    }
  }
  
  return NSUTF8StringEncoding;
}

#pragma mark - NSURLSessionTaskDelegate

- (void) URLSession: (NSURLSession*) session
               task: (NSURLSessionTask*) task
didCompleteWithError: (NSError*) error
{
  if (session != self.session)
  {
    return;
  }

  NSHTTPURLResponse* response = (NSHTTPURLResponse*) task.response;
  
  [self.logger traceWithFormat: @"Task did complete for for %@ with status %lu", self, (long) response.statusCode];
  
  if (error)
  {
    [self didFailWithError: error retry: CTNRetryAfterDefaultPeriod];
  }
  else
  {
    if (self.responseBuffer)
    {
      if (self.downloadAsFile)
      {
        self.responsePath = CTNUniquePathWithExtension(@".bin");
        
        NSError* error = nil;
        
        if ([self.responseBuffer writeToFile: self.responsePath options: 0 error: &error])
        {
          [self.logger traceWithFormat: @"Copied downloaded data to %@", self.responsePath];
        }
        else
        {
          [self.logger warnWithFormat: @"Cannot copy downloaded data to %@: %@", self.responsePath, [error localizedDescription]];
          
          self.fileError = error;
        }
      }
      else
      {
        self.responseData = self.responseBuffer;
      }
    }
    
    if (self.fileError)
    {
      [self didFailWithError: self.fileError retry: CTNRetryNever];
    }
    else
    {
      [self didSucceed];
      [self postResponse: response];
    }
    
    [self terminateSession];
  }
}

- (void) URLSession: (NSURLSession*) session
               task: (NSURLSessionTask*) task
didReceiveChallenge: (NSURLAuthenticationChallenge*) challenge
  completionHandler: (void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential*)) completionHandler
{
  if (session != self.session)
  {
    return;
  }
  
  // TODO: cope with being asked to accept a HTTPS certificate.

  NSHTTPURLResponse* response = [[NSHTTPURLResponse alloc] initWithURL: self.URL
                                                            statusCode: 401
                                                           HTTPVersion: @"1.1"
                                                          headerFields: nil];
  
  [self postResponse: response];
  completionHandler(NSURLSessionAuthChallengeCancelAuthenticationChallenge, nil);
  [self terminateSession];
}

#pragma mark - NSURLSessionDataDelegate

- (void) URLSession: (NSURLSession*) session
           dataTask: (NSURLSessionDataTask*) task
     didReceiveData: (NSData*) data
{
  if (self.responseBuffer)
  {
    [self.responseBuffer appendData: data];
  }
  else
  {
    self.responseBuffer = [NSMutableData dataWithData: data];
  }
}

#pragma mark - NSURLSessionDownloadDelegate

- (void) URLSession: (NSURLSession*) session
       downloadTask: (NSURLSessionDownloadTask*) task
didFinishDownloadingToURL: (NSURL*) location
{
  if (session != self.session)
  {
    return;
  }
  
  [self.logger traceWithFormat: @"Download for %@ is available at %@", self, location];

  if (self.downloadAsFile)
  {
    self.responsePath = CTNUniquePathWithExtension([location.path pathExtension]);
    
    NSError* error = nil;
    
    if ([[NSFileManager defaultManager] copyItemAtPath: location.path toPath: self.responsePath error: &error])
    {
      [self.logger traceWithFormat: @"Copied downloaded data to %@", self.responsePath];
    }
    else
    {
      [self.logger warnWithFormat: @"Cannot copy downloaded data to %@: %@", self.responsePath, [error localizedDescription]];
      
      self.fileError = error;
    }
  }
  else
  {
    self.responseData = [NSData dataWithContentsOfFile: location.path];
    
    if (!self.responseData)
    {
      self.fileError = [NSError errorWithDomain: @"" code: -1 userInfo: @{NSLocalizedDescriptionKey: @"failed to read downloaded data"}];
    }
  }
}

@end
