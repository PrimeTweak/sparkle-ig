#import "SPKHookBisect.h"

#if SPK_DEV

#import "../Utils.h"

// One bool per installer. The `tools_bisect_` prefix is registered as a global
// key (see SPKPrefIsGlobalKey), because a bisect must mean the same thing on
// every account and must resolve during the early-launch window, before the
// session PK exists.
static NSString *const kSPKHookBisectKeyPrefix = @"tools_bisect_skip_";

static NSString *const kSPKHookBisectUngroupedSurface = @"Launch";

// Skipping these would strand the user in a bisect round with no way back into
// Sparkle Settings: navigation owns the tab surfaces and the shortcut owns the
// long-press that opens Settings.
static NSSet<NSString *> *SPKHookBisectEssentialInstallers(void) {
    static NSSet<NSString *> *essential;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        essential = [NSSet setWithArray:@[
            @"SPKInstallNavigationHooksIfNeeded",
            @"SPKInstallSettingsShortcutsHooksIfNeeded",
        ]];
    });
    return essential;
}

BOOL SPKHookBisectInstallerIsEssential(NSString *installerName) {
    return [SPKHookBisectEssentialInstallers() containsObject:installerName ?: @""];
}

NSString *SPKHookBisectSkipKey(NSString *installerName) {
    return [kSPKHookBisectKeyPrefix stringByAppendingString:installerName ?: @""];
}

// MARK: - Session registry

// Installer names in the order SPK_INSTALL first reached them, plus the surface
// that was installing at the time. Mutated only from the main thread (hook
// installation is staged on main from AppBootstrap), read from the Settings UI.
static NSMutableArray<NSString *> *SPKHookBisectOrder(void) {
    static NSMutableArray<NSString *> *order;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        order = [NSMutableArray array];
    });
    return order;
}

static NSMutableDictionary<NSString *, NSString *> *SPKHookBisectSurfaceForInstaller(void) {
    static NSMutableDictionary<NSString *, NSString *> *surfaces;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        surfaces = [NSMutableDictionary dictionary];
    });
    return surfaces;
}

static NSString *spkHookBisectCurrentSurface = nil;

void SPKHookBisectSetCurrentSurface(NSString *surface) {
    spkHookBisectCurrentSurface = surface.length > 0 ? [surface copy] : nil;
}

BOOL SPKHookBisectInstallerIsSkipped(NSString *installerName) {
    if (installerName.length == 0 || SPKHookBisectInstallerIsEssential(installerName))
        return NO;
    return [SPKUtils getBoolPref:SPKHookBisectSkipKey(installerName)];
}

void SPKHookBisectSetInstaller(NSString *installerName, BOOL skipped) {
    if (installerName.length == 0 || SPKHookBisectInstallerIsEssential(installerName))
        return;
    SPKPreferenceSetObject(@(skipped), SPKHookBisectSkipKey(installerName));
}

BOOL SPKHookBisectShouldSkipInstaller(const char *installerName) {
    if (installerName == NULL)
        return NO;
    NSString *name = @(installerName);

    NSMutableDictionary<NSString *, NSString *> *surfaces = SPKHookBisectSurfaceForInstaller();
    if (!surfaces[name]) {
        surfaces[name] = spkHookBisectCurrentSurface ?: kSPKHookBisectUngroupedSurface;
        [SPKHookBisectOrder() addObject:name];
    }

    if (!SPKHookBisectInstallerIsSkipped(name))
        return NO;

    SPKLog(@"Bisect", @"Skipping installer %@ (surface=%@)", name, surfaces[name]);
    return YES;
}

NSArray<NSDictionary *> *SPKHookBisectRegisteredGroups(void) {
    NSMutableArray<NSDictionary *> *groups = [NSMutableArray array];
    NSMutableDictionary<NSString *, NSMutableArray<NSString *> *> *bySurface = [NSMutableDictionary dictionary];
    NSDictionary<NSString *, NSString *> *surfaces = SPKHookBisectSurfaceForInstaller();

    for (NSString *name in SPKHookBisectOrder()) {
        NSString *surface = surfaces[name] ?: kSPKHookBisectUngroupedSurface;
        NSMutableArray<NSString *> *bucket = bySurface[surface];
        if (!bucket) {
            bucket = [NSMutableArray array];
            bySurface[surface] = bucket;
            // Groups follow first-registration order, which is install order:
            // Launch, then whichever surface timer fired first.
            [groups addObject:@{@"surface" : surface, @"installers" : bucket}];
        }
        [bucket addObject:name];
    }
    return groups;
}

// MARK: - Bulk operations

static NSArray<NSString *> *SPKHookBisectCandidates(void) {
    NSMutableArray<NSString *> *candidates = [NSMutableArray array];
    for (NSString *name in SPKHookBisectOrder()) {
        if (!SPKHookBisectInstallerIsEssential(name))
            [candidates addObject:name];
    }
    return candidates;
}

NSUInteger SPKHookBisectSkippedCount(void) {
    NSUInteger count = 0;
    for (NSString *name in SPKHookBisectCandidates()) {
        if (SPKHookBisectInstallerIsSkipped(name))
            count++;
    }
    return count;
}

NSUInteger SPKHookBisectRegisteredInstallerCount(void) {
    return SPKHookBisectCandidates().count;
}

void SPKHookBisectSetAll(BOOL skipped) {
    for (NSString *name in SPKHookBisectCandidates()) {
        SPKHookBisectSetInstaller(name, skipped);
    }
    SPKLog(@"Bisect", @"%@ all installers", skipped ? @"Skipped" : @"Restored");
}

NSUInteger SPKHookBisectSkipHalfOfRemaining(void) {
    NSMutableArray<NSString *> *remaining = [NSMutableArray array];
    for (NSString *name in SPKHookBisectCandidates()) {
        if (!SPKHookBisectInstallerIsSkipped(name))
            [remaining addObject:name];
    }
    if (remaining.count < 2)
        return 0;

    NSUInteger half = remaining.count / 2;
    for (NSUInteger i = 0; i < half; i++) {
        SPKHookBisectSetInstaller(remaining[i], YES);
    }
    SPKLog(@"Bisect", @"Skipped %lu of %lu remaining installers",
           (unsigned long)half, (unsigned long)remaining.count);
    return half;
}

// MARK: - Display

NSString *SPKHookBisectDisplayName(NSString *installerName) {
    NSString *name = installerName ?: @"";
    if ([name hasPrefix:@"SPKInstall"])
        name = [name substringFromIndex:@"SPKInstall".length];
    for (NSString *suffix in @[ @"HooksIfEnabled", @"HooksIfNeeded", @"HooksNow", @"Hooks", @"HookIfNeeded", @"Hook" ]) {
        if ([name hasSuffix:suffix]) {
            name = [name substringToIndex:name.length - suffix.length];
            break;
        }
    }
    return name.length > 0 ? name : (installerName ?: @"");
}

#endif // SPK_DEV
