//
//  SQLStatement.m
//  Database
//
//  Created by Gary Meehan on 30/01/2013.
//  Copyright (c) 2013 CommonTime. All rights reserved.
//

#import "SQLStatement.h"

#import "SQLDatabase.h"

@interface SQLStatement()

@property (nonatomic, readwrite, strong) SQLDatabase* database;
@property (nonatomic, readwrite, assign) sqlite3_stmt* handle;

@end

@implementation SQLStatement

- (id) initWithDatabase: (SQLDatabase*) database
                  query: (NSString*) query
{
  if ((self = [super init]))
  {
    sqlite3_stmt* handle = NULL;
    
    if (sqlite3_prepare_v2(database.handle, [query UTF8String], -1, &handle, NULL) == SQLITE_OK)
    {
      self.database = database;
      self.handle = handle;
    }
    else
    {
      self = nil;
    }
  }
  
  return self;
}

- (id) initWithDatabase: (SQLDatabase*) database
            queryFormat: (NSString*) format, ...
{
  if ((self = [super init]))
  {
    va_list args;
    va_start(args, format);
    
    NSString* query = [[NSString alloc] initWithFormat: format arguments: args];
    
    va_end(args);
    
    sqlite3_stmt* handle = NULL;

    if (sqlite3_prepare_v2(database.handle, [query UTF8String], -1, &handle, NULL) == SQLITE_OK)
    {
      self.database = database;
      self.handle = handle;
    }
    else
    {
      self = nil;
    }
  }
  
  return self;
}

- (id) initWithDatabase: (SQLDatabase*) database
      paramterizedQuery: (NSString*) query
{
  if ((self = [super init]))
  {
    sqlite3_stmt* handle = NULL;
    
    if (sqlite3_prepare_v2(database.handle, [query UTF8String], -1, &handle, NULL) == SQLITE_OK)
    {
      self.database = database;
      self.handle = handle;
    }
    else
    {
      self = nil;
    }
  }
  
  return self;
}

- (void) dealloc
{
  sqlite3_finalize(self.handle);
}

- (SQLResult) bindInt: (int) value toColumn: (int) column
{
  return sqlite3_bind_int(self.handle, column, value);
}

- (SQLResult) bindString: (NSString*) value toColumn: (int) column
{
  if (value)
  {
    NSData* data = [value dataUsingEncoding: NSUTF8StringEncoding];
    
    return sqlite3_bind_text(self.handle, column, [data bytes], (int) [data length], SQLITE_TRANSIENT);
  }
  else
  {
    return sqlite3_bind_null(self.handle, column);
  }
}

- (SQLResult) bindData: (NSData*) data toColumn: (int) column
{
  if (data)
  {
    return sqlite3_bind_blob(self.handle, column, [data bytes], (int) [data length], SQLITE_TRANSIENT);
  }
  else
  {
    return sqlite3_bind_null(self.handle, column);
  }
}

- (SQLResult) bindLongLong: (long long) value toColumn: (int) column
{
  return sqlite3_bind_int64(self.handle, column, (sqlite3_int64) value);
}

- (SQLResult) bindDouble: (double) value toColumn: (int) column
{
  return sqlite3_bind_double(self.handle, column, value);
}

- (int) columnCount
{
  return sqlite3_column_count(self.handle);
}

- (SQLResult) step
{
  return sqlite3_step(self.handle);
}

- (int) intAtColumn: (int) column
{
  return sqlite3_column_int(self.handle, column);
}

- (long long) longLongAtColumn:(int)column
{
  return (long long) sqlite3_column_int64(self.handle, column);
}

- (double) doubleAtColumn: (int) column
{
  return sqlite3_column_double(self.handle, column);
}

- (NSString*) stringAtColumn: (int) column
{
  const unsigned char* text = sqlite3_column_text(self.handle, column);
  
  if (text)
  {
    return [NSString stringWithCString: (const char*) text
                              encoding: NSUTF8StringEncoding];
  }
  else
  {
    return nil;
  }
}

- (NSData*) dataAtColumn: (int) column
{
  int length = sqlite3_column_bytes(self.handle, column);
  
  if (length > 0)
  {
    const void* bytes = sqlite3_column_blob(self.handle, column);
    
    return [NSData dataWithBytes: bytes length: length];
  }
  else
  {
    return nil;
  }
}

@end
