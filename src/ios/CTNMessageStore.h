//
//  CTNMessageStore.h
//  AzureTester
//
//  Created by Gary Meehan on 29/10/2012.
//  Copyright (c) 2012 CommonTime. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "CTNMessageSender.h"

@class CTNAttachment;
@class CTNMessage;
@class CTNMessageStore;

@protocol CTNMessageStoreDelegate

- (BOOL) messageStore: (CTNMessageStore*) messageStore
        didAddMessage: (CTNMessage*) message;

- (BOOL) messageStore: (CTNMessageStore*) messageStore
     didUpdateMessage: (CTNMessage*) message;

- (BOOL) messageStore: (CTNMessageStore*) messageStore
     didRemoveMessage: (CTNMessage*) message;

@end

@protocol CTNMessageStoreSystemDelegate<CTNMessageStoreDelegate>

- (BOOL) messageStore: (CTNMessageStore*) messageStore
        canAddChannel: (NSString*) channel;

- (BOOL) messageStore: (CTNMessageStore*) messageStore
 isChannelInitialized: (NSString*) channel;

- (void) messageStore: (CTNMessageStore*) messageStore
 didInitializeChannel: (NSString*) channel;

@end

@interface CTNMessageStore : NSObject

@property (nonatomic, readwrite, weak) id<CTNMessageStoreDelegate> standardDelegate;
@property (nonatomic, readwrite, weak) id<CTNMessageStoreSystemDelegate> systemDelegate;

+ (CTNMessageStore*) inboxMessageStore;

+ (CTNMessageStore*) outboxMessageStore;

- (BOOL) containsMessage: (CTNMessage*) message;

- (BOOL) addMessage: (CTNMessage*) message;

- (void) saveMessage: (CTNMessage*) message allowUpdate: (BOOL) allowUpdate;

- (CTNMessage*) messageForIdentifier: (NSString*) identifier;

- (void) removeMessage: (CTNMessage*) message;

- (NSArray*) allMessages;

- (void) removeExpiredMessage: (CTNMessage*) message;

- (NSArray*) allMessagesForChannel: (NSString*) channel
                        subchannel: (NSString*) subchannel;

- (NSArray*) allUnreadMessagesForReceiver: (NSString*) receiver
                                  channel: (NSString*) channel
                               subchannel: (NSString*) subchannel;

- (NSArray*) allUnreadMessagesForProviderWithName: (NSString*) providerName;

- (void) markAllUnreadMessagesAsCreated;

- (void) sendAllMessages;

- (BOOL) wasMessage: (CTNMessage*) message
     readByReceiver: (NSString*) receiver;

- (void) message: (CTNMessage*) message
wasReadByReceiver: (NSString*) receiver;

- (NSUInteger) unreadCount;

- (BOOL) insertAttachment: (CTNAttachment*) attachment;

- (BOOL) updateAttachment: (CTNAttachment*) attachment;

- (BOOL) removeAllAttachmentsForMessage: (CTNMessage*) message;

- (CTNAttachment*) attachmentForSessionIdentifier: (NSString*) sessionIdentifier
                                            error: (NSError**) error;

- (NSArray*) allAttachmentsForMessage: (CTNMessage*) message
                                error: (NSError**) error;

- (BOOL) canAddChannel: (NSString*) channel;

- (BOOL) isChannelInitialized: (NSString*) channel;

- (void) didInitializeChannel: (NSString*) channel;

@end
