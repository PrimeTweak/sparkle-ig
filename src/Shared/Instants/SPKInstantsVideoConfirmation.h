#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Posted after a held video-send continuation is accepted. Injected camera
/// sources use it to disarm the selected clip and return to the live feed.
FOUNDATION_EXPORT NSNotificationName const SPKInstantsVideoSendConfirmedNotification;

/// Feeds the on-screen QuickSnap shutter's long-press lifecycle into video
/// confirmation. The receiver validates that the button belongs to the modern
/// QuickSnap camera before arming the writer-completion gate.
FOUNDATION_EXPORT void SPKInstantsVideoConfirmationHandleLongPress(UIView *captureButton,
                                                                   UIGestureRecognizer *gesture);

NS_ASSUME_NONNULL_END
