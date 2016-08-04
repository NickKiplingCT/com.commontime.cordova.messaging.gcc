//
//  CTUtility.m
//  AzureTester
//
//  Created by Gary Meehan on 29/10/2012.
//  Copyright (c) 2012 CommonTime. All rights reserved.
//

#import "CTNUtility.h"

#import <MobileCoreServices/MobileCoreServices.h>

#pragma mark - URL-Encoding forms and strings

NSString* CTNURLEncodeString(NSString* string)
{
  CFStringRef encoded = CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault,
                                                                (CFStringRef) string,
                                                                NULL,
                                                                CFSTR(":/?#[]@!$&'()*+,;="),
                                                                kCFStringEncodingUTF8);
  
  return ((NSString*) CFBridgingRelease(encoded));
}

NSString* CTNURLDecodeString(NSString* string)
{
  NSString* stringWithSpaces = [string stringByReplacingOccurrencesOfString: @"+" withString: @" "];
  
  CFStringRef decoded = CFURLCreateStringByReplacingPercentEscapesUsingEncoding(kCFAllocatorDefault,
                                                                                (CFStringRef) stringWithSpaces,
                                                                                CFSTR(""),
                                                                                kCFStringEncodingUTF8);
  
  return ((NSString*) CFBridgingRelease(decoded));
}

NSData* CTNURLEncodeForm(NSDictionary* form)
{
  BOOL addSeparator = NO;
  NSMutableData* data = [NSMutableData data];
  
  for (NSString* key in form)
  {
    NSString* format = addSeparator ? @"&%@=%@" : @"%@=%@";
    NSString* pair = [NSString stringWithFormat: format,
                      CTNURLEncodeString(key),
                      CTNURLEncodeString([form objectForKey: key])];
    
    [data appendData: [pair dataUsingEncoding: NSUTF8StringEncoding]];
    addSeparator = YES;
  }
  
  return data;
}

NSDictionary* CTNURLDecodeForm(NSData* data)
{
  NSString* string = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
  NSArray* fields = [string componentsSeparatedByString: @"&"];
  NSMutableDictionary* form = [NSMutableDictionary dictionary];
  
  for (NSString* field in fields)
  {
    NSArray* parts = [field componentsSeparatedByString: @"="];
    
    if ([parts count] == 2)
    {
      [form setObject: CTNURLDecodeString([parts objectAtIndex: 1])
               forKey: [parts objectAtIndex: 0]];
    }
  }
  
  return form;
}

