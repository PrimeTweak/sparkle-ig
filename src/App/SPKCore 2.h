#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, SPKSurface) {
    SPKSurfaceGeneralUI = 0,
    SPKSurfaceFeed,
    SPKSurfaceStories,
    SPKSurfaceReels,
    SPKSurfaceMessages,
    SPKSurfaceProfile,
};

#ifdef __cplusplus
extern "C" {
#endif

FOUNDATION_EXPORT void SPKCoreRegisterBootstrapDefaults(void);
FOUNDATION_EXPORT void SPKCoreRegisterDefaults(void);
FOUNDATION_EXPORT NSDictionary<NSString *, id> *SPKCoreRegisteredDefaults(void);
FOUNDATION_EXPORT void SPKCoreInstallLaunchCriticalHooks(void);
FOUNDATION_EXPORT void SPKCoreInstallSurfaceHooks(SPKSurface surface);
FOUNDATION_EXPORT void SPKCoreShowSettingsIfNeeded(UIWindow *window);

/// YES until the user has ever completed first-run onboarding (i.e. `app_first_run`
/// has never been stamped). Onboarding shows once, on the very first run — not on
/// later version bumps; upgraders get the What's New sheet instead.
FOUNDATION_EXPORT BOOL SPKCoreOnboardingPending(void);

/// YES when the user has been onboarded but hasn't yet seen the What's New sheet for
/// the current `SPKVersionString` (including upgraders who predate the feature).
FOUNDATION_EXPORT BOOL SPKCoreWhatsNewPending(void);

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END
