#import "../../Shared/UI/SPKDialog.h"
#import "SPKToolsSettingsProvider.h"
#include <UIKit/UIKit.h>

#import "../../App/SPKFlexLoader.h"
#import "../../App/SPKStabilityGuard.h"
#import "../../AssetUtils.h"
#import "../../Shared/Gallery/SPKGalleryLockViewController.h"
#import "../../Shared/Settings/SPKSettingsLockManager.h"
#import "../../Utils.h"
#import "../SPKOnboardingViewController.h"
#import "../SPKWhatsNewViewController.h"
#import "../SPKSettingsViewController.h"
#import "../SPKTopicSettingsSupport.h"
#if SPK_DEV
#import "SPKHookBisectSettingsProvider.h"
#endif
#import "SPKInterfaceSettingsProvider.h"

static UIViewController *SPKSettingsLockPresenter(void) {
    UIViewController *presenter = UIApplication.sharedApplication.keyWindow.rootViewController;
    while (presenter.presentedViewController)
        presenter = presenter.presentedViewController;
    return presenter;
}

static void SPKSettingsLockReloadPresenter(UIViewController *presenter) {
    // `presenter` is the topmost presented VC, which is usually the navigation
    // controller wrapping the settings page rather than the page itself. Reload
    // whichever SPKSettingsViewController is actually on screen so the Change
    // Passcode row greys/ungreys with the lock toggle.
    SPKSettingsViewController *settingsVC = nil;
    if ([presenter isKindOfClass:SPKSettingsViewController.class]) {
        settingsVC = (SPKSettingsViewController *)presenter;
    } else if ([presenter isKindOfClass:UINavigationController.class]) {
        UIViewController *top = ((UINavigationController *)presenter).topViewController;
        if ([top isKindOfClass:SPKSettingsViewController.class])
            settingsVC = (SPKSettingsViewController *)top;
    }
    [settingsVC.tableView reloadData];
}

static NSDictionary *SPKSettingsLockSection(void) {
    SPKSetting *lockSwitch = [SPKSetting switchCellWithTitle:@"Passcode lock"
                                                        icon:SPKSettingsIcon(@"lock")
                                                 defaultsKey:@""];
    lockSwitch.helpText = @"Ask for a passcode before opening Sparkle Settings.";
    lockSwitch.reloadsTableOnSwitchChange = YES;
    lockSwitch.switchValueProvider = ^BOOL {
        return [SPKSettingsLockManager sharedManager].isLockEnabled;
    };
    lockSwitch.switchChangeHandler = ^(BOOL enabled) {
        SPKSettingsLockManager *currentManager = [SPKSettingsLockManager sharedManager];
        UIViewController *presenter = SPKSettingsLockPresenter();
        if (enabled && !currentManager.isLockEnabled) {
            [SPKGalleryLockViewController presentMode:SPKGalleryLockModeSetPasscode
                                           forManager:currentManager
                                   fromViewController:presenter
                                           completion:^(__unused BOOL success) {
                                               SPKSettingsLockReloadPresenter(presenter);
                                           }];
            return;
        }
        if (!enabled && currentManager.isLockEnabled) {
            [SPKDialog presentFromController:presenter
                                                          title:@"Turn off the settings passcode"
                                                        message:@"The log and the captured files for this account are removed."
                                                        actions:@[
                                                            [SPKDialogAction actionWithTitle:@"Cancel"
                                                                                        style:SPKDialogActionStyleCancel
                                                                                      handler:^{
                                                                                          SPKSettingsLockReloadPresenter(presenter);
                                                                                      }],
                                                            [SPKDialogAction actionWithTitle:@"Disable"
                                                                                        style:SPKDialogActionStyleDestructive
                                                                                      handler:^{
                                                                                          [currentManager removePasscode];
                                                                                          SPKSettingsLockReloadPresenter(presenter);
                                                                                      }],
]];
        }
    };

    SPKSetting *changePasscode = [SPKSetting buttonCellWithTitle:@"Change passcode"
                                                        subtitle:nil
                                                            icon:SPKSettingsIcon(@"key")
                                                          action:^{
                                                              [SPKGalleryLockViewController presentMode:SPKGalleryLockModeChangePasscode
                                                                                             forManager:[SPKSettingsLockManager sharedManager]
                                                                                     fromViewController:SPKSettingsLockPresenter()
                                                                                             completion:^(__unused BOOL success){
                                                                                             }];
                                                          }];
    changePasscode.helpText = @"Replace the passcode that opens Sparkle Settings.";
    changePasscode.hiddenProvider = ^BOOL {
        return !([SPKSettingsLockManager sharedManager].isLockEnabled);
    };

    return SPKTopicSection(@"Settings lock", @[ lockSwitch, changePasscode ], @"Require the independent Settings passcode or biometrics when opening Sparkle Settings, including topic sheets.");
}

