#import "../UI/SPKUserListViewController.h"
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// The users you have saved Instants from, listed from the Gallery itself (no separate
/// bookkeeping): every gallery file whose source is Instants, grouped by author. Selecting
/// a user opens the Gallery filtered to that user's Instants.
@interface SPKInstantsSavedUsersViewController : SPKUserListViewController

/// Presents the list as a sheet from `presenter` (topmost controller when nil).
+ (void)presentFromViewController:(nullable UIViewController *)presenter;

/// Whether any Instant has been saved to the Gallery. Used to decide whether the entry
/// point is worth showing at all.
+ (BOOL)hasSavedInstants;

@end

NS_ASSUME_NONNULL_END