NSString* CTNURLEncodeQueryParameters(NSDictionary* parameters)
{
  BOOL addSeparator = NO;
  NSMutableString* string = [NSMutableString string];
  
  for (id key in parameters)
  {
    id value = parameters[key];
    NSString* pair = nil;
    
    if ([key isKindOfClass: [NSString class]])
    {
      if ([value isKindOfClass: [NSNumber class]])
      {
        NSString* format = addSeparator ? @"&%@=%@" : @"%@=%@";
        
        pair = [NSString stringWithFormat: format, CTNURLEncodeString(key), value];
      }
      else if ([value isKindOfClass: [NSString class]])
      {
        NSString* format = addSeparator ? @"&%@=%@" : @"%@=%@";
        
        pair = [NSString stringWithFormat: format, CTNURLEncodeString(key), CTNURLEncodeString(value)];
      }
      else if ([value isKindOfClass: [NSNull class]])
      {
        NSString* format = addSeparator ? @"&%@" : @"%@";
        
        pair = [NSString stringWithFormat: format, CTNURLEncodeString(key)];
      }
      else
      {
        NSString* format = addSeparator ? @"&%@=%@" : @"%@=%@";
        NSData* data = [NSJSONSerialization dataWithJSONObject: value options: 0 error: NULL];
        
        if (data)
        {
          pair = [NSString stringWithFormat: format, CTNURLEncodeString(key), CTNURLEncodeString([[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding])];
        }
      }
    }
    
    if (pair)
    {
      [string appendString: pair];
      addSeparator = YES;
    }
  }
  
  return string;
}

#pragma mark - Formatting memory

NSString* CTNFormatBytes(unsigned long long bytes)
{
  if (bytes < 1024)
  {
    return [NSString stringWithFormat: @"%llu bytes", bytes];
  }
  else if (bytes < 1024 * 1024)
  {
    return [NSString stringWithFormat: @"%llu bytes (%.1lf KB)", bytes, bytes / 1024.0];
  }
  else if (bytes < 1024 * 1024 * 1024)
  {
    return [NSString stringWithFormat: @"%llu bytes (%.1lf MB)", bytes, bytes / (1024.0 * 1024.0)];
  }
  else
  {
    return [NSString stringWithFormat: @"%llu bytes (%.1lf GB)", bytes, bytes / (1024.0 * 1024.0 * 1024.0)];
  }
}

#pragma mark - MIME types

NSString* CTNMIMETypeFromPath(NSString* path)
{
  NSString* extension = [path pathExtension];
  
  if ([extension length] == 0)
  {
    NSInputStream* inputStream = [NSInputStream inputStreamWithFileAtPath: path];
    
    if (inputStream)
    {
      [inputStream open];
      
      uint8_t buffer[256];
      NSInteger length = [inputStream read: buffer maxLength: sizeof(buffer)];
      
      [inputStream close];
      
      if (length > 0)
      {
        return CTNMIMETypeFromBytes(buffer, length);
      }
      else
      {
        return @"application/octet-stream";
      }
    }
    else
    {
      return @"application/octet-stream";
    }
  }
  else
  {
    return CTNMIMETypeFromExtension(extension);
  }
}

NSString* CTNMIMETypeFromData(NSData* data)
{
  return CTNMIMETypeFromBytes([data bytes], [data length]);
}

NSString* CTNMIMETypeFromBytes(const uint8_t* bytes, NSInteger length)
{
  static const uint8_t BMP[] = { 66, 77 };
  static const uint8_t DOC[] = { 208, 207, 17, 224, 161, 177, 26, 225 };
  static const uint8_t EXE_DLL[] = { 77, 90 };
  static const uint8_t GIF[] = { 71, 73, 70, 56 };
  static const uint8_t ICO[] = { 0, 0, 1, 0 };
  static const uint8_t JPG[] = { 255, 216, 255 };
  static const uint8_t MP3[] = { 255, 251, 48 };
  static const uint8_t OGG[] = { 79, 103, 103, 83, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0 };
  static const uint8_t PDF[] = { 37, 80, 68, 70, 45, 49, 46 };
  static const uint8_t PNG[] = { 137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82 };
  static const uint8_t RAR[] = { 82, 97, 114, 33, 26, 7, 0 };
  static const uint8_t SWF[] = { 70, 87, 83 };
  static const uint8_t TIFF[] = { 73, 73, 42, 0 };
  static const uint8_t TORRENT[] = { 100, 56, 58, 97, 110, 110, 111, 117, 110, 99, 101 };
  static const uint8_t TTF[] = { 0, 1, 0, 0, 0 };
  static const uint8_t WAV_AVI[] = { 82, 73, 70, 70 };
  static const uint8_t WMV_WMA[] = { 48, 38, 178, 117, 142, 102, 207, 17, 166, 217, 0, 170, 0, 98, 206, 108 };
  static const uint8_t ZIP_DOCX[] = { 80, 75, 3, 4 };
  
  if (length >= sizeof(BMP) && memcmp(BMP, bytes, sizeof(BMP)) == 0)
  {
    return @"image/bmp";
  }
  else if (length >= sizeof(DOC) && memcmp(DOC, bytes, sizeof(DOC)) == 0)
  {
    return @"application/msword";
  }
  else if (length >= sizeof(EXE_DLL) && memcmp(EXE_DLL, bytes, sizeof(EXE_DLL)) == 0)
  {
    return @"application/x-msdownload";
  }
  else if (length >= sizeof(GIF) && memcmp(GIF, bytes, sizeof(GIF)) == 0)
  {
    return @"image/gif";
  }
  else if (length >= sizeof(ICO) && memcmp(ICO, bytes, sizeof(ICO)) == 0)
  {
    return @"image/x-icon";
  }
  else if (length >= sizeof(JPG) && memcmp(JPG, bytes, sizeof(JPG)) == 0)
  {
    return @"image/jpeg";
  }
  else if (length >= sizeof(MP3) && memcmp(MP3, bytes, sizeof(MP3)) == 0)
  {
    return @"audio/mpeg";
  }
  else if (length >= sizeof(OGG) && memcmp(OGG, bytes, sizeof(OGG)) == 0)
  {
    return @"application/ogg";
  }
  else if (length >= sizeof(PDF) && memcmp(PDF, bytes, sizeof(PDF)) == 0)
  {
    return @"application/pdf";
  }
  else if (length >= sizeof(PNG) && memcmp(PNG, bytes, sizeof(PNG)) == 0)
  {
    return @"image/png";
  }
  else if (length >= sizeof(RAR) && memcmp(RAR, bytes, sizeof(RAR)) == 0)
  {
    return @"application/x-rar-compressed";
  }
  else if (length >= sizeof(SWF) && memcmp(SWF, bytes, sizeof(SWF)) == 0)
  {
    return @"application/x-shockwave-flash";
  }
  else if (length >= sizeof(TIFF) && memcmp(TIFF, bytes, sizeof(TIFF)) == 0)
  {
    return @"image/tiff";
  }
  else if (length >= sizeof(TORRENT) && memcmp(TORRENT, bytes, sizeof(TORRENT)) == 0)
  {
    return @"application/x-bittorrent";
  }
  else if (length >= sizeof(TTF) && memcmp(TTF, bytes, sizeof(TTF)) == 0)
  {
    return @"application/x-font-ttf";
  }
  else if (length >= sizeof(WAV_AVI) && memcmp(WAV_AVI, bytes, sizeof(WAV_AVI)) == 0)
  {
    return @"video/x-msvideo";
  }
  else if (length >= sizeof(WMV_WMA) && memcmp(WMV_WMA, bytes, sizeof(WMV_WMA)) == 0)
  {
    return @"video/x-ms-wmv";
  }
  else if (length >= sizeof(ZIP_DOCX) && memcmp(ZIP_DOCX, bytes, sizeof(ZIP_DOCX)) == 0)
  {
    return @"application/x-zip-compressed";
  }
  else
  {
    return @"application/octet-stream";
  }
}

NSString* CTNMIMETypeFromExtension(NSString* extension)
{
  CFStringRef UTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef) extension, NULL);
  CFStringRef mimeType = UTTypeCopyPreferredTagWithClass (UTI, kUTTagClassMIMEType);
  CFRelease(UTI);

  if (mimeType)
  {
    return CFBridgingRelease(mimeType);
  }
  else
  {
    return @"application/octet-stream";
  }
}

