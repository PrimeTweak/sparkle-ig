#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// GIF title rows for IG's native Direct message menu.
///
/// Unlike comments, DM GIFs carry their name locally on
/// `IGDirectAnimatedMedia.giphyModel` (`IGGiphyGIFModel.title` /
/// `verifiedUsername`), so the common path needs no network at all.
///
/// The Direct menu is built from a fixed element array, so the row's text has to
/// be known up front. `SPKDMGifTitleNoteMenuViewModel` records the message being
/// long-pressed while IG assembles its menu configuration, and
/// `SPKDMGifTitleElementsForTemplate` then contributes the rows.

/// YES when the DM GIF title pref is on.
FOUNDATION_EXPORT BOOL SPKDMGifTitleEnabled(void);

/// Records the message view model IG is about to build a menu for.
FOUNDATION_EXPORT void SPKDMGifTitleNoteMenuViewModel(id _Nullable viewModel);

/// Rows to inject for the recorded message, or an empty array. Safe to call more
/// than once per long-press: IG builds the menu repeatedly, feeding back the
/// array it was already given, and rows already present are not re-added.
FOUNDATION_EXPORT NSArray *SPKDMGifTitleElementsForMenu(NSArray *_Nullable elements);

/// Registers a just-constructed Direct menu view so a pending lookup can fill in
/// its placeholder row once the title arrives. IG's menu takes its text up front,
/// but the view is still on screen when the answer comes back, so the row is
/// patched in place rather than left saying "Looking up…". Ignored when no
/// lookup is outstanding.
FOUNDATION_EXPORT void SPKDMGifTitleRegisterMenuView(id _Nullable menuView);

NS_ASSUME_NONNULL_END
