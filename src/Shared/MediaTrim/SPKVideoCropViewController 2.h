#import <UIKit/UIKit.h>

#import "SPKTrimCrop.h"

NS_ASSUME_NONNULL_BEGIN

/// Full-screen video framing editor: pan/zoom crop over a looping preview of the
/// clip, plus 90° rotate and horizontal flip. Shares its crop surface with the
/// photo editor (`SPKCropCanvasView`), so the geometry behaves identically.
///
/// It produces an `SPKTrimCrop` — a description, not a render. The trim editor
/// carries it on the `SPKTrimResult` and `SPKTrimRenderer` applies it in one pass
/// with the trim, so cropping never costs an extra encode.
@interface SPKVideoCropViewController : UIViewController

/// `lockedAspectRatio` > 0 pins the crop to that ratio and hides the ratio picker
/// (Instants pass 1.0); 0 offers the full freeform picker. `initialCrop` reopens
/// on a previous selection. `completion` gets nil when the user cancels.
+ (void)presentForVideoURL:(NSURL *)videoURL
         lockedAspectRatio:(CGFloat)lockedAspectRatio
               initialCrop:(nullable SPKTrimCrop *)initialCrop
                     title:(nullable NSString *)title
                      from:(UIViewController *)presenter
                completion:(void (^)(SPKTrimCrop *_Nullable crop))completion;

@end

NS_ASSUME_NONNULL_END
