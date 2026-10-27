#import "SPKGallerySettingsProvider.h"
#import "../SPKSetting.h"
#import "../SPKTopicSettingsSupport.h"

#import "../../Shared/Gallery/SPKGallerySettingsViewController.h"
#import "../../Shared/Gallery/SPKGalleryViewController.h"
#import "../../Utils.h"

@implementation SPKGallerySettingsProvider

+ (SPKSetting *)rootSetting {
    // One screen instead of two: the gallery's own settings are the page, and
    // the two rows that used to sit in front of them open it from the top.
    SPKSetting *page = [SPKSetting navigationCellWithTitle:@"Gallery"
                                                  subtitle:nil
                                                      icon:SPKSettingsIcon(@"sparkle_gallery")
                                            viewController:[[SPKGallerySettingsViewController alloc] init]];
    page.searchSectionsProvider = ^NSArray * {
        return [SPKGallerySettingsViewController searchSections];
    };
    return page;
}

@end
