//
//  SQLDatabase.m
//  Database
//
//  Created by Gary Meehan on 30/01/2013.
//  Copyright (c) 2013 CommonTime. All rights reserved.
//

#import "SQLDatabase.h"

#import <sqlite3.h>

#import "SQLStatement.h"

@interface SQLDatabase()

@property (nonatomic, readwrite, assign) sqlite3* handle;

@end;

@implementation SQLDatabase

+ (id) databaseWithPath: (NSString*) path
{
  return[[SQLDatabase alloc] initWithPath: path];
}

- (id) initWithPath: (NSString*) path
{
  if ((self = [super init]))
  {
    sqlite3* handle = NULL;
    
    if (sqlite3_open([path UTF8String], &handle) == SQLITE_OK)
    {
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
  sqlite3_close(self.handle);
}

- (NSError*) lastError
{
  int errorCode = sqlite3_errcode(self.handle);
  
  if (errorCode == SQLITE_OK)
  {
    return nil;
  }
  else
  {
    NSString* errorMessage = [NSString stringWithCString: sqlite3_errmsg(self.handle)
                                                encoding: NSUTF8StringEncoding];
    
    NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                              errorMessage, NSLocalizedDescriptionKey,
                              nil];
    
    return [NSError errorWithDomain: @"SQLite"
                               code: errorCode
                           userInfo: userInfo];
  }
}

- (SQLStatement*) statementWithQuery: (NSString*) query
{
  return [[SQLStatement alloc] initWithDatabase: self query: query];
}

- (SQLStatement*) statementWithQueryFormat: (NSString*) format, ...
{
  va_list args;
  va_start(args, format);
  
  NSString* query = [[NSString alloc] initWithFormat: format arguments: args];
  
  id statement = [[SQLStatement alloc] initWithDatabase: self
                                                  query: query];
  
  va_end(args);
  
  return statement;
}

- (SQLStatement*) statementWithParameterizedQuery: (NSString*) query
{
 return [[SQLStatement alloc] initWithDatabase: self paramterizedQuery: query];
}

- (BOOL) containsTableWithName: (NSString*) name
{
  NSString* existsCommand = @"SELECT name FROM sqlite_master WHERE type='table' AND name='%@';";
  SQLStatement* statement = [self statementWithQueryFormat: existsCommand, name];
  
  if (statement)
  {
    return [statement step] == SQLITE_ROW;
  }
  else
  {
    return NO;
  }
}

- (void) compact
{
  sqlite3_exec(self.handle, "VACUUM;", NULL, NULL, NULL);
}

- (long long) lastInsertRowIdentifier
{
  return sqlite3_last_insert_rowid(self.handle);
}

@end
