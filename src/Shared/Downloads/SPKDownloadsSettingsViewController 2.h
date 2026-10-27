#import <UIKit/UIKit.h>

#import "../../Settings/SPKSettingsViewController.h"

NS_ASSUME_NONNULL_BEGIN

/// Download-related settings: duplicate detection, concurrency, history limit,
/// media quality/encoding, and audio download options. Reached from the gear
/// button in the Downloads history screen and from the "Downloads" settings row.
@interface SPKDownloadsSettingsViewController : SPKSettingsViewController

/// Sections used for settings search indexing.
+ (NSArray *)searchSections;

@end

NS_ASSUME_NONNULL_END
