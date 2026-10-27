#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

// Circular avatar view used in the sender list and detail header. Shows the
// cached profile picture when available, otherwise a neutral user-circle
// glyph on a tinted background. Handles its own async load + reuse safety.
@interface SPKDeletedMessagesAvatarView : UIView

- (void)configureWithPK:(nullable NSString *)pk
              urlString:(nullable NSString *)urlString;

// Group-thread avatar: shows the group's custom photo when `photoURL` is set
// (cached by threadId), otherwise a native-size multi-person glyph.
- (void)configureAsGroupWithThreadId:(nullable NSString *)threadId
                            photoURL:(nullable NSString *)photoURL;

- (void)prepareForReuse;

@end

NS_ASSUME_NONNULL_END
