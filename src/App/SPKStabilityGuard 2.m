// SPKStabilityGuard — a launch failsafe.
//
// Each launch records a start timestamp. If a launch never reaches the "stable"
// mark (set ~5s after the app is active and all staged hooks installed) and the
// next launch starts within kSPKStabilityRecentLaunchWindow, it's counted as an
// incomplete launch. After kSPKStabilityFailureThreshold consecutive incomplete
// launches the tweak enters *safe startup mode*: feature hooks are suppressed
// (only Settings access remains) and Liquid Glass is disabled, so a hook that
// crashes Instagram on launch can't lock the user out permanently. The user can
// clear this from Tools > "Reset Safe Startup Mode" (SPKStabilityGuardReset).
#import "../Shared/UI/SPKDialog.h"
#import "SPKStabilityGuard.h"

#import "../Shared/UI/SPKIGAlertPresenter.h"
#import "../Utils.h"

static NSString *const kSPKStabilityLaunchStartedAtKey = @"app_launch_started_at";
static NSString *const kSPKStabilityLaunchCompletedAtKey = @"app_launch_completed_at";
static NSString *const kSPKStabilityFailedLaunchCountKey = @"app_failed_launch_count";
static NSString *const kSPKSafeStartupModeKey = @"app_safe_startup";
static NSString *const kSPKSafeStartupReasonKey = @"app_safe_startup_reason";

static NSTimeInterval const kSPKStabilityRecentLaunchWindow = 300.0;
static NSInteger const kSPKStabilityFailureThreshold = 2;

static NSTimeInterval SPKNow(void) {
    return [NSDate date].timeIntervalSince1970;
}

void SPKStabilityGuardBeginLaunch(void) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSTimeInterval now = SPKNow();
    NSTimeInterval previousStart = [defaults doubleForKey:kSPKStabilityLaunchStartedAtKey];
    NSInteger failedLaunches = [defaults integerForKey:kSPKStabilityFailedLaunchCountKey];

    if (previousStart > 0.0) {
        BOOL recentIncompleteLaunch = (now - previousStart) <= kSPKStabilityRecentLaunchWindow;
        failedLaunches = recentIncompleteLaunch ? failedLaunches + 1 : 0;
        [defaults setInteger:failedLaunches forKey:kSPKStabilityFailedLaunchCountKey];

        if (recentIncompleteLaunch && failedLaunches >= kSPKStabilityFailureThreshold) {
            [defaults setBool:YES forKey:kSPKSafeStartupModeKey];
            [defaults setObject:@"Repeated incomplete launches" forKey:kSPKSafeStartupReasonKey];
            SPKWarnLog(@"Stability", @"Entering safe startup mode after %ld incomplete launches", (long)failedLaunches);
        } else if (recentIncompleteLaunch) {
            SPKWarnLog(@"Stability", @"Detected incomplete previous launch; count=%ld", (long)failedLaunches);
        }
    }

    [defaults setDouble:now forKey:kSPKStabilityLaunchStartedAtKey];

    if ([defaults boolForKey:kSPKSafeStartupModeKey]) {
        NSString *reason = [defaults stringForKey:kSPKSafeStartupReasonKey] ?: @"unknown";
        SPKWarnLog(@"Stability", @"Safe startup mode active: %@", reason);
    } else {
        SPKLog(@"Stability", @"Launch guard armed");
    }
    [defaults synchronize];
}

void SPKStabilityGuardMarkHooksFinished(void) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults removeObjectForKey:kSPKStabilityLaunchStartedAtKey];
    [defaults setInteger:0 forKey:kSPKStabilityFailedLaunchCountKey];
    [defaults setDouble:SPKNow() forKey:kSPKStabilityLaunchCompletedAtKey];
    [defaults synchronize];
    SPKLog(@"Stability", @"Launch marked stable");
}

BOOL SPKStabilityGuardIsSafeStartupMode(void) {
    return [[NSUserDefaults standardUserDefaults] boolForKey:kSPKSafeStartupModeKey];
}

void SPKStabilityGuardPresentSafeModeAlertIfNeeded(void) {
    if (!SPKStabilityGuardIsSafeStartupMode()) {
        return;
    }

    NSString *reason = [[NSUserDefaults standardUserDefaults] stringForKey:kSPKSafeStartupReasonKey] ?: @"unknown";
    SPKLog(@"Stability", @"Presenting safe startup alert (reason: %@)", reason);

    [SPKDialog presentFromController:nil
                                                 title:@"Sparkle Safe Mode"
                                               message:@"Instagram closed before finishing launch several times in a row, so Sparkle turned its features off to get you back into the app.\n\n"
                                                        "Every Sparkle feature is disabled right now. Only Sparkle Settings is reachable. Turn Safe Mode off to enable them again."
                                               actions:@[
                                                   [SPKDialogAction actionWithTitle:@"Turn Off Safe Mode"
                                                                               style:SPKDialogActionStyleDefault
                                                                             handler:^{
                                                                                 SPKStabilityGuardReset();
                                                                                 [SPKUtils showRestartConfirmation];
                                                                             }],
                                                   [SPKDialogAction actionWithTitle:@"Open Sparkle Settings"
                                                                               style:SPKDialogActionStyleDefault
                                                                             handler:^{
                                                                                 [SPKUtils showSettingsForTopicTitle:@"Tools"];
                                                                             }],
                                                   [SPKDialogAction actionWithTitle:@"Not Now"
                                                                               style:SPKDialogActionStyleCancel
                                                                             handler:nil],
                                               ]];
}

void SPKStabilityGuardReset(void) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults removeObjectForKey:kSPKStabilityLaunchStartedAtKey];
    [defaults removeObjectForKey:kSPKStabilityFailedLaunchCountKey];
    [defaults removeObjectForKey:kSPKSafeStartupModeKey];
    [defaults removeObjectForKey:kSPKSafeStartupReasonKey];
    [defaults removeObjectForKey:kSPKStabilityLaunchCompletedAtKey];
    [defaults synchronize];
    SPKLog(@"Stability", @"Safe startup state reset");
}
