#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

// Shared control surface for the Instants (QuickSnap) camera sample-buffer
// injector implemented in InstantsGalleryUpload.xm.
//
// It serves two features:
//   1. Upload-from-Gallery: replace the live camera feed with a chosen image.
//   2. Confirm Instant Capture: "freeze" the live preview on the exact frame the
//      user pressed the shutter on, hold it while a confirmation alert is shown,
//      then either keep it (so the captured/sent frame is EXACTLY what the user
//      saw) or clear it to resume the live feed on cancel.
//
// The injector continuously remembers the most recent live frame while the
// QuickSnap camera is active, so `freezeNow` can snapshot it instantly.
@interface SPKInstantsFrameInjector : NSObject

/// Snapshot the most recent live frame and start replaying it downstream so the
/// preview (and any subsequent capture) is frozen on that exact frame.
+ (void)freezeNow;

/// Stop replaying the frozen frame; the live camera feed resumes.
+ (void)clearFrozen;

@end

NS_ASSUME_NONNULL_END
