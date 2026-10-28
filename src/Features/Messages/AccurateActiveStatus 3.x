// Makes Instagram's own activity dot update promptly.
//
// Instagram constructs one IGPresencePeriodicScheduler while building the user
// session. Its block performs the native fetch-and-store path used by the inbox,
// so shortening that scheduler preserves Instagram's own response processing.
// The hook must be installed before the app delegate's launch implementation;
// installing it with the delayed Messages surface misses the initializer and
// leaves the preference as a number that nothing reads.

#import "AccurateActiveStatus.h"

#import "../../InstagramHeaders.h"
#import "../../Shared/Account/SPKAccountManager.h"
#import "../../Utils.h"

#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static NSString *const kSPKAccurateStatusKey = @"msgs_presence_accurate_status";
static NSString *const kSPKRefreshIntervalKey = @"msgs_presence_refresh_interval";

static const double kSPKRefreshIntervalDefault = 20.0;
static const double kSPKRefreshIntervalMin = 10.0;
static const double kSPKRefreshIntervalMax = 300.0;

static BOOL sSPKAccurateHooksInstalled = NO;
static BOOL sSPKSchedulerHookInstalled = NO;
static BOOL sSPKGraceHookInstalled = NO;
static BOOL sSPKGraceCacheHookInstalled = NO;
static NSUInteger sSPKSchedulerInterceptions = 0;
static unsigned long long sSPKLastOriginalInterval = 0;
static unsigned long long sSPKLastEffectiveInterval = 0;
static NSUInteger sSPKGraceOverrideReads = 0;
static NSUInteger sSPKGraceCacheOverrideReads = 0;
static NSHashTable *sSPKSchedulers = nil;
static id sSPKForegroundObserver = nil;
static id sSPKAccountObserver = nil;
static char kSPKSchedulerOriginalIntervalKey;
static char kSPKSchedulerStartedKey;

static unsigned long long SPKPresenceRefreshInterval(void) {
    double configured = [SPKUtils getDoublePref:kSPKRefreshIntervalKey];
    if (configured <= 0)
        configured = kSPKRefreshIntervalDefault;
    // This drives a repeating network fetch. A floor prevents an accidental
    // battery and rate-limit problem from masquerading as a more accurate dot.
    configured = MAX(kSPKRefreshIntervalMin, MIN(kSPKRefreshIntervalMax, configured));
    return (unsigned long long)configured;
}

static unsigned long long SPKSchedulerStoredInterval(id scheduler) {
    if (!scheduler)
        return 0;
    Ivar intervalIvar = class_getInstanceVariable([scheduler class], "_interval");
    if (!intervalIvar)
        return 0;
    return *(unsigned long long *)((uint8_t *)(__bridge void *)scheduler + ivar_getOffset(intervalIvar));
}

static BOOL SPKSchedulerSetStoredInterval(id scheduler, unsigned long long interval) {
    if (!scheduler)
        return NO;
    Ivar intervalIvar = class_getInstanceVariable([scheduler class], "_interval");
    if (!intervalIvar)
        return NO;
    *(unsigned long long *)((uint8_t *)(__bridge void *)scheduler + ivar_getOffset(intervalIvar)) = interval;
    return YES;
}

static unsigned long long SPKEffectiveSchedulerInterval(unsigned long long original) {
    if (![SPKUtils getBoolPref:kSPKAccurateStatusKey])
        return original;
    return MIN(original, SPKPresenceRefreshInterval());
}

