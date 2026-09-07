#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

// Circular avatar view backed by SPKAvatarCache. Shows the cached profile
// picture when available, otherwise a neutral glyph on a tinted background
// (a user-circle for 1:1 entries, a group glyph when `isGroup`). Handles its
// own async load, reuse safety, and tap-to-retry while the placeholder shows.
@interface SPKAvatarView : UIView

- (void)configureWithPK:(nullable NSString *)pk
              urlString:(nullable NSString *)urlString;

- (void)configureWithPK:(nullable NSString *)pk
              urlString:(nullable NSString *)urlString
                isGroup:(BOOL)isGroup;

- (void)prepareForReuse;

@end

NS_ASSUME_NONNULL_END
