#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "../ActionButton/ActionButtonCore.h"
#import "../Downloads/SPKDownloadTypes.h"

@class SPKGallerySaveMetadata;

NS_ASSUME_NONNULL_BEGIN

/// Shared plumbing for auto-save across surfaces (Stories now; DM view-once and
/// Instants next). Per-surface code owns *what* to save (resolution + allow-list);
/// this owns *how* it's saved: quality, destination, notification, download-history
/// retention, and the session summary.
///
/// Settings live under Downloads > Auto-Save and are shared by every surface, so
/// quality/destination are configured in exactly one place.

// Shared preference keys (Downloads > Auto-Save).
FOUNDATION_EXPORT NSString *const kSPKAutoSaveDestinationKey;
FOUNDATION_EXPORT NSString *const kSPKAutoSaveVideoQualityKey;
FOUNDATION_EXPORT NSString *const kSPKAutoSavePhotoQualityKey;
FOUNDATION_EXPORT NSString *const kSPKAutoSaveKeepHistoryKey;

#ifdef __cplusplus
extern "C" {
#endif

/// Where auto-saved media lands: the Sparkle Gallery (default) or the system photo
/// library. Anything unrecognised reads as Gallery, so a stray pref value can never
/// route saves somewhere the durable duplicate guard doesn't understand.
SPKDownloadDestination SPKAutoSaveDestination(void);

/// Resolves `media` and submits an auto-save download.
///
/// Routes through SPKMediaQualityManager with a forced quality tier, so DASH videos
/// are properly resolved and muxed instead of downloading the raw manifest artifact,
/// and the quality picker is never presented. Submitted quietly (no queue pill).
///
/// Feedback is per *session*, not per item: the first submission posts a single
/// "started" pill under `notificationIdentifier`, and the summary lands at the end.
/// Tapping through twenty stories therefore costs two notifications, not forty.
///
/// `notificationIdentifier` must be one registered via SPKAutoSaveRegisterNotificationIdentifier,
/// or the watcher won't recognize the resulting job. Returns NO when nothing downloadable
/// resolves.
BOOL SPKAutoSaveSubmitMedia(id _Nullable media,
                            SPKActionButtonSource source,
                            NSString *_Nullable username,
                            NSString *notificationIdentifier);

/// Marks `identifier` as an auto-save notification identifier so the watcher claims
/// jobs carrying it. Call once per surface.
void SPKAutoSaveRegisterNotificationIdentifier(NSString *identifier);

/// Starts the shared job watcher. Idempotent; safe to call from every surface's installer.
void SPKAutoSaveStartWatching(void);

/// Ends the current auto-save session and posts the summary toast (subject to
/// "Show Summary After Viewing").
///
/// The summary is *deferred* until every submitted job reaches a terminal state.
/// A DASH video isn't saved when its download finishes -- the FFmpeg merge runs
/// inside the job -- so counting at dismissal time would report a number that is
/// still climbing. If a job never reports back, the summary flushes anyway after
/// a timeout rather than being lost.
void SPKAutoSaveSessionDidEnd(void);

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END