NSString* CTNExtensionFromMIMEType(NSString* MIMEType)
{
  if (MIMEType)
  {
    CFStringRef UTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, (__bridge CFStringRef) MIMEType, NULL);
    CFStringRef extension = UTTypeCopyPreferredTagWithClass (UTI, kUTTagClassFilenameExtension);
    CFRelease(UTI);
    
    if (extension)
    {
      return CFBridgingRelease(extension);
    }
  }
  
  return nil;
}

NSString* CTNStringFromJSONObject(id object)
{
  if (object)
  {
    if ([object isKindOfClass: [NSString class]])
    {
      return [NSString stringWithFormat: @"\"%@\"", object];
    }
    else
    {
      NSData* data = [NSJSONSerialization dataWithJSONObject: object
                                                     options: 0
                                                       error: NULL];
      
      return [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
    }
  }
  else
  {
    return nil;
  }
}

id CTNJSONObjectFromString(NSString* string)
{
  if (string)
  {
    if ([string length] > 2 && [string characterAtIndex: 0] == '"')
    {
      return [string substringWithRange: NSMakeRange(1, [string length] - 2)];
    }
    else
    {
      NSData* data = [string dataUsingEncoding: NSUTF8StringEncoding];
      
      return [NSJSONSerialization JSONObjectWithData: data options: 0 error: NULL];
    }
  }
  else
  {
    return nil;
  }
}

NSData* CTNDataFromJSONObject(id object)
{
  if (object)
  {
    if ([object isKindOfClass: [NSString class]])
    {
      NSString* quotedString = [NSString stringWithFormat: @"\"%@\"", object];
      
      return [quotedString dataUsingEncoding: NSUTF8StringEncoding];
    }
    else
    {
      return [NSJSONSerialization dataWithJSONObject: object
                                             options: 0
                                               error: NULL];
    }
  }
  else
  {
    return nil;
  }
}

id CTNJSONObjectFromData(NSData* data)
{
  if (data)
  {
    if (data.length > 2 && ((const uint8_t*) data.bytes)[0] == '"')
    {
      NSString* quotedString = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
      
      return [quotedString substringWithRange: NSMakeRange(1, quotedString.length - 2)];
    }
    else
    {
      return [NSJSONSerialization JSONObjectWithData: data options: 0 error: NULL];
    }
  }
  else
  {
    return nil;
  }
}

NSString* CTNDocumentsDirectory()
{
  NSArray* paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
  
  if ([paths count] == 0)
  {
    return nil;
  }
  else
  {
    return [paths objectAtIndex: 0];
  }
}

NSString* CTNUniquePathWithExtension(NSString* extension)
{
  NSString* filename = [[NSUUID UUID] UUIDString];
  
  if ([extension length] > 0)
  {
    filename = [filename stringByAppendingPathExtension: extension];
  }
  
  return [CTNDocumentsDirectory() stringByAppendingPathComponent: filename];
}
