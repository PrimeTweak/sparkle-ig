#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class SPKAutoSaveFilterConfig;

NS_ASSUME_NONNULL_BEGIN

#ifdef __cplusplus
extern "C" {
#endif

/// This surface's filter: mode + dual lists, keyed by username.
///
/// Username rather than pk because that's all a resolved snap carries -- Instants have
/// no author pk on the item -- which also means the list can be curated by typing a
/// username without a lookup round-trip.
SPKAutoSaveFilterConfig *SPKInstantsAutoSaveFilterConfig(void);

BOOL SPKInstantsAutoSaveAllUsersMode(void);
NSString *SPKInstantsAutoSaveListTitle(void);
BOOL SPKInstantsAutoSaveAppliesToUsername(NSString *_Nullable username);
UIViewController *SPKInstantsAutoSaveListViewController(void);
/// One-line state for the Downloads > Auto-Save surfaces row.
NSString *SPKInstantsAutoSaveSettingsSummary(void);

/// Considers an already-resolved snap for auto-save. Resolution lives in the feature
/// hook (the Instants resolver is ObjC++), so this takes the snap object -- the download
/// pipeline duck-types it via its `sparkle*URL` properties, exactly as the action button
/// does.
///
/// `snapKey` is any stable identity for the snap; the caller owns deriving it, since a
/// view-resolved snap often has no media pk to use.
void SPKInstantsAutoSaveConsiderSnap(id _Nullable snap, NSString *_Nullable username, NSString *_Nullable snapKey);
/// Clears the per-session dedupe set when the Instants viewer closes.
void SPKInstantsAutoSaveViewerSessionDidEnd(void);

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END
