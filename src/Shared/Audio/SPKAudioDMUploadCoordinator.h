#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SPKAudioDMUploadCoordinator : NSObject

+ (BOOL)senderTargetSupportsAudioUpload:(nullable id)senderTarget;
/// Where the audio to send is picked from.
typedef NS_ENUM(NSInteger, SPKAudioDMUploadSource) {
    SPKAudioDMUploadSourcePhotos,
    SPKAudioDMUploadSourceGallery,
    SPKAudioDMUploadSourceFiles,
};

+ (void)presentUploadPickerForSenderTarget:(id)senderTarget
                                 presenter:(UIViewController *)presenter
                                sourceView:(nullable UIView *)sourceView;

/// Skips the source dialog and opens one picker directly, for callers that
/// already let the reader choose the source.
+ (void)presentUploadPickerForSource:(SPKAudioDMUploadSource)source
                        senderTarget:(id)senderTarget
                           presenter:(UIViewController *)presenter
                          sourceView:(nullable UIView *)sourceView;

@end

NS_ASSUME_NONNULL_END
