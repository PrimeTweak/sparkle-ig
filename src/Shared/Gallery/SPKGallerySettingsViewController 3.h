#import <UIKit/UIKit.h>

#import "../../Settings/SPKSettingsViewController.h"

NS_ASSUME_NONNULL_BEGIN

/// Read-only gallery settings page: storage stats, lock configuration, clear gallery,
/// delete by type / source.
@interface SPKGallerySettingsViewController : SPKSettingsViewController

/// Destination folder for imports from Settings (same as current gallery folder when opened from the gallery).
@property (nonatomic, copy, nullable) NSString *importDestinationFolderPath;

+ (NSArray *)searchSections;

@end

NS_ASSUME_NONNULL_END
