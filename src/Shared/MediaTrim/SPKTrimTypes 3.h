#import <CoreMedia/CoreMedia.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// The kind of media the trim editor is operating on. Video is the only kind
/// wired today; Audio is declared up front so the same editor/result pipeline
/// can later drive voice-message upload trimming without changing call sites.
typedef NS_ENUM(NSInteger, SPKTrimMediaKind) {
    SPKTrimMediaKindVideo = 0,
    SPKTrimMediaKindAudio = 1,
};

/// What the editor produced. A frame only result is an *image* file, not a
/// one-frame video — that is the storage win for "video that's really a photo".
typedef NS_ENUM(NSInteger, SPKTrimResultMode) {
    SPKTrimResultModeTrimmedVideo = 0,
    SPKTrimResultModeFrameOnly = 1,
    SPKTrimResultModeTrimmedAudio = 2,
};

NS_ASSUME_NONNULL_END
