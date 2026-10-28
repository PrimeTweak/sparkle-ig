#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Presentational overlay for the full-screen media preview: shows the source user
/// (title) and a subtitle (post date for posts, full name for profile pictures) over
/// the media. Non-interactive — it never intercepts touches, so a tap on the media
/// still toggles the chrome and hides this overlay in lockstep with it.
@interface SPKMediaPreviewInfoOverlay : UIView

/// Populates the overlay with a pre-composed title (e.g. "@user" or "@user · Feed")
/// and subtitle. Empty/nil fields are omitted; returns whether any content was set
/// (so the host can skip showing an empty overlay).
- (BOOL)configureWithTitle:(nullable NSString *)title
                  subtitle:(nullable NSString *)subtitle;

@end

NS_ASSUME_NONNULL_END
