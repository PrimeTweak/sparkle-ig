#import "../InstagramHeaders.h"
#import "../Tweak.h"
#import "../Utils.h"
#import "SPKCore.h"
#import "SPKFlexLoader.h"
#import "SPKPerfMeter.h"
#import "SPKStabilityGuard.h"
#import "SPKStartupProfiler.h"

static BOOL sSPKAppDidBecomeActive = NO;
static BOOL sSPKStagedHooksFinished = NO;
static BOOL sSPKStabilityCompletionScheduled = NO;
static BOOL sSPKSafeModeAlertScheduled = NO;

// Safe mode suppresses every feature hook, which is indistinguishable from
// Sparkle being broken unless we say so. Explain it once per launch, and keep
// explaining on later launches until the user turns it off — a missed alert
// otherwise leaves them stuck with a silently inert tweak.
static void SPKPresentSafeModeAlertIfNeeded(void) {
    if (sSPKSafeModeAlertScheduled || !SPKStabilityGuardIsSafeStartupMode()) {
        return;
    }
    sSPKSafeModeAlertScheduled = YES;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        SPKStabilityGuardPresentSafeModeAlertIfNeeded();
    });
}

static void SPKMarkLaunchStableIfReady(void) {
    if (!sSPKAppDidBecomeActive || !sSPKStagedHooksFinished || sSPKStabilityCompletionScheduled) {
        return;
    }
    sSPKStabilityCompletionScheduled = YES;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        SPKStabilityGuardMarkHooksFinished();
    });
}

static void SPKScheduleHookPhase(NSTimeInterval delay, NSString *name, dispatch_block_t block, BOOL finalPhase) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        SPKStartupMark([NSString stringWithFormat:@"%@ hooks begin", name]);
        if (block)
            block();
        SPKStartupMark([NSString stringWithFormat:@"%@ hooks installed", name]);
        if (finalPhase) {
            sSPKStagedHooksFinished = YES;
            SPKMarkLaunchStableIfReady();
        }
    });
}

static BOOL SPKIsMessagesOnlyMode(void) {
    BOOL msgsVisible = ![SPKUtils getBoolPref:@"interface_hide_msgs_tab"];
    BOOL feedHidden = [SPKUtils getBoolPref:@"interface_hide_feed_tab"];
    BOOL exploreHidden = [SPKUtils getBoolPref:@"interface_hide_explore_tab"];
    BOOL reelsHidden = [SPKUtils getBoolPref:@"interface_hide_reels_tab"];
    BOOL profileHidden = [SPKUtils getBoolPref:@"interface_hide_profile_tab"];
    
    BOOL usesClassic = [[SPKUtils getStringPref:@"interface_nav_order"] isEqualToString:@"classic"];
    BOOL createHidden = !usesClassic || [SPKUtils getBoolPref:@"interface_hide_create_tab"];
    
    return msgsVisible && feedHidden && exploreHidden && reelsHidden && profileHidden && createHidden;
}

static void SPKScheduleStagedFeatureHooks(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        BOOL msgOnly = SPKIsMessagesOnlyMode();
        
        NSTimeInterval generalDelay = 0.25;
        NSTimeInterval feedDelay = msgOnly ? 0.65 : 0.35;
        NSTimeInterval storiesDelay = msgOnly ? 0.75 : 0.45;
        NSTimeInterval reelsDelay = msgOnly ? 0.85 : 0.55;
        NSTimeInterval messagesDelay = msgOnly ? 0.10 : 0.65;
        NSTimeInterval profileDelay = msgOnly ? 0.95 : 0.75;

        SPKScheduleHookPhase(generalDelay, @"general UI", ^{
            SPKCoreInstallSurfaceHooks(SPKSurfaceGeneralUI);
        },
                             NO);
        SPKScheduleHookPhase(feedDelay, @"feed", ^{
            SPKCoreInstallSurfaceHooks(SPKSurfaceFeed);
        },
                             NO);
        SPKScheduleHookPhase(storiesDelay, @"stories", ^{
            SPKCoreInstallSurfaceHooks(SPKSurfaceStories);
        },
                             NO);
        SPKScheduleHookPhase(reelsDelay, @"reels", ^{
            SPKCoreInstallSurfaceHooks(SPKSurfaceReels);
        },
                             NO);
        SPKScheduleHookPhase(messagesDelay, @"messages", ^{
            SPKCoreInstallSurfaceHooks(SPKSurfaceMessages);
        },
                             NO);
        SPKScheduleHookPhase(profileDelay, @"profile", ^{
            SPKCoreInstallSurfaceHooks(SPKSurfaceProfile);
        },
                             YES);
    });
}

%hook IGInstagramAppDelegate
- (_Bool)application:(UIApplication *)application willFinishLaunchingWithOptions:(id)arg2 {
    SPKStartupMark(@"willFinishLaunching begin");
    SPKCoreRegisterBootstrapDefaults();
    SPKStabilityGuardBeginLaunch();
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    // Instagram's own override, answered for it: NO while the tweak is asked to
    // take the glass away, untouched otherwise.
    if ([SPKUtils spk_isLiquidGlassDisabled])
        [defaults setBool:NO forKey:@"instagram.override.project.lucent.navigation"];
    else
        [defaults removeObjectForKey:@"instagram.override.project.lucent.navigation"];
    [defaults removeObjectForKey:@"liquid_glass_override_enabled"];
    [defaults removeObjectForKey:@"IGLiquidGlassOverrideEnabled"];
    SPKCoreInstallLaunchCriticalHooks();
    SPKStartupMark(@"launch critical hooks installed");

    return %orig;
}

- (_Bool)application:(UIApplication *)application didFinishLaunchingWithOptions:(id)arg2 {
    SPKStartupMark(@"didFinishLaunching begin");
    BOOL result = %orig;
    SPKStartupMark(@"didFinishLaunching orig returned");
    SPKScheduleStagedFeatureHooks();
    SPKPerfMeterStartIfEnabled();

    double openDelay = [SPKUtils getBoolPref:@"tools_open_settings_on_launch"] ? 0.0 : 5.0;

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(openDelay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (SPKCoreOnboardingPending() || SPKCoreWhatsNewPending() || [SPKUtils getBoolPref:@"tools_open_settings_on_launch"]) {
            SPKLog(@"Bootstrap", @"Intro sheet pending or launch-open enabled; presenting settings");
            SPKCoreShowSettingsIfNeeded([self window]);
        }
    });
    if ([SPKUtils getBoolPref:@"tools_flex_app_launch"]) {
        SPKFlexShowExplorer(@"launch");
    }

    return result;
}

- (void)applicationDidBecomeActive:(id)arg1 {
    %orig;
    sSPKAppDidBecomeActive = YES;
    SPKMarkLaunchStableIfReady();
    // The HUD needs a window scene, which is not guaranteed at didFinishLaunching.
    SPKPerfMeterStartIfEnabled();
    SPKPresentSafeModeAlertIfNeeded();

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        [SPKUtils evaluateAutomaticCacheClearIfNeeded];
    });

    if ([SPKUtils getBoolPref:@"tools_flex_app_start"]) {
        SPKFlexShowExplorer(@"focus");
    }
}
%end
