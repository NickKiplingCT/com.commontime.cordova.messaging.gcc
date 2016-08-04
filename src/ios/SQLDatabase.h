//
//  SQLDatabase.h
//  Database
//
//  Created by Gary Meehan on 30/01/2013.
//  Copyright (c) 2013 CommonTime. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <sqlite3.h>

@class SQLStatement;

@interface SQLDatabase : NSObject

@property (nonatomic, readonly) sqlite3* handle;

+ (id) databaseWithPath: (NSString*) path;

- (id) initWithPath: (NSString*) path;

- (NSError*) lastError;

- (SQLStatement*) statementWithQuery: (NSString*) query;

- (SQLStatement*) statementWithQueryFormat: (NSString*) format, ... NS_FORMAT_FUNCTION(1, 2);

- (SQLStatement*) statementWithParameterizedQuery: (NSString*) query;

- (BOOL) containsTableWithName: (NSString*) name;

- (void) compact;

- (long long) lastInsertRowIdentifier;

@end
