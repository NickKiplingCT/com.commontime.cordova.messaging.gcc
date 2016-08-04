//
//  CTNMessageStore.m
//  AzureTester
//
//  Created by Gary Meehan on 29/10/2012.
//  Copyright (c) 2012 CommonTime. All rights reserved.
//

#import "CTNMessageStore.h"

#import "CTLogger.h"
#import "SQLDatabase.h"
#import "SQLStatement.h"

#import "CTNAzureStorageBlobAttachment.h"
#import "CTNAzureStorageBlobReference.h"
#import "CTNConstants.h"
#import "CTNContentReference.h"
#import "CTNFileReference.h"
#import "CTNMessage.h"
#import "CTNNotificationProvider.h"
#import "CTNNotificationProviderManager.h"
#import "CTNUtility.h"

static const NSTimeInterval CTNDeletionStubLifespan = 48 * 60 * 60.0;
static const NSUInteger MaxContentBytes = 4 * 1024;

enum
{
  CTNAttachmentTypeNone = 0,
  CTNAttachmentTypeAzureBlobStorage = 1,
};

@interface CTNMessageStore()

@property (nonatomic, readonly) CTLogger* logger;

@property (nonatomic, readwrite, strong) NSTimer* purgeTimer;
@property (nonatomic, readwrite, assign) BOOL deleteMessagesImmediately;

@property (nonatomic, readwrite, strong) SQLDatabase* database;
@property (nonatomic, readwrite, strong) NSString* storeTable;
@property (nonatomic, readwrite, strong) NSString* receiversTable;
@property (nonatomic, readwrite, strong) NSString* attachmentsTable;

@end

@implementation CTNMessageStore

+ (CTNMessageStore*) inboxMessageStore
{
  static CTNMessageStore* inbox;
  
  if (!inbox)
  {
    inbox = [[CTNMessageStore alloc] initWithName: @"Inbox"
                                         filename: @"inbox.sql"];
    
    inbox.deleteMessagesImmediately = NO;
  }
  
  return inbox;
}

+ (CTNMessageStore*) outboxMessageStore
{
  static CTNMessageStore* outbox;
  
  if (!outbox)
  {
    outbox = [[CTNMessageStore alloc] initWithName: @"Outbox"
                                          filename: @"outbox.sql"];
    
    outbox.deleteMessagesImmediately = YES;
  }
  
  return outbox;
}

- (id) initWithName: (NSString*) name
           filename: (NSString*) filename
{
  if ((self = [super init]))
  {
    if (filename)
    {
      NSArray* paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
      NSString* path = nil;
      
      if (paths.count > 0)
      {
        path = [[paths objectAtIndex: 0] stringByAppendingPathComponent: filename];
        
        self.database = [SQLDatabase databaseWithPath: path];
        
        if (self.database)
        {
          self.storeTable = name;
          self.receiversTable = [NSString stringWithFormat: @"%@_receivers", name];
          self.attachmentsTable = [NSString stringWithFormat: @"%@_attachments", name];
          
          if ([self.database containsTableWithName: name] ||
              ([self createStoreTable] && [self createReceiversTable] && [self createAttachmentsTable]))
          {
#ifdef DEBUG
            [self logStoreTable];
#endif
            
            [self startPurgeTimer];
            
            return self;
          }
        }
      }
    }
  }
  
  self = nil;
  
  return self;
}

- (CTLogger*) logger
{
  return [CTNNotificationProviderManager sharedManager].logger;
}

- (BOOL) createStoreTable
{
  NSString* format = @"CREATE TABLE %@("
  "identifier TEXT PRIMARY KEY NOT NULL, "
  "channel TEXT, "
  "subchannel TEXT, "
  "content TEXT, "
  "notification TEXT, "
  "sentdate REAL, "
  "expirydate REAL, "
  "provider TEXT,"
  "deleted INT"
  ");";
  
  NSString* query = [NSString stringWithFormat: format, self.storeTable];
  SQLStatement* statement = [self.database statementWithQuery: query];
  
  if (!statement)
  {
    [self.logger warnWithFormat: @"Cannot create store table: %@", [[self.database lastError] localizedDescription]];
    
    return NO;
  }
  
  if ([statement step] == SQLITE_DONE)
  {
    return YES;
  }
  else
  {
    [self.logger warnWithFormat: @"Cannot create store table: %@", [[self.database lastError] localizedDescription]];
    
    return NO;
  }
}

- (BOOL) createReceiversTable
{
  NSString* format = @"CREATE TABLE %@("
  "identifier TEXT NOT NULL, "
  "receiver TEXT NOT NULL"
  ");";
  
  NSString* query = [NSString stringWithFormat: format, self.receiversTable];
  SQLStatement* statement = [self.database statementWithQuery: query];
  
  if (!statement)
  {
    [self.logger warnWithFormat: @"Cannot create receivers table: %@", [[self.database lastError] localizedDescription]];
    
    return NO;
  }
  
  if ([statement step] == SQLITE_DONE)
  {
    return YES;
  }
  else
  {
    [self.logger warnWithFormat: @"Cannot create receivers table: %@", [[self.database lastError] localizedDescription]];
    
    return NO;
  }
}

- (BOOL) createAttachmentsTable
{
  NSString* format = @"CREATE TABLE %@("
  "identifier STRING PRIMARY KEY, "
  "type INT, "
  "messageidentifier TEXT, "
  "localref TEXT, "
  "remoteref TEXT, "
  "status INT, "
  "sessionidentifier TEXT"
  ");";
  
  NSString* query = [NSString stringWithFormat: format, self.attachmentsTable];
  SQLStatement* statement = [self.database statementWithQuery: query];
  
  if (!statement)
  {
    [self.logger warnWithFormat: @"Cannot create attachments table: %@", [[self.database lastError] localizedDescription]];
    
    return NO;
  }
  
  if ([statement step] == SQLITE_DONE)
  {
    return YES;
  }
  else
  {
    [self.logger warnWithFormat: @"Cannot create attachments table: %@", [[self.database lastError] localizedDescription]];
    
    return NO;
  }
}

