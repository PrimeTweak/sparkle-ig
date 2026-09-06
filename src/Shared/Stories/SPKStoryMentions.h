// Single source of truth for the mentioned users on a story item.
//
// IG exposes mentions as one tappable object per sticker/region, not one per
// user, so the same account can appear several times on a single story (a
// reshare emits the original author as a visible sticker plus one or more
// attribution tappables). Everything user facing must go through this module,
// which resolves the media once, unions every mention collection, and dedupes
// by user PK so the overlay button, its count badge, and the mentions sheet can
// never disagree.

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SPKStoryMention : NSObject
@property (nonatomic, copy, readonly, nullable) NSString *pk;
@property (nonatomic, strong, readonly) id userObject;
@property (nonatomic, copy, readonly, nullable) NSString *username;
@property (nonatomic, copy, readonly, nullable) NSString *fullName;
@property (nonatomic, strong, readonly, nullable) NSURL *profilePictureURL;
@end

#ifdef __cplusplus
extern "C" {
#endif

/// Mentioned users for the story item behind `overlayView`, deduped by PK and
/// ordered by first appearance. The story's own author is excluded. Result is
/// cached per overlay and invalidated when the underlying media changes, so this
/// is safe to call from a layout pass.
NSArray<SPKStoryMention *> *SPKStoryMentionsForOverlay(UIView *_Nullable overlayView);

/// Convenience for callers that only need the badge/visibility count.
NSUInteger SPKStoryMentionCountForOverlay(UIView *_Nullable overlayView);

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END
