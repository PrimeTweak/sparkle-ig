#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SPKDeletedMessagesViewController : UIViewController

// Presents the full grouped log.
+ (void)presentFromViewController:(nullable UIViewController *)presenter;

// Presents the full log, then drills straight into one chat's thread so the
// nav back button returns to the full list. Resolves the sender via threadId
// (reliable from an open chat) with senderPK as a fallback. When nothing is
// captured for that chat yet, it lands on the full list instead (no dead-end).
// `senderName` is a best-effort label only.
+ (void)presentForThreadId:(nullable NSString *)threadId
                  senderPK:(nullable NSString *)senderPK
                senderName:(nullable NSString *)senderName
        fromViewController:(nullable UIViewController *)presenter;

@end

NS_ASSUME_NONNULL_END
