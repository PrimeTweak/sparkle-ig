#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "SPKTrimCrop.h"
#import "SPKTrimTypes.h"

NS_ASSUME_NONNULL_BEGIN

/// One choice in the editor's Done menu (save destinations for the save flow).
@interface SPKTrimDoneOption : NSObject
@property (nonatomic, copy) NSString *title;
/// Reported back on `SPKTrimResult.destinationTag` when chosen.
@property (nonatomic, copy) NSString *identifier;
/// Semantic icon key (see AssetUtils). Optional.
@property (nonatomic, copy, nullable) NSString *iconName;
+ (instancetype)optionWithTitle:(NSString *)title
                     identifier:(NSString *)identifier
                       iconName:(nullable NSString *)iconName;
@end

/// Describes one trim session. Built by the caller (gallery, save flow, ...) and
/// handed to `SPKTrimEditorViewController`. Intentionally media-agnostic so the
/// same object can configure an audio trim later.
@interface SPKTrimConfiguration : NSObject

/// Local file URL of the media to trim. Must exist on disk.
@property (nonatomic, copy) NSURL *sourceURL;

/// What we're editing. Defaults to `SPKTrimMediaKindVideo`.
@property (nonatomic, assign) SPKTrimMediaKind mediaKind;

/// When YES, the editor exposes the "Frame only" mode that exports a still
/// image instead of a clip. Only meaningful for video. Defaults to YES.
@property (nonatomic, assign) BOOL allowsFrameOnly;

/// When YES, a video trim also offers an "Audio Only" mode that exports the
/// selected range as an .m4a, discarding the picture. Only meaningful for video
/// (an audio trim is already audio-only). Defaults to YES.
@property (nonatomic, assign) BOOL allowsAudioOnly;

/// When YES, the editor's top bar offers a Crop button that opens the video
/// framing editor (pan/zoom crop, rotate, flip). Only meaningful for video.
/// Defaults to YES.
@property (nonatomic, assign) BOOL allowsCrop;

/// Pins the crop editor to a single ratio and hides its ratio picker (Instants
/// pass 1.0). 0 (the default) offers the full freeform picker.
///
/// A locked ratio also seeds a centred crop at that ratio, so the render matches
/// the destination's shape even if the user never opens the crop editor. Without
/// it a 16:9 clip sent to a square destination would be padded with black bars.
@property (nonatomic, assign) CGFloat lockedCropAspectRatio;

/// Longest selectable clip, in seconds. 0 (the default) means the full duration.
/// Callers with a hard ceiling (an Instant is capped) set it so the scrubber can
/// never select more than the destination accepts.
@property (nonatomic, assign) NSTimeInterval maximumDuration;

/// Shortest selectable clip, in seconds. Prevents a degenerate zero-length
/// range. Defaults to 0.3.
@property (nonatomic, assign) NSTimeInterval minimumDuration;

/// Title shown in the editor's top bar. Defaults to "Trim".
@property (nonatomic, copy, nullable) NSString *title;

/// When non-empty, the Done button becomes a menu offering these destinations;
/// the chosen one is reported on `SPKTrimResult.destinationTag`. When empty,
/// Done is a plain confirm button (gallery flow handles routing afterwards).
@property (nonatomic, copy, nullable) NSArray<SPKTrimDoneOption *> *doneOptions;

+ (instancetype)configurationWithVideoURL:(NSURL *)videoURL;

/// Audio trim: sets `mediaKind` to Audio, disables single-frame, and titles the
/// editor "Trim Audio". The editor renders a waveform instead of a filmstrip.
+ (instancetype)configurationWithAudioURL:(NSURL *)audioURL;

@end

NS_ASSUME_NONNULL_END
