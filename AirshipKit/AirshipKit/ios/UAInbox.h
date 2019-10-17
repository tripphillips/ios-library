/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>

#import "UAGlobal.h"
#import "UAComponent.h"

@class UAInboxMessageList;
@class UAInboxAPIClient;
@class UAInboxMessage;

NS_ASSUME_NONNULL_BEGIN

/**
 * Delegate protocol for receiving callbacks related to
 * Rich Push message delivery and display.
 */
@protocol UAInboxDelegate <NSObject>

@optional

///---------------------------------------------------------------------------------------
/// @name Inbox Delegate Optional Methods
///---------------------------------------------------------------------------------------

/**
 * Called when a new message is available from a foreground notification.
 *
 * @param message The Inbox message
 */
- (void)richPushMessageAvailable:(UAInboxMessage *)message;

/**
 * Called when the inbox is requested to be displayed by the UADisplayInboxAction.
 *
 * @param messageID The message ID of the Rich Push message
 */
- (void)showMessageForID:(NSString *)messageID;

@required

///---------------------------------------------------------------------------------------
/// @name Inbox Delegate Required Methods
///---------------------------------------------------------------------------------------

/**
 * Called when the inbox is requested to be displayed by the UADisplayInboxAction.
 */
- (void)showInbox;

@end

/**
 * The main class for interacting with the Rich Push Inbox.
 *
 * This class bridges library functionality with the UI and is the main point of interaction.
 * Most implementations will only use functionality found in this class.
 */
@interface UAInbox : UAComponent

///---------------------------------------------------------------------------------------
/// @name Inbox Properties
///---------------------------------------------------------------------------------------

/**
 * The list of Rich Push Inbox messages.
 */
@property (nonatomic, strong) UAInboxMessageList *messageList;

/**
 * The delegate that should be notified when an incoming push is handled,
 * as an object conforming to the UAInboxDelegate protocol.
 * NOTE: The delegate is not retained.
 */
@property (nonatomic, weak, nullable) id <UAInboxDelegate> delegate;

@end

NS_ASSUME_NONNULL_END
