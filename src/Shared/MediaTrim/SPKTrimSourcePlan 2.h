#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Resolved plan for trimming a piece of feed/reel/story media, honoring the
/// user's `downloads_video_quality` setting (built by SPKMediaQualityManager).
@interface SPKTrimSourcePlan : NSObject

/// Progressive (ready-to-play) URL to scrub in the editor — small/fast. Falls
/// back to the final video URL when no progressive representation exists.
@property (nonatomic, copy) NSURL *editURL;

/// The chosen-quality video to render the final cut from.
@property (nonatomic, copy) NSURL *finalVideoURL;

/// Separate DASH audio stream to merge in, when `needsMerge` is YES.
@property (nonatomic, copy, nullable) NSURL *finalAudioURL;

/// YES when the chosen option is a DASH video that must be merged with
/// `finalAudioURL`; NO for a progressive (already-muxed) source.
@property (nonatomic, assign) BOOL needsMerge;

/// YES when the final render source is a separate DASH rep — merged
/// (video+audio) or silent video-only — that must be fetched to local file(s)
/// and rendered, so the editor scrubs the lightweight progressive `editURL`
/// preview instead of the (often AV1, undecodable on older iOS) rep itself. NO
/// for a progressive pick, where the edited preview *is* the final source.
@property (nonatomic, assign) BOOL needsHighQualityFetch;

/// YES when the chosen quality is a silent (video-only) stream — the trim editor
/// should not offer an "Audio Only" output mode even if the progressive preview
/// file happens to contain an audio track.
@property (nonatomic, assign) BOOL sourceIsSilent;

@property (nonatomic, assign) NSInteger width;
@property (nonatomic, assign) NSInteger height;
@property (nonatomic, assign) double duration;

@end

NS_ASSUME_NONNULL_END
