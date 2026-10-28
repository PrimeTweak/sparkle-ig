#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class SPKStoryContext, SPKAutoSaveFilterConfig;

NS_ASSUME_NONNULL_BEGIN

#ifdef __cplusplus
extern "C" {
#endif

/// This surface's filter: mode + dual lists, keyed by user pk.
SPKAutoSaveFilterConfig *SPKStoryAutoSaveFilterConfig(void);

/// YES when Filter Mode is "All Users" (list = exclusions), NO when "Selected Users"
/// (list = inclusions). Mirrors the Manually-Mark-Seen dual-list model.
BOOL SPKStoryAutoSaveAllUsersMode(void);
/// Title of the active list for the current mode ("Excluded Users" / "Selected Users").
NSString *SPKStoryAutoSaveListTitle(void);

/// The active list for the current Filter Mode. Entries match the manual-seen list
/// shape: pk / username / fullName / profilePicUrl / addedAt. Each mode keeps its own
/// list, so switching modes doesn't destroy the other's.
NSArray<NSDictionary *> *SPKStoryAutoSaveUserList(void);
BOOL SPKStoryAutoSaveListContainsUser(NSString *_Nullable pk);
/// Resolves mode + list into the actual decision for `pk`.
BOOL SPKStoryAutoSaveAppliesToUser(NSString *_Nullable pk);
void SPKStoryToggleAutoSaveForPK(NSString *pk, NSString *_Nullable username, NSString *_Nullable fullName, NSString *_Nullable profilePicUrl);
UIViewController *SPKStoryAutoSaveListViewController(void);
/// One-line state for the Downloads > Auto-Save surfaces row ("Off", "All Users",
/// "3 Selected").
NSString *SPKStoryAutoSaveSettingsSummary(void);

/// Dynamic action-menu title for the currently displayed story's user, or nil
/// when no user resolves.
BOOL SPKStoryAutoSaveAppliesToCurrentUser(SPKStoryContext *_Nullable context);
NSString *_Nullable SPKStoryAutoSaveCurrentUserActionTitle(SPKStoryContext *_Nullable context);
NSString *_Nullable SPKStoryAutoSaveCurrentUserConfirmationTitle(SPKStoryContext *_Nullable context);
NSString *_Nullable SPKStoryAutoSaveCurrentUserConfirmationMessage(SPKStoryContext *_Nullable context);
BOOL SPKStoryToggleAutoSaveCurrentUser(SPKStoryContext *_Nullable context, NSString *_Nullable *_Nullable notificationTitle, NSString *_Nullable *_Nullable notificationSubtitle);

/// Called from `IGStoryFullscreenOverlayView -layoutSubviews`. Cheap no-op
/// unless the feature is on, the list is non-empty, and the displayed item is
/// both new to this session and absent from the Gallery.
void SPKStoryAutoSaveConsiderOverlay(UIView *_Nullable overlayView);
/// Clears the per-session dedupe set when the story viewer is dismissed, so
/// re-opening a reel re-checks the Gallery rather than trusting stale state.
void SPKStoryAutoSaveViewerSessionDidEnd(void);

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END
