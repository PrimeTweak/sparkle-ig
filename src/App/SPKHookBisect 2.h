// Runtime bisect harness for hook installation.
//
// Feature toggles are a poor way to isolate a performance regression: most
// installers in SPKStartupHooks.m ignore their pref and install unconditionally
// (only the hook bodies consult the pref), so turning a feature "off" leaves its
// swizzles and its per-layout work in place. The only existing control that
// actually skips installation is the `tools_disable_all` master switch, which is
// all-or-nothing.
//
// This harness sits between the surface registry and the individual installers:
// every installer call runs through SPK_INSTALL(), which records the installer
// and skips it when its bisect key is set. That turns "which of ~130 installers
// is responsible" into a binary search driven from Settings > Tools > Hook
// Bisect, one relaunch per round, with no rebuild.

// Developer-only: compiled out unless SPK_DEV is defined (see Makefile).
// In a release build the fallbacks at the bottom reduce SPK_INSTALL back to a
// plain installer call, so the registry in SPKStartupHooks.m needs no #ifdefs.

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#if SPK_DEV

/// Records `installerName` in the session registry and reports whether it should
/// be skipped. Called by SPK_INSTALL for every installer, so registration happens
/// even for skipped ones (the Settings page lists what the session knows about).
FOUNDATION_EXPORT BOOL SPKHookBisectShouldSkipInstaller(const char *installerName);

/// Tags installers registered from here on, so the Settings page can group them.
/// Set at the top of each SPKInstall<Surface>SurfaceHooksIfNeeded() function.
FOUNDATION_EXPORT void SPKHookBisectSetCurrentSurface(NSString *surface);

/// Ordered [{ @"surface": NSString, @"installers": NSArray<NSString *> }], in
/// registration order. An installer shared by several surfaces is listed once,
/// under the first surface that reached it — its skip key still covers every
/// call site, since skipping is keyed by name.
FOUNDATION_EXPORT NSArray<NSDictionary *> *SPKHookBisectRegisteredGroups(void);

/// Installers that stay installed no matter what, so Settings remains reachable
/// to undo a bisect round (navigation + the settings shortcut gesture).
FOUNDATION_EXPORT BOOL SPKHookBisectInstallerIsEssential(NSString *installerName);

/// "SPKInstallShareLongPressCopyHooksIfNeeded" -> "ShareLongPressCopy".
FOUNDATION_EXPORT NSString *SPKHookBisectDisplayName(NSString *installerName);

FOUNDATION_EXPORT BOOL SPKHookBisectInstallerIsSkipped(NSString *installerName);
FOUNDATION_EXPORT void SPKHookBisectSetInstaller(NSString *installerName, BOOL skipped);

/// Number of registered installers currently marked skipped.
FOUNDATION_EXPORT NSUInteger SPKHookBisectSkippedCount(void);

/// Number of registered installers that can be skipped (essential ones excluded).
FOUNDATION_EXPORT NSUInteger SPKHookBisectRegisteredInstallerCount(void);

/// Marks every registered non-essential installer skipped / unskipped.
FOUNDATION_EXPORT void SPKHookBisectSetAll(BOOL skipped);

/// One bisect step: skips the first half of the installers that are still
/// running. Returns how many were newly skipped (0 when one candidate is left).
FOUNDATION_EXPORT NSUInteger SPKHookBisectSkipHalfOfRemaining(void);

#else // SPK_DEV

// Release build: nothing is skippable and nothing is recorded, so every
// installer runs exactly as it would have without the harness.
#define SPKHookBisectShouldSkipInstaller(installerName) (NO)
#define SPKHookBisectSetCurrentSurface(surface) ((void)0)

#endif // SPK_DEV

NS_ASSUME_NONNULL_END