- (void) logStoreTable
{
  [self.logger traceWithFormat: @"Contents of %@:", self.storeTable];
  
  NSString* format = @"SELECT "
  "identifier, "
  "channel, "
  "subchannel, "
  "content, "
  "notification, "
  "sentdate, "
  "expirydate, "
  "provider, "
  "deleted "
  "FROM %@;";
  
  NSString* query = [NSString stringWithFormat: format, self.storeTable];
  SQLStatement* statement = [self.database statementWithParameterizedQuery: query];
  
  if (!statement)
  {
    [self.logger warnWithFormat: @"Cannot send message: %@", [[self.database lastError] localizedDescription]];
    
    return;
  }
  
  while ([statement step] == SQLITE_ROW)
  {
    CTNMessage* message = [self messageFromStatement: statement expandContent: NO];
    
    [self.logger traceWithFormat: @"  %@ | %@ | %@ | %@ | %@ | %@ | %@ | %@ | %@",
     message.identifier,
     message.channel,
     message.subchannel,
     message.content,
     message.notification,
     message.sentDate,
     message.expiryDate,
     message.provider,
     message.isDeleted == 0 ? @"" : @"<deleted>"];
  }
}

- (void) dealloc
{
  if (self.purgeTimer.isValid)
  {
    [self.purgeTimer invalidate];
  }
}

- (NSString*) description
{
  return self.storeTable;
}

- (void) startPurgeTimer
{
  self.purgeTimer = [NSTimer scheduledTimerWithTimeInterval: 15 * 60.0
                                                     target: self
                                                   selector: @selector(purgeExpiredMessagesWithTimer:)
                                                   userInfo: nil
                                                    repeats: YES];
}

- (void) purgeExpiredMessagesWithTimer: (NSTimer*) timer
{
  NSArray* expired = [self expiredMessageIdentifiers];
  
  if ([expired count] > 0)
  {
    [self.logger traceWithFormat: @"Purging %lu expired messages in %@", (unsigned long) [expired count], self];
    
    for (NSString* identifier in expired)
    {
      CTNMessage* message = [self messageForIdentifier: identifier];
      
      [self removeExpiredMessage: message];
    }

    [self.database compact];
  }
}

- (NSArray*) expiredMessageIdentifiers
{
  NSString* format = @"SELECT identifier FROM %@ WHERE expiryDate < ?;";
  NSString* query = [NSString stringWithFormat: format, self.storeTable];
  SQLStatement* statement = [self.database statementWithParameterizedQuery: query];
  
  if (!statement)
  {
    [self.logger warnWithFormat: @"Cannot find expired messages: %@", [[self.database lastError] localizedDescription]];
    
    return nil;
  }
  
  [statement bindDouble: [[NSDate date] timeIntervalSince1970] toColumn: 1];
  
  NSMutableArray* expired = [NSMutableArray array];
  
  while ([statement step] == SQLITE_ROW)
  {
    [expired addObject: [statement stringAtColumn: 0]];
  }
  
  return expired;
}

- (void) removeExpiredMessage: (CTNMessage*) message
{
  if (message)
  {
    CTNNotificationProviderManager* providerManager = [CTNNotificationProviderManager sharedManager];
    CTNNotificationProvider* provider = [providerManager providerWithName: message.provider error: NULL];
    
    [provider messageDidExpire: message];
    [self deleteReceiversForMessageWithIdentifier: message.identifier];
    [self deleteMessage: message];
  }
}

- (void) deleteReceiversForMessageWithIdentifier: (NSString*) identifier
{
  NSString* format = @"DELETE FROM %@ WHERE identifier = ?;";
  NSString* query = [NSString stringWithFormat: format, self.receiversTable];
  SQLStatement* statement = [self.database statementWithParameterizedQuery: query];
  
  if (!statement)
  {
    [self.logger warnWithFormat: @"Cannot delete messages: %@", [[self.database lastError] localizedDescription]];
    
    return;
  }
  
  [statement bindString: identifier toColumn: 1];
  
  if ([statement step] != SQLITE_DONE)
  {
    [self.logger warnWithFormat: @"Cannot delete messages: %@", [[self.database lastError] localizedDescription]];
  }
}

- (void) deleteMessage: (CTNMessage*) message
{
  [self messageWillBeDeleted: message];
  [self deleteMessageWithIdentifier: message.identifier];
}
  
- (void) deleteMessageWithIdentifier: (NSString*) identifier
{
  NSString* format = @"DELETE FROM %@ WHERE identifier = ?;";
  NSString* query = [NSString stringWithFormat: format, self.storeTable];
  SQLStatement* statement = [self.database statementWithParameterizedQuery: query];
  
  if (!statement)
  {
    [self.logger warnWithFormat: @"Cannot delete message: %@", [[self.database lastError] localizedDescription]];
    
    return;
  }
  
  [statement bindString: identifier toColumn: 1];

  if ([statement step] != SQLITE_DONE)
  {
    [self.logger warnWithFormat: @"Cannot delete message: %@", [[self.database lastError] localizedDescription]];
  }
}

- (void) messageWillBeDeleted: (CTNMessage*) message
{
  if (message.contentReference)
  {
    NSFileManager* fileManager = [NSFileManager defaultManager];
    
    [fileManager removeItemAtPath: message.contentReference.path error: NULL];
  }
  
  CTNNotificationProvider* provider = [[CTNNotificationProviderManager sharedManager] providerWithName: message.provider error: NULL];
  
  [provider messageWillBeDeleted: message];
}

- (BOOL) messageWasLoaded: (CTNMessage*) message
                    error: (NSError**) error
{
  CTNContentReference* contentReference = [CTNContentReference contentReferenceWithContent: message.content];
  
  if (contentReference)
  {
    NSData* data = [NSData dataWithContentsOfFile: contentReference.path options: 0 error: error];
    
    if (!data)
    {
      return NO;
    }
    
    [self.logger traceWithFormat: @"Expanded %@ to data of size %@", contentReference, CTNFormatBytes([data length])];
    
    id content = CTNJSONObjectFromData(data);
    
    if (!content)
    {
      return NO;
    }
    
    message.contentReference = contentReference;
    message.content = content;
  }
  
  return YES;
}