static void SPKTrackScheduler(id scheduler, unsigned long long originalInterval) {
    if (!scheduler)
        return;
    objc_setAssociatedObject(scheduler,
                             &kSPKSchedulerOriginalIntervalKey,
                             @(originalInterval),
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    @synchronized(sSPKSchedulers) {
        [sSPKSchedulers addObject:scheduler];
    }
}

static void SPKApplyConfiguredIntervalToScheduler(id scheduler, BOOL restartIfRunning, NSString *reason) {
    NSNumber *originalNumber = objc_getAssociatedObject(scheduler, &kSPKSchedulerOriginalIntervalKey);
    if (!originalNumber)
        return;

    unsigned long long original = originalNumber.unsignedLongLongValue;
    unsigned long long effective = SPKEffectiveSchedulerInterval(original);
    unsigned long long current = SPKSchedulerStoredInterval(scheduler);
    sSPKLastOriginalInterval = original;
    if (current == effective) {
        sSPKLastEffectiveInterval = effective;
        return;
    }

    BOOL wasStarted = [objc_getAssociatedObject(scheduler, &kSPKSchedulerStartedKey) boolValue];
    if (!SPKSchedulerSetStoredInterval(scheduler, effective)) {
        SPKLog(@"Presence", @"[Sparkle Presence] scheduler live update unavailable reason=%@", reason ?: @"unknown");
        return;
    }
    sSPKLastEffectiveInterval = effective;

    // The current FBTimer was created from the old interval. Recreate it only
    // when this scheduler had already started; otherwise its eventual -start
    // will consume the updated ivar normally.
    if (restartIfRunning && wasStarted) {
        IGPresencePeriodicScheduler *presenceScheduler = (IGPresencePeriodicScheduler *)scheduler;
        [presenceScheduler stop];
        [presenceScheduler start];
    }

    SPKLog(@"Presence", @"[Sparkle Presence] scheduler live interval %llus -> %llus reason=%@",
           current,
           effective,
           reason ?: @"unknown");
}

void SPKRefreshAccurateActiveStatusScheduler(void) {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            SPKRefreshAccurateActiveStatusScheduler();
        });
        return;
    }

    NSArray *schedulers = nil;
    @synchronized(sSPKSchedulers) {
        schedulers = sSPKSchedulers.allObjects;
    }
    for (id scheduler in schedulers)
        SPKApplyConfiguredIntervalToScheduler(scheduler, YES, @"settings/account refresh");
}

static void SPKAccurateLogGraceOverrideOnce(BOOL cachedGetter) {
    static dispatch_once_t valueOnceToken;
    static dispatch_once_t cacheOnceToken;
    dispatch_once(cachedGetter ? &cacheOnceToken : &valueOnceToken, ^{
        SPKLog(@"Presence", @"[Sparkle Presence] accurate status %@ grace override active",
               cachedGetter ? @"cached" : @"direct");
    });
}

%group SPKAccurateGrace

%hook IGDirectGatingService

- (long long)activeNowGracePeriod {
    if (![SPKUtils getBoolPref:kSPKAccurateStatusKey])
        return %orig;
    sSPKGraceOverrideReads += 1;
    SPKAccurateLogGraceOverrideOnce(NO);
    return 0;
}

%end

%end

%group SPKAccurateGraceCache

%hook IGDirectGatingService

- (NSNumber *)activeNowGracePeriodCacheValue {
    if (![SPKUtils getBoolPref:kSPKAccurateStatusKey])
        return %orig;
    sSPKGraceCacheOverrideReads += 1;
    SPKAccurateLogGraceOverrideOnce(YES);
    return @0;
}

%end

%end

%group SPKAccurateScheduler

%hook IGPresencePeriodicScheduler

- (id)initWithIntervalInSeconds:(unsigned long long)seconds block:(id)block {
    sSPKSchedulerInterceptions += 1;
    sSPKLastOriginalInterval = seconds;

    if (![SPKUtils getBoolPref:kSPKAccurateStatusKey]) {
        sSPKLastEffectiveInterval = seconds;
        SPKLog(@"Presence", @"[Sparkle Presence] presence scheduler intercepted interval=%llus accurate=off", seconds);
        id scheduler = %orig;
        SPKTrackScheduler(scheduler, seconds);
        return scheduler;
    }

    unsigned long long configured = SPKPresenceRefreshInterval();
    unsigned long long effective = MIN(seconds, configured);
    sSPKLastEffectiveInterval = effective;
    if (effective == seconds) {
        SPKLog(@"Presence", @"[Sparkle Presence] presence scheduler keeping interval=%llus configured=%llus",
               seconds, configured);
        id scheduler = %orig;
        SPKTrackScheduler(scheduler, seconds);
        return scheduler;
    }

    SPKLog(@"Presence", @"[Sparkle Presence] presence scheduler interval %llus -> %llus",
           seconds, effective);
    id scheduler = %orig(effective, block);
    SPKTrackScheduler(scheduler, seconds);
    return scheduler;
}

