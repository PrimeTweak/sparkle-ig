#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Streams a chosen video's frames into the Instants (QuickSnap) camera feed, so
/// IG records a video Instant from them itself.
///
/// This exists because IG 441's send payload is a Swift enum
/// (`IGQuickSnapPendingSendMedia`), unhookable from ObjC, so there is no way to
/// hand IG a finished video file. Feeding the capture pipeline instead leaves
/// every bit of IG's record/send/upload plumbing untouched: it believes it
/// filmed the video. Device-confirmed that Optic records from the
/// `AVCaptureVideoDataOutput` we already proxy (an injected still shows up in
/// the recording), which is what makes this viable.
///
/// The frames are rendered to match the still-image injector's geometry exactly:
/// aspect-fitted into a centered square of side `min(width, height)` with black
/// filling the rest of the camera frame.
///
/// Every call below is safe from the capture callback queue.
@interface SPKInstantsVideoStreamer : NSObject

/// Arms the streamer with an already-trimmed, already-cropped video. The reader
/// is built lazily on the first frame request, because the camera's dimensions
/// and pixel format are not known until then.
///
/// Arming only *holds the first frame* in the preview; playback starts on
/// `play`. A looping preview would otherwise mean a take begins wherever the
/// loop had drifted to, since IG records from the moment the shutter is pressed.
+ (void)startWithVideoURL:(NSURL *)videoURL;

/// Disarms and tears down. Safe to call when not armed.
+ (void)stop;

+ (BOOL)isArmed;

/// Starts playback from the first frame. Called when IG starts recording, so a
/// take always begins at the start of the video. No-op while already playing,
/// which lets several record-start signals be hooked without one rewinding a
/// take the other already started.
+ (void)play;

/// Returns to holding the first frame. Called when recording stops or is
/// cancelled, so the next take starts from the beginning again.
+ (void)pause;

/// The frame due at `cameraTime`, rendered for the camera's frame geometry.
/// Returns NULL when not armed or when a frame is not available, in which case
/// the caller should pass the live frame through untouched.
+ (nullable CVPixelBufferRef)copyPixelBufferForCameraTime:(CMTime)cameraTime
                                                    width:(int32_t)width
                                                   height:(int32_t)height
                                                   format:(OSType)format CF_RETURNS_RETAINED;

@end

NS_ASSUME_NONNULL_END