- (BOOL) messageWillBeSaved: (CTNMessage*) message error:(NSError **)error
{
  if (!message.content)
  {
    return YES;
  }
  
  NSData* body = CTNDataFromJSONObject(message.content);
  
  if (!body)
  {
    return NO;
  }
  
  [self.logger traceWithFormat: @"Content of %@ has a size of %@", message, CTNFormatBytes([body length])];
  
  if ([body length] <= MaxContentBytes)
  {
    return YES;
  }
  
  NSString* path = CTNUniquePathWithExtension(@"json");
  
  if (!path)
  {
    return NO;
  }
  
  if (![body writeToFile: path options: NSDataWritingAtomic error: error])
  {
    return NO;
  }
  
  message.contentReference = [CTNContentReference contentReferenceWithPath: path];
  
  [self.logger traceWithFormat: @"Saved message content to %@", message.contentReference];
  
  return YES;
}

- (BOOL) containsMessage: (CTNMessage*) message
{
  return [self containsMessageWithIdentifier: message.identifier];
}

- (BOOL) containsMessageWithIdentifier: (NSString*) identifier
  {
  if (!identifier)
  {
    return NO;
  }
  
  NSString* format = @"SELECT identifier FROM %@ WHERE identifier=?;";
  NSString* query = [NSString stringWithFormat: format, self.storeTable];
  SQLStatement* statement = [self.database statementWithParameterizedQuery: query];
  
  if (!statement)
  {
    [self.logger warnWithFormat: @"Cannot check for message: %@", [[self.database lastError] localizedDescription]];
    
    return NO;
  }
  
  [statement bindString: identifier toColumn: 1];
  
  SQLResult result = [statement step];
  
  if (result == SQLITE_ROW)
  {
    return YES;
  }
  else if (result == SQLITE_DONE)
  {
    return NO;
  }
  else
  {
    [self.logger warnWithFormat: @"Cannot check for message with identifier %@: %@", identifier, [[self.database lastError] localizedDescription]];
    
    return NO;
  }
}

- (BOOL) addMessage: (CTNMessage*) message
{
  if (message.isDeleted || [message.expiryDate compare: [NSDate date]] == NSOrderedAscending)
  {
    return [self addMessageAsDeleted: message];
  }
  else
  {
    return [self addMessage: message notifyDelegate: YES];
  }
}

- (BOOL) addMessage: (CTNMessage*) message
     notifyDelegate: (BOOL) shouldNotifiy
{
  if (!message.identifier)
  {
    return NO;
  }
  
  if ([self containsMessage: message])
  {
    return NO;
  }
  
  return [self insertMessage: message notifyDelegate: shouldNotifiy];
}

- (BOOL) addMessageAsDeleted: (CTNMessage*) message
{
  // N.B. we call neither the added nor deleted callbacks
  message.isDeleted = YES;
  message.content = nil;
  message.notification = nil;
  message.expiryDate = [[NSDate date] dateByAddingTimeInterval: CTNDeletionStubLifespan];

  return [self addMessage: message notifyDelegate: NO];
}

- (void) saveMessage: (CTNMessage*) message allowUpdate: (BOOL) allowUpdate
{
  if (!message)
  {
    return;
  }
  
  if (!message.identifier)
  {
    return;
  }
  
  if ([self containsMessage: message])
  {
    if (allowUpdate)
    {
      [self updateMessage: message notifyDelegate: NO];
    }
  }
  else
  {
    [self insertMessage: message notifyDelegate: NO];
  }
}

- (BOOL) insertMessage: (CTNMessage*) message
        notifyDelegate: (BOOL) shouldNotify
{
  NSString* format = @"INSERT INTO %@ VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);";
  NSString* query = [NSString stringWithFormat: format, self.storeTable];
  SQLStatement* statement = [self.database statementWithParameterizedQuery: query];
  
  if (!statement)
  {
    [self.logger warnWithFormat: @"Cannot add message: %@", [[self.database lastError] localizedDescription]];
    
    return NO;
  }
  
  NSError* error = nil;
  
  if (![self messageWillBeSaved: message error: &error])
  {
    [self.logger warnWithFormat: @"Cannot add message: %@", error];
    
    return NO;
  }
  
  NSString* content = message.contentReference
  ? [NSString stringWithFormat: @"\"%@\"", message.contentReference.string]
  : CTNStringFromJSONObject(message.content);

  [statement bindString: message.identifier toColumn: 1];
  [statement bindString: message.channel toColumn: 2];
  [statement bindString: message.subchannel toColumn: 3];
  [statement bindString: content toColumn: 4];
  [statement bindString: message.notification toColumn: 5];
  [statement bindDouble: [message.sentDate timeIntervalSince1970] toColumn: 6];
  [statement bindDouble: [message.expiryDate timeIntervalSince1970] toColumn: 7];
  [statement bindString: message.provider toColumn: 8];
  [statement bindInt: message.isDeleted ? 1 : 0 toColumn: 9];
  
  if ([statement step] != SQLITE_DONE)
  {
    [self.logger warnWithFormat: @"Cannot add message: %@", [[self.database lastError] localizedDescription]];
    
    return NO;
  }
  
  if (shouldNotify)
  {
    [self didAddMessage: message];
  }
  
  [self.logger traceWithFormat: @"%@: inserted %@", self, message];
  
  return YES;
}

