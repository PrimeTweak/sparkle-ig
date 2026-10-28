#import <UIKit/UIKit.h>

#import "../../Settings/SPKSettingsViewController.h"

NS_ASSUME_NONNULL_BEGIN

/// Downloads > Auto-Save. Owns the settings shared by every auto-save surface
/// (destination, quality, summary, history retention) plus a row per surface for
/// the surface-specific bits (enable, filter mode, user list).
@interface SPKAutoSaveSettingsViewController : SPKSettingsViewController
+ (NSArray *)searchSections;
@end

NS_ASSUME_NONNULL_END
