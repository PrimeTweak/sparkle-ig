#import "../Gallery/SPKGalleryManager.h"

NS_ASSUME_NONNULL_BEGIN

/// Independent Settings passcode lock backed by its own keychain record.
@interface SPKSettingsLockManager : SPKGalleryManager

+ (instancetype)sharedManager;
- (void)lockSettings;

@end

NS_ASSUME_NONNULL_END
