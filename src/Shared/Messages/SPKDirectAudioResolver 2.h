#import <UIKit/UIKit.h>

#import "../Audio/SPKAudioItem.h"

NS_ASSUME_NONNULL_BEGIN

/// Locates the audio behind a Direct voice message and the user who sent it.
///
/// Direct hands the UI layer no single object with both the audio URL and the
/// sender, so these walk the message/view-model graph outward from whatever
/// object is at hand, bounded by depth and a visited set.

/// Best-effort username for the sender of the message `object` belongs to.
FOUNDATION_EXPORT NSString *_Nullable SPKDirectAudioResolvedUsername(id _Nullable object);

/// Builds a playable/downloadable item from the message view `view` sits in,
/// or nil when no audio URL can be found.
FOUNDATION_EXPORT SPKAudioItem *_Nullable SPKDirectAudioItemForView(UIView *_Nullable view, SPKAudioSource source);

/// Presents the audio action sheet for the message `view` sits in, reporting
/// through the notification pill when no audio URL can be found.
FOUNDATION_EXPORT void SPKDirectPresentAudioActions(UIView *_Nullable view, SPKAudioSource source);

NS_ASSUME_NONNULL_END