- (void)start {
    SPKApplyConfiguredIntervalToScheduler(self, NO, @"start");
    %orig;
    objc_setAssociatedObject(self, &kSPKSchedulerStartedKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)stop {
    %orig;
    objc_setAssociatedObject(self, &kSPKSchedulerStartedKey, @NO, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

%end

%end

NSString *SPKAccurateActiveStatusDiagnosticsText(void) {
    BOOL enabled = [SPKUtils getBoolPref:kSPKAccurateStatusKey];
    unsigned long long configured = SPKPresenceRefreshInterval();
    NSMutableArray<NSString *> *lines = [NSMutableArray arrayWithObjects:
        [NSString stringWithFormat:@"Accurate Active Status: %@", enabled ? @"ON" : @"OFF"],
        [NSString stringWithFormat:@"Configured refresh: %llus", configured],
        [NSString stringWithFormat:@"Early hooks installed: %@", sSPKAccurateHooksInstalled ? @"YES" : @"NO"],
        [NSString stringWithFormat:@"Scheduler hook available: %@", sSPKSchedulerHookInstalled ? @"YES" : @"NO"],
        nil];

    if (sSPKSchedulerInterceptions > 0) {
        [lines addObject:[NSString stringWithFormat:@"Scheduler intercepted: YES (%llus -> %llus, %lu instance%@)",
                                                   sSPKLastOriginalInterval,
                                                   sSPKLastEffectiveInterval,
                                                   (unsigned long)sSPKSchedulerInterceptions,
                                                   sSPKSchedulerInterceptions == 1 ? @"" : @"s"]];
    } else {
        [lines addObject:@"Scheduler intercepted: NO"];
    }

    [lines addObject:[NSString stringWithFormat:@"Grace hook available: %@", sSPKGraceHookInstalled ? @"YES" : @"NO"]];
    [lines addObject:[NSString stringWithFormat:@"Grace override used: %@ (%lu direct, %lu cached)",
                                               (sSPKGraceOverrideReads + sSPKGraceCacheOverrideReads) > 0 ? @"YES" : @"NO",
                                               (unsigned long)sSPKGraceOverrideReads,
                                               (unsigned long)sSPKGraceCacheOverrideReads]];
    if (!sSPKGraceCacheHookInstalled && sSPKGraceHookInstalled)
        [lines addObject:@"Cached grace getter: unavailable on this Instagram version"];

    return [lines componentsJoinedByString:@"\n"];
}

void SPKInstallAccurateActiveStatusHooksIfEnabled(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class schedulerClass = %c(IGPresencePeriodicScheduler);
        Class gatingClass = %c(IGDirectGatingService);

        if (schedulerClass) {
            sSPKSchedulers = [NSHashTable weakObjectsHashTable];
            %init(SPKAccurateScheduler);
            sSPKSchedulerHookInstalled = YES;

            NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
            sSPKForegroundObserver = [center addObserverForName:UIApplicationDidBecomeActiveNotification
                                                        object:nil
                                                         queue:NSOperationQueue.mainQueue
                                                    usingBlock:^(__unused NSNotification *note) {
                                                        // Other foreground observers resolve the live session account.
                                                        // Run on the next main-loop turn so this read uses that account,
                                                        // rather than the early-launch roster fallback.
                                                        dispatch_async(dispatch_get_main_queue(), ^{
                                                            [[SPKAccountManager shared] refreshCurrentAccount];
                                                            SPKRefreshAccurateActiveStatusScheduler();
                                                        });
                                                    }];
            sSPKAccountObserver = [center addObserverForName:SPKAccountDidChangeNotification
                                                     object:nil
                                                      queue:NSOperationQueue.mainQueue
                                                 usingBlock:^(__unused NSNotification *note) {
                                                     dispatch_async(dispatch_get_main_queue(), ^{
                                                         SPKRefreshAccurateActiveStatusScheduler();
                                                     });
                                                 }];
        }

        if (gatingClass && [gatingClass instancesRespondToSelector:@selector(activeNowGracePeriod)]) {
            %init(SPKAccurateGrace);
            sSPKGraceHookInstalled = YES;
        }

        if (gatingClass && [gatingClass instancesRespondToSelector:@selector(activeNowGracePeriodCacheValue)]) {
            %init(SPKAccurateGraceCache);
            sSPKGraceCacheHookInstalled = YES;
        }

        sSPKAccurateHooksInstalled = YES;
        SPKLog(@"Presence", @"[Sparkle Presence] accurate status hooks installed enabled=%d configured=%llus scheduler=%d grace=%d cachedGrace=%d",
               [SPKUtils getBoolPref:kSPKAccurateStatusKey],
               SPKPresenceRefreshInterval(),
               sSPKSchedulerHookInstalled,
               sSPKGraceHookInstalled,
               sSPKGraceCacheHookInstalled);
    });
}
