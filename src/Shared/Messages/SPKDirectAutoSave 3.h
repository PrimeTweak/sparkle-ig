#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class SPKAutoSaveFilterConfig, SPKDirectThreadContext;

NS_ASSUME_NONNULL_BEGIN

#ifdef __cplusplus
extern "C" {
#endif

/// This surface's filter: mode + dual lists, keyed by thread id (so group chats work
/// and a per-message author never has to be resolved). Its own lists -- auto-saving a
/// chat is unrelated to whether it's marked seen.
SPKAutoSaveFilterConfig *SPKDirectAutoSaveFilterConfig(void);

BOOL SPKDirectAutoSaveAllChatsMode(void);
NSString *SPKDirectAutoSaveListTitle(void);
BOOL SPKDirectAutoSaveAppliesToThread(NSString *_Nullable threadId);
UIViewController *SPKDirectAutoSaveListViewController(void);
/// One-line state for the Downloads > Auto-Save surfaces row.
NSString *SPKDirectAutoSaveSettingsSummary(void);

/// Called from the visual-message viewer whenever it displays an item. Cheap no-op
/// unless the feature is on, the thread qualifies, and the item is both new to this
/// session and absent from the Gallery.
void SPKDirectAutoSaveConsiderController(UIViewController *_Nullable controller);
/// Clears the per-session dedupe set when the viewer is dismissed.
void SPKDirectAutoSaveViewerSessionDidEnd(void);

/// Current-thread rule, for the DM viewer's action menu.
BOOL SPKDirectAutoSaveAppliesToCurrentThread(SPKDirectThreadContext *_Nullable context);
NSString *_Nullable SPKDirectAutoSaveCurrentThreadActionTitle(SPKDirectThreadContext *_Nullable context);
NSString *_Nullable SPKDirectAutoSaveCurrentThreadConfirmationTitle(SPKDirectThreadContext *_Nullable context);
NSString *_Nullable SPKDirectAutoSaveCurrentThreadConfirmationMessage(SPKDirectThreadContext *_Nullable context);
BOOL SPKDirectToggleAutoSaveCurrentThread(SPKDirectThreadContext *_Nullable context,
                                          NSString *_Nullable *_Nullable notificationTitle,
                                          NSString *_Nullable *_Nullable notificationSubtitle);

/// The whole user-facing flow for the current-thread rule: confirm, toggle, report.
/// Both entry points -- the DM viewer's action button and the eye button menu -- go
/// through here so their wording and confirmation behaviour can't drift apart.
void SPKDirectPresentAutoSaveThreadRuleToggle(SPKDirectThreadContext *_Nullable context);

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END