- (BOOL) updateMessage: (CTNMessage*) message notifyDelegate: (BOOL) shouldNotify
{
  NSString* format = @"UPDATE %@ SET "
  "channel = ?, "
  "subchannel = ?, "
  "content = ?, "
  "notification = ?, "
  "sentdate = ?, "
  "expirydate = ?, "
  "provider = ?, "
  "deleted = ? "
  "WHERE identifier = ?;";
  
  NSString* query = [NSString stringWithFormat: format, self.storeTable];
  SQLStatement* statement = [self.database statementWithParameterizedQuery: query];
  
  if (!statement)
  {
    [self.logger warnWithFormat: @"Cannot update message: %@", [[self.database lastError] localizedDescription]];
    
    return NO;
  }
  
  NSError* error = nil;
  
  if (![self messageWillBeSaved: message error: &error])
  {
    [self.logger warnWithFormat: @"Cannot update message: %@", error];
    
    return NO;
  }
  
  NSString* content = message.contentReference
  ? [NSString stringWithFormat: @"\"%@\"", message.contentReference.string]
  : CTNStringFromJSONObject(message.content);
  
  [statement bindString: message.channel toColumn: 1];
  [statement bindString: message.subchannel toColumn: 2];
  [statement bindString: content toColumn: 3];
  [statement bindString: message.notification toColumn: 4];
  [statement bindDouble: [message.sentDate timeIntervalSince1970] toColumn: 5];
  [statement bindDouble: [message.expiryDate timeIntervalSince1970] toColumn: 6];
  [statement bindString: message.provider toColumn: 7];
  [statement bindInt: message.isDeleted ? 1 : 0 toColumn: 8];
  [statement bindString: message.identifier toColumn: 9];
  
  if ([statement step] != SQLITE_DONE)
  {
    [self.logger warnWithFormat: @"Cannot update message: %@", [[self.database lastError] localizedDescription]];
    
    return NO;
  }
  
  if (shouldNotify)
  {
    [self didUpdateMessage: message];
  }
  
  [self.logger traceWithFormat: @"%@: updated %@", self, message];

  return YES;
}

- (CTNMessage*) messageForIdentifier: (NSString*) identifier
{
  NSString* format = @"SELECT "
  "identifier, "
  "channel, "
  "subchannel, "
  "content, "
  "notification, "
  "sentdate, "
  "expirydate, "
  "provider, "
  "deleted "
  "FROM %@ WHERE identifier = ?;";
  
  NSString* query = [NSString stringWithFormat: format, self.storeTable];
  SQLStatement* statement = [self.database statementWithParameterizedQuery: query];
  
  if (!statement)
  {
    [self.logger warnWithFormat: @"Cannot get message: %@", [[self.database lastError] localizedDescription]];
    
    return nil;
  }
  
  [statement bindString: identifier toColumn: 1];
  
  SQLResult result = [statement step];
  
  if (result == SQLITE_ROW)
  {
    return [self messageFromStatement: statement expandContent: YES];
  }
  else if (result == SQLITE_DONE)
  {
    return nil;
  }
  else
  {
    [self.logger warnWithFormat: @"Cannot get message: %@", [[self.database lastError] localizedDescription]];
    
    return nil;
  }
}

- (void) removeMessage: (CTNMessage*) message
{
  if (!message.identifier)
  {
    return;
  }
  
  BOOL deleteImmediately = self.deleteMessagesImmediately;
  
  if (!self.deleteMessagesImmediately)
  {
    CTNNotificationProviderManager* providerManager = [CTNNotificationProviderManager sharedManager];
    CTNNotificationProvider* provider = [providerManager providerWithName: message.provider error: NULL];
    
    deleteImmediately = !provider.needsDeletionStub;
  }
  
  if (deleteImmediately)
  {
    [self.logger traceWithFormat: @"Deleting %@ immediately", message];
    
    [self deleteReceiversForMessageWithIdentifier: message.identifier];
    [self deleteMessage: message];
  }
  else
  {
    NSDate* expiryDate = [[NSDate date] dateByAddingTimeInterval: CTNDeletionStubLifespan];
   
    [self.logger traceWithFormat: @"Will mark %@ as deleted and remove at %@", message, expiryDate];
    
    message.isDeleted = YES;
    message.content = nil;
    message.notification = nil;
    message.expiryDate = expiryDate;

    [self saveMessage: message allowUpdate: YES];
  }
  
  [self.logger traceWithFormat: @"%@: removed %@", self, message];
  
  [self didRemoveMessage: message];
}

- (CTNMessage*) messageFromStatement: (SQLStatement*) statement
                       expandContent: (BOOL) expandContent
{
  CTNMessage* message = [CTNMessage message];
  
  message.identifier = [statement stringAtColumn: 0];
  message.channel = [statement stringAtColumn: 1];
  message.subchannel = [statement stringAtColumn: 2];
  message.content = CTNJSONObjectFromString([statement stringAtColumn: 3]);
  message.notification = [statement stringAtColumn: 4];
  message.sentDate = [NSDate dateWithTimeIntervalSince1970: [statement doubleAtColumn: 5]];
  message.expiryDate = [NSDate dateWithTimeIntervalSince1970: [statement doubleAtColumn: 6]];
  message.provider = [statement stringAtColumn: 7];
  message.isDeleted = [statement intAtColumn: 8] != 0;
  
  if (expandContent)
  {
    [self messageWasLoaded: message error: NULL];
  }
  
  return message;
}

- (NSArray*) allMessages
{
  NSMutableArray* messages = [NSMutableArray array];
  SQLStatement* statement = nil;
  
  NSString* format = @"SELECT "
  "identifier, "
  "channel, "
  "subchannel, "
  "content, "
  "notification, "
  "sentdate, "
  "expirydate, "
  "provider, "
  "deleted "
  "FROM %@ WHERE deleted = 0;";
  
  NSString* query = [NSString stringWithFormat: format, self.storeTable];
  
  statement = [self.database statementWithParameterizedQuery: query];
  
  if (!statement)
  {
    [self.logger warnWithFormat: @"Cannot get messages: %@", [[self.database lastError] localizedDescription]];
    
    return nil;
  }
  
  for (;;)
  {
    SQLResult result = [statement step];
    
    if (result == SQLITE_ROW)
    {
      [messages addObject: [self messageFromStatement: statement expandContent: YES]];
    }
    else if (result == SQLITE_DONE)
    {
      break;
    }
    else
    {
      [self.logger warnWithFormat: @"Cannot get messages: %@", [[self.database lastError] localizedDescription]];
      
      return nil;
    }
  }
  
  return messages;
}

