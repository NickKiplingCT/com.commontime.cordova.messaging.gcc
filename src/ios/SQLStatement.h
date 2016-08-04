//
//  SQLStatement.h
//  Database
//
//  Created by Gary Meehan on 30/01/2013.
//  Copyright (c) 2013 CommonTime. All rights #ireserved.
//

#import <Foundation/Foundation.h>

@class SQLDatabase;

typedef int SQLResult;

@interface SQLStatement : NSObject

@property (nonatomic, readonly, assign) int columnCount;

- (id) initWithDatabase: (SQLDatabase*) database
                  query: (NSString*) query;

- (id) initWithDatabase: (SQLDatabase*) database
            queryFormat: (NSString*) format, ... NS_FORMAT_FUNCTION(2, 3);

- (id) initWithDatabase: (SQLDatabase*) database
      paramterizedQuery: (NSString*) query;

- (SQLResult) step;

- (SQLResult) bindInt: (int) value toColumn: (int) column;

- (SQLResult) bindLongLong: (long long) value toColumn: (int) column;

- (SQLResult) bindDouble: (double) value toColumn: (int) column;

- (SQLResult) bindString: (NSString*) value toColumn: (int) column;

- (SQLResult) bindData: (NSData*) data toColumn: (int) column;

- (int) intAtColumn: (int) column;

- (long long) longLongAtColumn: (int) column;

- (double) doubleAtColumn: (int) column;

- (NSString*) stringAtColumn: (int) column;

- (NSData*) dataAtColumn: (int) column;

@end
