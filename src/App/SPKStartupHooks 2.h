#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Installs optional feature hooks after Sparkle defaults have been registered.
/// Installers must be idempotent and avoid constructing feature UI or opening persistent stores.
FOUNDATION_EXPORT void SPKInstallEnabledFeatureHooks(void);
FOUNDATION_EXPORT void SPKInstallLaunchCriticalHooks(void);
FOUNDATION_EXPORT void SPKInstallFeedSurfaceHooksIfNeeded(void);
FOUNDATION_EXPORT void SPKInstallStorySurfaceHooksIfNeeded(void);
FOUNDATION_EXPORT void SPKInstallReelsSurfaceHooksIfNeeded(void);
FOUNDATION_EXPORT void SPKInstallMessagesSurfaceHooksIfNeeded(void);
FOUNDATION_EXPORT void SPKInstallProfileSurfaceHooksIfNeeded(void);
FOUNDATION_EXPORT void SPKInstallGeneralUIHooksIfNeeded(void);

NS_ASSUME_NONNULL_END