- (NSArray*) allMessagesForChannel: (NSString*) channel
                        subchannel: (NSString*) subchannel
{
  channel = [channel lowercaseString];
  subchannel = [subchannel lowercaseString];
  
  NSMutableArray* messages = [NSMutableArray array];
  SQLStatement* statement = nil;
  
  if ([subchannel length] == 0)
  {
    NSString* format = @"SELECT "
    "identifier, "
    "channel, "
    "subchannel, "
    "content, "
    "notification, "
    "sentdate, "
    "expirydate, "
    "provider, "
    "deleted "
    "FROM %@ WHERE channel = ? AND deleted = 0;";
    
    NSString* query = [NSString stringWithFormat: format, self.storeTable];
    
    statement = [self.database statementWithParameterizedQuery: query];
    
    if (!statement)
    {
      [self.logger warnWithFormat: @"Cannot get messages: %@", [[self.database lastError] localizedDescription]];
      
      return nil;
    }
    
    [statement bindString: channel toColumn: 1];
  }
  else
  {
    NSString* format = @"SELECT "
    "identifier, "
    "channel, "
    "subchannel, "
    "content, "
    "notification, "
    "sentdate, "
    "expirydate, "
    "provider, "
    "deleted "
    "FROM %@ WHERE channel = ? AND subchannel = ? AND deleted = 0;";
    
    NSString* query = [NSString stringWithFormat: format, self.storeTable];
    
    statement = [self.database statementWithParameterizedQuery: query];
    
    if (!statement)
    {
      [self.logger warnWithFormat: @"Cannot get messages: %@", [[self.database lastError] localizedDescription]];
      
      return nil;
    }
    
    [statement bindString: channel toColumn: 1];
    [statement bindString: subchannel toColumn: 2];
  }
  
  for (;;)
  {
    SQLResult result = [statement step];
    
    if (result == SQLITE_ROW)
    {
      [messages addObject: [self messageFromStatement: statement expandContent: YES]];
    }
    else if (result == SQLITE_DONE)
    {
      break;
    }
    else
    {
      [self.logger warnWithFormat: @"Cannot get messages: %@", [[self.database lastError] localizedDescription]];
      
      return nil;
    }
  }
  
  return messages;
}

- (NSArray*) allUnreadMessagesForReceiver: (NSString*) receiver
                                  channel: (NSString*) channel
                               subchannel: (NSString*) subchannel
{
  channel = [channel lowercaseString];
  subchannel = [subchannel lowercaseString];
  
  NSMutableArray* messages = [NSMutableArray array];
  SQLStatement* statement = nil;
  
  if ([subchannel length] == 0)
  {
    NSString* format = @"SELECT "
    "identifier, "
    "channel, "
    "subchannel, "
    "content, "
    "notification, "
    "sentdate, "
    "expirydate, "
    "provider, "
    "deleted "
    "FROM %@ WHERE channel = ? AND deleted = 0;";
    
    NSString* query = [NSString stringWithFormat: format, self.storeTable];
   
    statement = [self.database statementWithParameterizedQuery: query];
    
    if (!statement)
    {
      [self.logger warnWithFormat: @"Cannot get message: %@", [[self.database lastError] localizedDescription]];
      
      return nil;
    }
    
    [statement bindString: channel toColumn: 1];
  }
  else
  {
    NSString* format = @"SELECT "
    "identifier, "
    "channel, "
    "subchannel, "
    "content, "
    "notification, "
    "sentdate, "
    "expirydate, "
    "provider, "
    "deleted "
    "FROM %@ WHERE channel = ? AND subchannel = ? AND deleted = 0;";
    
    NSString* query = [NSString stringWithFormat: format, self.storeTable];
    
    statement = [self.database statementWithParameterizedQuery: query];
    
    if (!statement)
    {
      [self.logger warnWithFormat: @"Cannot get message: %@", [[self.database lastError] localizedDescription]];
      
      return nil;
    }
  
    [statement bindString: channel toColumn: 1];
    [statement bindString: subchannel toColumn: 2];
  }
  
  for (;;)
  {
    SQLResult result = [statement step];
    
    if (result == SQLITE_ROW)
    {
      if (receiver.length == 0)
      {
        [messages addObject: [self messageFromStatement: statement expandContent: YES]];
      }
      else
      {
        NSString* identifier = [statement stringAtColumn: 0];
        
        if (![self wasMessageWithIdentifier: identifier readByReceiver: receiver])
        {
          [messages addObject: [self messageFromStatement: statement expandContent: YES]];
        }
      }
    }
    else if (result == SQLITE_DONE)
    {
      break;
    }
    else
    {
      [self.logger warnWithFormat: @"Cannot get message: %@", [[self.database lastError] localizedDescription]];

      return nil;
    }
  }
  
  return messages;
}

- (NSArray*) allUnreadMessagesForProviderWithName: (NSString*) providerName
{
  NSMutableArray* messages = [NSMutableArray array];
  SQLStatement* statement = nil;
  
  NSString* format = @"SELECT "
  "identifier, "
  "channel, "
  "subchannel, "
  "content, "
  "notification, "
  "sentdate, "
  "expirydate, "
  "provider, "
  "deleted "
  "FROM %@ WHERE provider = ? AND deleted = 0;";
  
  NSString* query = [NSString stringWithFormat: format, self.storeTable];
  
  statement = [self.database statementWithParameterizedQuery: query];
  
  if (!statement)
  {
    [self.logger warnWithFormat: @"Cannot get messages: %@", [[self.database lastError] localizedDescription]];
    
    return nil;
  }
  
  [statement bindString: providerName toColumn: 1];
  
  for (;;)
  {
    SQLResult result = [statement step];
    
    if (result == SQLITE_ROW)
    {
      [messages addObject: [self messageFromStatement: statement expandContent: YES]];
    }
    else if (result == SQLITE_DONE)
    {
      break;
    }
    else
    {
      [self.logger warnWithFormat: @"Cannot get messages: %@", [[self.database lastError] localizedDescription]];
      
      return nil;
    }
  }
  
  return messages;
}

