#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Sends a photo from the Sparkle Gallery into the current DM thread,
/// mirroring the audio upload coordinator. Only the buttonDelegate's
/// messageSenderFeatureController is required; reachable from the same composer
/// chain the audio upload uses.
@interface SPKMediaDMUploadCoordinator : NSObject

+ (BOOL)senderTargetSupportsMediaUpload:(id)senderTarget;

+ (void)presentGalleryUploadPickerForSenderTarget:(id)senderTarget
                                        presenter:(UIViewController *)presenter
                                       sourceView:(nullable UIView *)sourceView;

@end

NS_ASSUME_NONNULL_END
