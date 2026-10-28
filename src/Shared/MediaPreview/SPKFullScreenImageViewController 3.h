#import <UIKit/UIKit.h>

@class SPKMediaItem;

@protocol SPKFullScreenContentDelegate <NSObject>
@optional
- (void)mediaContentDidTap:(UIViewController *)controller;
- (void)mediaContent:(UIViewController *)controller didFailWithError:(NSError *)error;
/// Reports the zoom state of the content so the host can adapt chrome (e.g.
/// show a material backing behind the bars when content fills behind them).
- (void)mediaContent:(UIViewController *)controller didChangeZoomState:(BOOL)isZoomed;
@end

NS_ASSUME_NONNULL_BEGIN

/// Non-notched devices (no home indicator) have opaque top/bottom preview bars
/// that overlap edge-to-edge media — e.g. a 16:9 photo or video fills the whole
/// screen and disappears behind (and fights touches with) the chrome. On those
/// devices we inset the media between the bars; notched devices keep the
/// immersive full-bleed layout, since the system safe area already separates
/// content from the chrome and looks right full-screen.
static inline BOOL SPKFullScreenPreviewShouldInsetMediaBetweenBars(void) {
    UIWindow *window = nil;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]])
            continue;
        for (UIWindow *candidate in ((UIWindowScene *)scene).windows) {
            if (candidate.isKeyWindow) {
                window = candidate;
                break;
            }
            if (!window)
                window = candidate;
        }
        if (window.isKeyWindow)
            break;
    }
    // Home indicator => notched/edge-to-edge device: keep full-bleed.
    return window.safeAreaInsets.bottom <= 0.0;
}

@interface SPKFullScreenImageViewController : UIViewController

@property (nonatomic, strong, readonly) SPKMediaItem *mediaItem;
@property (nonatomic, weak) id<SPKFullScreenContentDelegate> delegate;
@property (nonatomic, readonly) BOOL isZoomed;

- (instancetype)initWithMediaItem:(SPKMediaItem *)item;
- (void)preloadContent;
- (void)cleanup;
- (void)resetZoomIfNeeded;
- (void)applyMediaContentInsets:(UIEdgeInsets)insets;

@end

NS_ASSUME_NONNULL_END