- (void) markAllUnreadMessagesAsCreated
{
  NSString* format = @"SELECT "
  "identifier, "
  "channel, "
  "subchannel, "
  "content, "
  "notification, "
  "sentdate, "
  "expirydate, "
  "provider, "
  "deleted "
  "FROM %@ WHERE deleted = 0;";
  
  NSString* query = [NSString stringWithFormat: format, self.storeTable];
  SQLStatement* statement = [self.database statementWithParameterizedQuery: query];
  
  if (!statement)
  {
    [self.logger warnWithFormat: @"Cannot mark messages: %@", [[self.database lastError] localizedDescription]];
    
    return;
  }
  
  for (;;)
  {
    SQLResult result = [statement step];
    
    if (result == SQLITE_ROW)
    {
      NSString* identifier = [statement stringAtColumn: 0];
      
      if (![self wasMessageWithIdentifierReadByAnyReceiver: identifier])
      {
        CTNMessage* message = [self messageFromStatement: statement expandContent: YES];
        
        [self didAddMessage: message];
      }
    }
    else if (result == SQLITE_DONE)
    {
      break;
    }
    else
    {
      [self.logger warnWithFormat: @"Cannot mark messages: %@", [[self.database lastError] localizedDescription]];
      
      return;
    }
  }
}

- (BOOL) wasMessageWithIdentifierReadByAnyReceiver: (NSString*) identifier
{
  NSString* format = @"SELECT identifier FROM %@ WHERE identifier = ?;";
  NSString* query = [NSString stringWithFormat: format, self.receiversTable];
  SQLStatement* statement = [self.database statementWithParameterizedQuery: query];
  
  if (!statement)
  {
    [self.logger warnWithFormat: @"Cannot find receivers: %@", [[self.database lastError] localizedDescription]];
    
    return NO;
  }
  
  [statement bindString: identifier toColumn: 1];
  
  SQLResult result = [statement step];
  
  if (result == SQLITE_ROW)
  {
    return YES;
  }
  else if (result == SQLITE_DONE)
  {
    return NO;
  }
  else
  {
    [self.logger warnWithFormat: @"Cannot find receivers: %@", [[self.database lastError] localizedDescription]];
    
    return NO;
  }
}

- (void) sendAllMessages
{
  NSString* format = @"SELECT "
  "identifier, "
  "channel, "
  "subchannel, "
  "content, "
  "notification, "
  "sentdate, "
  "expirydate, "
  "provider, "
  "deleted "
  "FROM %@ WHERE deleted = 0;";
  
  NSString* query = [NSString stringWithFormat: format, self.storeTable];
  SQLStatement* statement = [self.database statementWithParameterizedQuery: query];
 
  if (!statement)
  {
    [self.logger warnWithFormat: @"Cannot send messages: %@", [[self.database lastError] localizedDescription]];
    
    return;
  }

  for (;;)
  {
    SQLResult result = [statement step];
    
    if (result == SQLITE_ROW)
    {
      CTNMessage* message = [self messageFromStatement: statement expandContent: YES];

      if (message.hasExpired)
      {
        [self.logger warnWithFormat: @"Won't try to resend expired %@", message];
      }
      else
      {
        [self sendMessage: message];
      }
    }
    else if (result == SQLITE_DONE)
    {
      break;
    }
    else
    {
      [self.logger warnWithFormat: @"Cannot send messages: %@", [[self.database lastError] localizedDescription]];
      
      return;
    }
  }
}

- (void) sendMessage: (CTNMessage*) message
{
  [self.logger traceWithFormat: @"Sending message %@", message];
 
  NSError* error = nil;
  CTNNotificationProvider* provider = [[CTNNotificationProviderManager sharedManager] providerWithName: message.provider error: &error];
  
  if (provider && [provider sendMessage: message error: &error])
  {
    [self.logger traceWithFormat: @"Succesfully queued message %@ for sending", message];
  }
  else
  {
    [self.logger warnWithFormat: @"Cannot send messages: %@", [error localizedDescription]];
  }
}

- (BOOL) wasMessage: (CTNMessage*) message
     readByReceiver: (NSString*) receiver
{
  return  [self wasMessageWithIdentifier: message.identifier
                          readByReceiver: receiver];
}

- (BOOL) wasMessageWithIdentifier: (NSString*) identifier
                   readByReceiver: (NSString*) receiver
{
  NSString* format = @"SELECT identifier FROM %@ WHERE identifier = ? AND receiver = ?;";
  NSString* query = [NSString stringWithFormat: format, self.receiversTable];
  SQLStatement* statement = [self.database statementWithParameterizedQuery: query];
  
  if (!statement)
  {
    [self.logger warnWithFormat: @"Cannot find receivers: %@", [[self.database lastError] localizedDescription]];
    
    return NO;
  }
  
  [statement bindString: identifier toColumn: 1];
  [statement bindString: receiver toColumn: 2];
  
  SQLResult result = [statement step];
  
  if (result == SQLITE_ROW)
  {
    return YES;
  }
  else if (result == SQLITE_DONE)
  {
    return NO;
  }
  else
  {
    [self.logger warnWithFormat: @"Cannot find receivers: %@", [[self.database lastError] localizedDescription]];
    
    return NO;
  }
}

- (void) message: (CTNMessage*) message
wasReadByReceiver: (NSString*) receiver
{
  [self messageWithIdentifier: message.identifier
            wasReadByReceiver: receiver];
}

