#pragma once

#import <UIKit/UIKit.h>

#import "SPKSettingsViewController.h"

NS_ASSUME_NONNULL_BEGIN

/// Settings > Interface > App Font. A specimen card for the selected font over a
/// list of the default face plus every imported family, each row set in its own
/// typeface. Owns importing and deleting the font files.
@interface SPKFontPickerViewController : SPKSettingsViewController
@end

NS_ASSUME_NONNULL_END