@implementation SPKToolsSettingsProvider

+ (SPKSetting *)rootSetting {
    BOOL flexInstalled = SPKFlexIsBundled();
    NSString *flexFooter = flexInstalled
                               ? @"The first time FLEX is opened in a session it can take a moment to initialize."
                               : @"FLEX is not installed. Rebuild with \"--flex\" flag or install \"libFLEX.dylib\" to enable these options.";
    SPKSetting *flexGesture = [SPKSetting switchCellWithTitle:@"Three-finger hold"
                                                        icon:SPKSettingsIcon(@"pinch")
                                                 defaultsKey:@"tools_flex_instagram"];
flexGesture.helpText = @"Hold three fingers anywhere in Instagram to open the FLEX inspector.";
    SPKSetting *flexLaunch = [SPKSetting switchCellWithTitle:@"Open on app launch"
                                                        icon:SPKSettingsIcon(@"play")
                                                 defaultsKey:@"tools_flex_app_launch"];
    SPKSetting *flexFocus = [SPKSetting switchCellWithTitle:@"Open on app focus"
                                                        icon:SPKSettingsIcon(@"arrow_up_right")
                                                 defaultsKey:@"tools_flex_app_start"];
    SPKSetting *flexOpen = [SPKSetting buttonCellWithTitle:@"Open FLEX now"
                                                  subtitle:nil
                                                      icon:SPKSettingsIcon(@"toolbox")
                                                    action:^(void) {
                                                        SPKFlexShowExplorer(@"settings");
                                                    }];
    if (!flexInstalled) {
        flexGesture.userInfo = @{@"enabled" : @NO};
        flexLaunch.userInfo = @{@"enabled" : @NO};
        flexFocus.userInfo = @{@"enabled" : @NO};
        flexOpen.userInfo = @{@"enabled" : @NO};
    }
    // The TestFlight/Beta popup suppression is always active on release builds.
    // On dev builds, we keep a toggle to allow disabling it for testing.
    NSMutableArray *instagramCells = [NSMutableArray array];
#if SPK_DEV
    [instagramCells addObject:[SPKSetting switchCellWithTitle:@"[DEV] Hide TestFlight popup"
                                                  defaultsKey:@"tools_hide_testflight_popup"
                                              requiresRestart:YES]];
#endif
    SPKSetting *fixDuplicates = [SPKSetting switchCellWithTitle:@"Fix duplicate notifications"
                                                           icon:SPKSettingsIcon(@"notification")
                                                    defaultsKey:@"tools_fix_duplicate_notifications"];
    fixDuplicates.helpText = @"Drop the duplicate push notifications Instagram sends to sideloaded builds.";
    [instagramCells addObject:fixDuplicates];
    [instagramCells addObject:
        [SPKSetting navigationCellWithTitle:@"FLEX"
                                       subtitle:nil
                                           icon:SPKSettingsIcon(@"toolbox")
                                    navSections:@[
                SPKTopicSection(@"", @[ flexOpen, flexGesture, flexLaunch, flexFocus ], flexFooter)
                                    ]]];

    // Safe mode is one subject: this row keeps it from engaging, "Clear Safe
    // Mode" lifts it once it has. Both live in Recovery.
    SPKSetting *disableSafeMode = [SPKSetting switchCellWithTitle:@"Disable safe mode"
                                                             icon:SPKSettingsIcon(@"warning")
                                                      defaultsKey:@"tools_disable_safe_mode"];
    disableSafeMode.helpText = @"Stops Sparkle from disabling itself after a crash at launch. Leave it off unless you are debugging.";

#if SPK_DEV
    NSString *instagramFooter =
        @"1. Suppresses the Instagram Beta update popup.\n"
        @"2. Drops the duplicate in-app banner sideloaded Instagram posts while the notification extension is already delivering the same push. Only acts while the app is foregrounded.\n"
        @"3. Makes Instagram not reset settings after subsequent crashes. Use at your own risk.";
#else
    NSString *instagramFooter =
        @"1. Drops the duplicate in-app banner sideloaded Instagram posts while the notification extension is already delivering the same push. Only acts while the app is foregrounded.\n"
        @"2. Makes Instagram not reset settings after subsequent crashes. Use at your own risk.";
#endif

    // Section order: everyday settings first, recovery and developer tooling
    // last — FLEX often is not even installed on regular builds.
    // Protect, fix, replay, rescue: the lock guards everything else, the
    // Instagram fixes come next, the intro screens are rarely reopened, and
    // recovery closes with the destructive row.
    NSMutableArray *sections = [NSMutableArray arrayWithArray:@[
        SPKSettingsLockSection(),
        SPKTopicSection(@"Instagram", instagramCells, instagramFooter),
        SPKTopicSection(@"Tweak", @[
            ({
                SPKSetting *row0 = [SPKSetting buttonCellWithTitle:@"Show onboarding"
                                   subtitle:nil
                                       icon:SPKSettingsIcon(@"compass")
                                     action:^(void) {
                                         [SPKOnboardingViewController presentFromViewController:nil onFinish:nil];
                                     }];
                row0;
            }),
            ({
                SPKSetting *row1 = [SPKSetting buttonCellWithTitle:@"Show what's new"
                                   subtitle:nil
                                       icon:SPKSettingsIcon(@"notes")
                                     action:^(void) {
                                         [SPKWhatsNewViewController presentFromViewController:nil onFinish:nil];
                                     }];
                row1;
            }),
        ],
                        nil),
        // "Recovery" — was the untitled section. Disable All Settings moved in
        // from Tweak: its own footer said "Use to isolate crashes."

#if SPK_DEV
        SPKTopicSection(@"Diagnostics",
                        @[ [SPKHookBisectSettingsProvider rootSetting] ],
                        @"Skip individual hook installers at launch to isolate a crash or a slowdown to one feature."),
#endif
        SPKTopicSection(@"Recovery", @[
            disableSafeMode,
            ({
                SPKSetting *row2 = [SPKSetting buttonCellWithTitle:@"Clear safe mode"
                                   subtitle:nil
                                       icon:SPKSettingsIcon(@"undo_circle")
                                     action:^(void) {
                                         SPKStabilityGuardReset();
                                         [SPKUtils showRestartConfirmation];
                                     }];
                row2.helpText = @"Bring the features back after a crash put Sparkle to sleep.";
                row2;
            }),
            ({
                SPKSetting *row3 = [SPKSetting switchCellWithTitle:@"Turn off all features"
                           icon:SPKSettingsIcon(@"circle_off")
                                defaultsKey:@"tools_disable_all"
                            requiresRestart:YES];
                row3.helpText = @"Suspend every feature at once, keeping your settings.";
                row3;
            }),
#if SPK_DEV
            // Dev builds only: wipe the intro-sheet state so the onboarding /
            // What's New gating fires from scratch on the next launch.
            [SPKSetting buttonCellWithTitle:@"[DEV] Reset intro state"
                                   subtitle:nil
                                       icon:SPKSettingsIcon(@"beaker")
                                     action:^(void) {
                                         NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
                                         [defaults removeObjectForKey:@"app_first_run"];
                                         [defaults removeObjectForKey:@"app_last_whatsnew_version"];
                                         [SPKUtils showRestartConfirmation];
                                     }],
#endif
        ],
                        @"1. Suppress every Sparkle feature hook, leaving only the shortcut to reach this screen. Use to isolate crashes.\n"
                        @"2. Clears failed-launch counters and temporary hook suppression. Tap this button if it appears as if features aren't enabled.")
    ]];

    return SPKTopicNavigationSetting(@"Tools", @"toolbox", 24.0, sections);
}

@end