- (void) messageWithIdentifier: (NSString*) identifier
             wasReadByReceiver: (NSString*) receiver
{
  NSString* format = @"INSERT INTO %@ VALUES (?, ?);";
  NSString* query = [NSString stringWithFormat: format, self.receiversTable];
  SQLStatement* statement = [self.database statementWithParameterizedQuery: query];
  
  if (!statement)
  {
    [self.logger warnWithFormat: @"Cannot insert into receivers: %@", [[self.database lastError] localizedDescription]];
    
    return;
  }
  
  [statement bindString: identifier toColumn: 1];
  [statement bindString: receiver toColumn: 2];
 
  SQLResult result = [statement step];
  
  if (result != SQLITE_DONE)
  {
    [self.logger warnWithFormat: @"Cannot find receivers: %@", [[self.database lastError] localizedDescription]];
  }
}

- (NSUInteger) unreadCount
{
  NSUInteger unreadCount = 0;
  NSString* format = @"SELECT identifier FROM %@ WHERE deleted = 0;";
  NSString* query = [NSString stringWithFormat: format, self.storeTable];
  SQLStatement* statement = [self.database statementWithParameterizedQuery: query];
  
  if (!statement)
  {
    return 0;
  }
  
  for (;;)
  {
    SQLResult result = [statement step];
    
    if (result == SQLITE_ROW)
    {
      NSString* identifier = [statement stringAtColumn: 0];
      
      if (![self wasMessageWithIdentifierReadByAnyReceiver: identifier])
      {
        ++unreadCount;
      }
    }
    else if (result == SQLITE_DONE)
    {
      break;
    }
    else
    {
      [self.logger warnWithFormat: @"Cannot mark messages: %@", [[self.database lastError] localizedDescription]];
      
      return 0;
    }
  }
  
  return unreadCount;
}

- (void) didAddMessage: (CTNMessage*) message
{
  if (![self.systemDelegate messageStore: self didAddMessage: message])
  {
    [self.standardDelegate messageStore: self didAddMessage: message];
  }
}

- (void) didUpdateMessage: (CTNMessage*) message
{
  if (![self.systemDelegate messageStore: self didUpdateMessage: message])
  {
    [self.standardDelegate messageStore: self didUpdateMessage: message];
  }
}

- (void) didRemoveMessage: (CTNMessage*) message
{
  if (![self.systemDelegate messageStore: self didRemoveMessage: message])
  {
    [self.standardDelegate messageStore: self didRemoveMessage: message];
  }
}

#pragma mark - Attachments

- (BOOL) insertAttachment: (CTNAttachment*) attachment
{
  NSString* format = @"INSERT INTO %@ (identifier, type, messageidentifier, localref, remoteref, status, sessionidentifier) VALUES (?, ?, ?, ?, ?, ?, ?);";
  NSString* query = [NSString stringWithFormat: format, self.attachmentsTable];
  SQLStatement* statement = [self.database statementWithParameterizedQuery: query];
  
  if (!statement)
  {
    [self.logger warnWithFormat: @"Cannot insert attachment: %@", [[self.database lastError] localizedDescription]];
    
    return NO;
  }
  
  int type = [self typeForAttachment: attachment];
  
  if (type == CTNAttachmentTypeNone)
  {
    [self.logger warnWithFormat: @"Cannot determine type for %@", attachment];
    
    return NO;
    
  }
  
  [statement bindString: attachment.identifier toColumn: 1];
  [statement bindInt: type toColumn: 2];
  [statement bindString: attachment.message.identifier toColumn: 3];
  [statement bindString: attachment.localReference toColumn: 4];
  [statement bindString: attachment.remoteReference toColumn: 5];
  [statement bindInt: attachment.status toColumn: 6];
  [statement bindString: attachment.sessionIdentifier toColumn: 7];
  
  if ([statement step] != SQLITE_DONE)
  {
    [self.logger warnWithFormat: @"Cannot insert attachment %@: %@", attachment, [[self.database lastError] localizedDescription]];
    
    return NO;
  }
  
  [self.logger traceWithFormat: @"%@: added pending attachment %@", self, attachment];
  
  return YES;
}

- (int) typeForAttachment: (CTNAttachment*) attachment
{
  if ([attachment isKindOfClass: [CTNAzureStorageBlobAttachment class]])
  {
    return CTNAttachmentTypeAzureBlobStorage;
  }
  else
  {
    return CTNAttachmentTypeNone;
  }
}

- (BOOL) updateAttachment: (CTNAttachment*) attachment
{
  NSString* format = @"UPDATE %@ SET localref = ?, remoteref = ?, status = ?, sessionIdentifier = ? WHERE identifier = ?;";
  NSString* query = [NSString stringWithFormat: format, self.attachmentsTable];
  SQLStatement* statement = [self.database statementWithParameterizedQuery: query];
  
  if (!statement)
  {
    [self.logger warnWithFormat: @"Cannot update attachment: %@", [[self.database lastError] localizedDescription]];
    
    return NO;
  }
  
  [statement bindString: attachment.localReference toColumn: 1];
  [statement bindString: attachment.remoteReference toColumn: 2];
  [statement bindInt: attachment.status toColumn: 3];
  [statement bindString: attachment.sessionIdentifier toColumn: 4];
  [statement bindString: attachment.identifier toColumn: 5];
  
  if ([statement step] != SQLITE_DONE)
  {
    [self.logger warnWithFormat: @"Cannot update attachment: %@", [[self.database lastError] localizedDescription]];
    
    return NO;
  }
  
  [self.logger traceWithFormat: @"%@: updated %@", self, attachment];
  
  return YES;
}

- (BOOL) removeAllAttachmentsForMessage: (CTNMessage*) message
{
  NSString* format = @"DELETE FROM %@ WHERE messageidentifier = ?;";
  NSString* query = [NSString stringWithFormat: format, self.attachmentsTable];
  SQLStatement* statement = [self.database statementWithParameterizedQuery: query];
  
  if (!statement)
  {
    [self.logger warnWithFormat: @"Cannot remote all attachments: %@", [[self.database lastError] localizedDescription]];
    
    return NO;
  }
  
  [statement bindString: message.identifier toColumn: 1];
  
  if ([statement step] != SQLITE_DONE)
  {
    [self.logger warnWithFormat: @"Cannot remove all attachments for %@: %@", message, [[self.database lastError] localizedDescription]];
    
    return NO;
  }
  
  [self.logger traceWithFormat: @"%@: removed all attachments for %@", self, message];
  
  return YES;
}

