#import "SPKDeletedMessagesModels.h"
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString *const SPKDeletedMessageBubbleCellReuseID;

@class SPKDeletedMessageBubbleCell;

@protocol SPKDeletedMessageBubbleCellDelegate <NSObject>
// Tapping a media bubble (photo/video/voice/etc) should open the full preview.
- (void)bubbleCell:(SPKDeletedMessageBubbleCell *)cell didTapMediaForMessage:(SPKDeletedMessage *)message;
@end

// Incoming-style message bubble for the per-sender detail view. Renders the
// captured content by kind: text bubble, media thumbnail with kind chip, voice
// pill with a play affordance + duration, or share/link card. The deleted
// timestamp sits under each bubble.
@interface SPKDeletedMessageBubbleCell : UITableViewCell

@property (nonatomic, weak) id<SPKDeletedMessageBubbleCellDelegate> delegate;

- (void)configureWithMessage:(SPKDeletedMessage *)message
                   thumbnail:(nullable UIImage *)thumbnail
                    outgoing:(BOOL)outgoing;

// Show a sender avatar + name above the bubble (group detail, incoming messages).
// Pass nil to hide — outgoing messages or consecutive messages from the same sender.
- (void)applySenderName:(nullable NSString *)name
               senderPk:(nullable NSString *)senderPk
              avatarURL:(nullable NSString *)avatarURL;

// Apply a thumbnail that arrived asynchronously, if the cell still shows
// `messageId`. Avoids a full row reload (which can miss during initial layout).
- (void)applyLoadedThumbnail:(UIImage *)thumbnail forMessageId:(NSString *)messageId;

- (UITargetedPreview *)contextMenuTargetedPreview;

@property (nonatomic, copy, readonly, nullable) NSString *messageId;

@end

NS_ASSUME_NONNULL_END
