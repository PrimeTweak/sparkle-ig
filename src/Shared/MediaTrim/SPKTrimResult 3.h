#import <Foundation/Foundation.h>

#import "SPKTrimCrop.h"
#import "SPKTrimTypes.h"

NS_ASSUME_NONNULL_BEGIN

/// A confirmed trim request from the editor. The editor returns this immediately
/// on confirm (no rendering); the save coordinator renders it in the background
/// and fills `outputURL`.
@interface SPKTrimResult : NSObject

@property (nonatomic, assign) SPKTrimResultMode mode;

/// Source media to render from.
@property (nonatomic, copy) NSURL *sourceURL;

/// Selection on the source timeline. For photo only, `startSeconds` is the
/// frame time and `durationSeconds` is 0.
@property (nonatomic, assign) NSTimeInterval startSeconds;
@property (nonatomic, assign) NSTimeInterval durationSeconds;

/// Optional render overrides (set by the save-flow entry to render the final
/// cut from the chosen-quality stream(s) instead of the edited preview file).
/// When `renderVideoURL` is set it replaces `sourceURL` for rendering; when
/// `renderAudioURL` is also set, the two are merged (DASH) in one pass.
@property (nonatomic, copy, nullable) NSURL *renderVideoURL;
@property (nonatomic, copy, nullable) NSURL *renderAudioURL;
@property (nonatomic, assign) NSInteger width;
@property (nonatomic, assign) NSInteger height;

/// Optional framing edit (crop / rotate / flip) applied in the same render pass
/// as the trim, so a crop never costs a second encode. Nil means the full frame.
@property (nonatomic, copy, nullable) SPKTrimCrop *crop;

/// Filled by the renderer once the temp output exists.
@property (nonatomic, copy, nullable) NSURL *outputURL;

/// Optional basename (no extension) for the rendered temp file. When set, the
/// save coordinator names the render with it instead of a random `SPKTrim-<UUID>`,
/// so destinations that hand the file off directly (Save Audio to Files, Share)
/// carry the usual `epoch_username_source_date` name rather than the temp UUID.
/// The Gallery path renames on import regardless, so it's only needed for the
/// direct-handoff destinations.
@property (nonatomic, copy, nullable) NSString *preferredBasename;

/// The destination chosen from the editor's Done menu (save flow), or nil when
/// Done was a plain confirm (gallery flow).
@property (nonatomic, copy, nullable) NSString *destinationTag;

+ (instancetype)requestWithMode:(SPKTrimResultMode)mode
                      sourceURL:(NSURL *)sourceURL
                   startSeconds:(NSTimeInterval)startSeconds
                durationSeconds:(NSTimeInterval)durationSeconds;

@end

NS_ASSUME_NONNULL_END