- (CTNAttachment*) attachmentWithType: (int) type
                           identifier: (NSString*) identifier
                       localReference: (NSString*) localReference
                      remoteReference: (NSString*) remoteReference
                              message: (CTNMessage*) message
                               status: (CTNAttachmentStatus) status
                    sessionIdentifier: (NSString*) sessionIdentifier
{
  switch (type)
  {
    case CTNAttachmentTypeAzureBlobStorage:
    {
      CTNFileReference* fileReference = [CTNFileReference fileReferenceWithString: localReference];
      CTNAzureStorageBlobReference* blobReference = [CTNAzureStorageBlobReference azureStorageBlobReferenceWithString: remoteReference];
      
      return [[CTNAzureStorageBlobAttachment alloc] initWithIdentifier: identifier
                                                               message: message
                                                                status: status
                                                     sessionIdentifier: sessionIdentifier
                                                         fileReference: fileReference
                                                         blobReference: blobReference];
    }
    default:
    {
      return nil;
    }
  }
}

- (CTNAttachment*) attachmentForSessionIdentifier: (NSString*) sessionIdentifier
                                            error: (NSError**) error
{
  NSString* format = @"SELECT identifier, type, localref, remoteref, messageidentifier, status FROM %@ WHERE sessionidentifier = ? LIMIT 1;";
  NSString* query = [NSString stringWithFormat: format, self.attachmentsTable];
  SQLStatement* statement = [self.database statementWithParameterizedQuery: query];
  
  if (!statement)
  {
    [self.logger warnWithFormat: @"Cannot get attachment: %@", [[self.database lastError] localizedDescription]];
    
    return nil;
  }
  
  [statement bindString: sessionIdentifier toColumn: 1];
  
  SQLResult result = [statement step];
  
  if (result == SQLITE_DONE)
  {
    return nil;
  }
  else if (result == SQLITE_ROW)
  {
    NSString* messageIdentifier = [statement stringAtColumn: 3];
    CTNMessage* message = [self messageForIdentifier: messageIdentifier];
    
    if (!message)
    {
      if (error)
      {
        NSDictionary* userInfo = @{NSLocalizedDescriptionKey: [NSString stringWithFormat: @"Cannot find message with identifier: %@", messageIdentifier]};
        
        *error = [NSError errorWithDomain: CTNErrorDomain
                                     code: CTNCannotFindMessage
                                 userInfo: userInfo];
      }
      
      return  nil;
    }
    
    NSString* identifier = [statement stringAtColumn: 0];
    int type = [statement intAtColumn: 1];
    NSString* localReference = [statement stringAtColumn: 2];
    NSString* remoteReference = [statement stringAtColumn: 3];
    int status = [statement intAtColumn: 4];

    return [self attachmentWithType: type
                         identifier: identifier
                     localReference: localReference
                    remoteReference: remoteReference
                            message: message
                             status: status
                  sessionIdentifier: sessionIdentifier];
  }
  else
  {
    [self.logger warnWithFormat: @"Cannot get attachment with session identifier %@: %@", sessionIdentifier, [[self.database lastError] localizedDescription]];
    
    if (error)
    {
      *error = [self.database lastError];
    }
    
    return nil;
  }
}

- (NSArray*) allAttachmentsForMessage: (CTNMessage*) message
                                error: (NSError**) error
{
  NSString* format = @"SELECT identifier, type, localref, remoteref, status, sessionIdentifier FROM %@ WHERE messageidentifier = ?;";
  NSString* query = [NSString stringWithFormat: format, self.attachmentsTable];
  SQLStatement* statement = [self.database statementWithParameterizedQuery: query];
  
  if (!statement)
  {
    [self.logger warnWithFormat: @"Cannot get attachments for message: %@", [[self.database lastError] localizedDescription]];
    
    return nil;
  }
  
  [statement bindString: message.identifier toColumn: 1];
  
  NSMutableArray* attachments = [NSMutableArray array];
  
  for (;;)
  {
    SQLResult result = [statement step];
    
    if (result == SQLITE_DONE)
    {
      return attachments;
    }
    else if (result == SQLITE_ROW)
    {
      NSString* identifier = [statement stringAtColumn: 0];
      int type = [statement intAtColumn: 1];
      NSString* localReference = [statement stringAtColumn: 2];
      NSString* remoteReference = [statement stringAtColumn: 3];
      int status = [statement intAtColumn: 4];
      NSString* sessionIdentifier = [statement stringAtColumn: 5];

      CTNAttachment* attachment = [self attachmentWithType: type
                                                identifier: identifier
                                            localReference: localReference
                                           remoteReference: remoteReference
                                                   message: message
                                                    status: status
                                         sessionIdentifier: sessionIdentifier];
      
      [attachments addObject: attachment];
    }
    else
    {
      [self.logger warnWithFormat: @"Cannot get attachments for message %@: %@", message, [[self.database lastError] localizedDescription]];
      
      if (error)
      {
        *error = [self.database lastError];
      }
      
      return nil;
    }
  }
}

- (BOOL) canAddChannel: (NSString*) channel
{
  if (self.systemDelegate)
  {
    return [self.systemDelegate messageStore: self canAddChannel: channel];
    
  }
  else
  {
    return YES;
  }
}

- (BOOL) isChannelInitialized: (NSString*) channel
{
  if (self.systemDelegate)
  {
    return [self.systemDelegate messageStore: self isChannelInitialized: channel];
  }
  else
  {
    return YES;
  }
}

- (void) didInitializeChannel: (NSString*) channel
{
  [self.systemDelegate messageStore: self didInitializeChannel: channel];
}

@end
