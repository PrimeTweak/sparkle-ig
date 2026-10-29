#import "SPKSettingsViewController.h"

NS_ASSUME_NONNULL_BEGIN

/// The whole tab bar on one page: layout, visible tabs and their order, Saved,
/// launch tab, swipe and the single-tab bar. Edits are staged, then applied
/// together with one restart.
@interface SPKTabEditorViewController : SPKSettingsViewController
@end

/// The applied layout's name, for the row that opens the editor.
FOUNDATION_EXPORT NSString *SPKTabEditorLayoutSummary(void);

NS_ASSUME_NONNULL_END
