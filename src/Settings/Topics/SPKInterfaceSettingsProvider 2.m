#import "../SPKTabOrderViewController.h"
#import "SPKInterfaceSettingsProvider.h"
#import "../../Shared/UI/SPKChrome.h"
#import "../../Utils.h"
#import "../SPKPreferenceAvailability.h"
#import "../SPKPreferences.h"
#import "../SPKToggleMenu.h"
#import "../SPKTopicSettingsSupport.h"
#import "SPKNotificationSettingsProvider.h"

// The navigable tab keys. The create "+" is a composer launcher rather than a
// destination, so it is excluded — hiding it can never leave the app tab-less.
static NSArray<NSString *> *SPKDestinationTabHideKeys(void) {
    return @[
        @"interface_hide_feed_tab",
        @"interface_hide_explore_tab",
        @"interface_hide_reels_tab",
        @"interface_hide_msgs_tab",
        @"interface_hide_profile_tab",
    ];
}

// YES if turning on `keyToEnable` would leave every navigable tab hidden.
static BOOL SPKEnablingKeyHidesEveryTab(NSString *keyToEnable) {
    for (NSString *key in SPKDestinationTabHideKeys()) {
        if ([key isEqualToString:keyToEnable])
            continue;
        if (![SPKUtils getBoolPref:key])
            return NO;
    }
    return YES;
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

// A "Hide … Tab" switch that can't hide the last remaining navigable tab: when
// this is the only tab still visible its switch is greyed out and can't be
// turned on, while any already-hidden tab can always be turned back on.
@implementation SPKInterfaceSettingsProvider

+ (SPKSetting *)rootSetting {
    // ---- Tabs ----------------------------------------------------------
    // The order glossary used to live in the section footer; it moves onto the
    // two rows it explains.

    // A page rather than a menu: each layout is shown as the bar it produces,
    // which four words could not do.
    SPKSetting *tabIconOrder = [SPKSetting navigationCellWithTitle:@"Tab order"
                                                          subtitle:nil
                                                              icon:SPKSettingsIcon(@"sort")
                                                    viewController:[SPKTabOrderViewController new]];
    tabIconOrder.searchKeywords = @"standard classic alternate layout order tab icon order";

    SPKSetting *swipeBetweenTabs = [SPKSetting menuCellWithTitle:@"Swipe between tabs"
                                                            icon:SPKSettingsIcon(@"left_right")
                                                            menu:SPKSwipeBetweenTabsMenu()];
    swipeBetweenTabs.helpText = @"For Instagram's old layout, pick the Classic order and turn swiping off.";
    swipeBetweenTabs.searchKeywords = @"old layout gesture disable recent searches";

    // Everything that shapes the tab bar, one section. The iOS 26 rows
    // (pill shape, scroll behavior) join it below when available.
    // Everything about how the screen renders. The iOS 26 glass rows join it
    // below when available — same pattern as the tab bar.
    NSMutableArray *screenRows = [@[
        ({
                SPKSetting *s = [SPKSetting switchCellWithTitle:@"Hide controls on capture"
                                                           icon:SPKSettingsIcon(@"eye_off")
                                                    defaultsKey:@"interface_hide_ui_on_capture"];
                s.switchChangeHandler = ^(BOOL isOn) {
                    [[NSUserDefaults standardUserDefaults] setBool:isOn forKey:@"interface_hide_ui_on_capture"];
                    [[NSNotificationCenter defaultCenter] postNotificationName:SPKHideUIOnCapturePreferenceDidChangeNotification object:nil];
                };
                s.helpText = @"Sparkle's interface vanishes from screenshots, screen recordings and mirroring.";
                s.searchKeywords = @"screenshot recording mirror redact";
                s;
            }),
    ] mutableCopy];

    NSMutableArray *tabBarRows = [NSMutableArray array];

    NSMutableArray *sections = [NSMutableArray arrayWithArray:@[
        // Was the untitled section — six homogeneous rows deserve their name.
        // No gate here (doctrine R4): Create requires a restart and two rows
        // have conditional visibility.
        SPKTopicSection(@"Explore & search", @[
            ({
                // Shortened from "Hide Explore Posts Grid" — the section header
                // already carries "Explore"; the old title stays searchable.
                SPKSetting *s = [SPKSetting switchCellWithTitle:@"Hide posts grid"
                                                           icon:SPKSettingsIcon(@"explore_grid")
                                                    defaultsKey:@"interface_hide_explore_grid"];
                s.searchKeywords = @"explore suggested grid";
                s;
            }),
            [SPKSetting switchCellWithTitle:@"Hide trending searches"
                                       icon:SPKSettingsIcon(@"trending")
                                defaultsKey:@"interface_hide_trending_searches"],
            ({
                // Moved from General (was "No Recent Searches") — it belongs
                // with the rest of the search screen. The hook gates logging,
                // hence "Disable"; the key is unchanged, so nothing migrates.
                SPKSetting *s = [SPKSetting switchCellWithTitle:@"Hide recent searches"
                                                           icon:SPKSettingsIcon(@"search")
                                                    defaultsKey:@"general_no_recent_searches"];
                s.searchKeywords = @"no history log recent";
                s;
            }),
            ({
                SPKSetting *s = [SPKSetting switchCellWithTitle:@"Open clipboard link"
                                                           icon:SPKSettingsIcon(@"link")
                                                    defaultsKey:@"interface_open_clipboard_link"];
                s.helpText = @"Long-press the Explore tab to open the Instagram link in your clipboard.";
                s.searchKeywords = @"url paste long press";
                s;
            })
        ],
                        nil),
    ]];

    // Hoisted to function scope: the row is assembled inside the block below
    // but consumed after it, once the gate and its dependants are in place.
    SPKSetting *(^tabBarBehaviorCell)(void) = ^SPKSetting * {
        SPKSetting *tabBarBehavior = [SPKSetting menuCellWithTitle:@"Hide on scroll"
                                                              icon:SPKSettingsIcon(@"arrow_down")
                                                              menu:SPKLiquidGlassTabBarStateMenu()];
    tabBarBehavior.searchKeywords = @"tab bar behavior";
        tabBarBehavior.defaultsKey = kSPKPrefInterfaceLiquidGlassTabBarMode;
        return tabBarBehavior;
    };


        // One switch on every iOS: taking the glass away is the useful direction
        // now that Instagram ships it to everyone. The pre-26 row that reshaped
        // the bar into the pill went with it, since a switch that removes the
        // glass has nothing to offer a device that never had it.
        SPKSetting *disableGlass = [SPKSetting switchCellWithTitle:@"Disable Liquid Glass"
                                                              icon:SPKSettingsIcon(@"aura")
                                                       defaultsKey:kSPKPrefInterfaceDisableLiquidGlass
                                                   requiresRestart:YES];
        disableGlass.helpText = @"Brings back the solid tab bar and navigation from before iOS 26.";
        disableGlass.searchKeywords = @"liquid glass revert old solid tab bar pill";

        SPKSetting *progressiveBlur = [SPKSetting switchCellWithTitle:@"Progressive blur"
                                                                 icon:SPKSettingsIcon(@"blend")
                                                          defaultsKey:kSPKPrefInterfaceProgressiveBlur
                                                      requiresRestart:YES];
        progressiveBlur.helpText = @"Restores the navigation bar's gradual blur as you scroll.";

        [screenRows addObjectsFromArray:@[ disableGlass, progressiveBlur ]];

    // The gate and the Messages-Only rows join the bar they shape.
    [tabBarRows addObjectsFromArray:@[
            // D5: the six tab toggles become one gate. Each item replicates what
            // SPKHideTabSwitch did per row — the last-visible-tab guard, the
            // restart prompt, and the effective-key write that actually hides
            // the tab. Two items are conditional on the Classic tab order.
            ({
                SPKToggleMenuItem * (^tabItem)(NSString *, NSString *, NSString *) =
                    ^SPKToggleMenuItem *(NSString *title, NSString *iconName, NSString *key) {
                        SPKToggleMenuItem *item = [SPKToggleMenuItem itemWithTitle:title
                                                                          iconName:iconName
                                                                       defaultsKey:key];
                        item.enabledProvider = ^BOOL {
                            if ([SPKUtils getBoolPref:key])
                                return YES;
                            return !SPKEnablingKeyHidesEveryTab(key);
                        };
                        item.requiresRestart = YES;
                        item.changeHandler = ^(BOOL isOn) {
                            [[NSUserDefaults standardUserDefaults] setBool:isOn
                                                                    forKey:SPKEffectivePreferenceKey(key)];
                        };
                        return item;
                    };

                SPKToggleMenuItem *messagesItem = tabItem(@"Messages", @"messages", @"interface_hide_msgs_tab");
                // Classic puts Messages back in the top-right corner instead of the
                // bottom bar (that layout is where the Create "+" becomes a tab), so
                // the "tab" toggle doesn't apply — hide it whenever Create's does show.
                messagesItem.hiddenProvider = ^BOOL {
                    return [[SPKUtils getStringPref:@"interface_nav_order"] isEqualToString:@"classic"];
                };

                SPKToggleMenuItem *createItem = tabItem(@"Create", @"plus", @"interface_hide_create_tab");
                // The create button is only a dedicated tab in the Classic tab
                // order; the other layouts fold it into the composer.
                createItem.hiddenProvider = ^BOOL {
                    return ![[SPKUtils getStringPref:@"interface_nav_order"] isEqualToString:@"classic"];
                };

                SPKSetting *g = SPKToggleMenuRowSetting(@"Hide tabs", @"eye_off", @[
                    tabItem(@"Feed", @"home", @"interface_hide_feed_tab"),
                    tabItem(@"Explore", @"search", @"interface_hide_explore_tab"),
                    messagesItem,
                    tabItem(@"Reels", @"reels", @"interface_hide_reels_tab"),
                    createItem,
                    tabItem(@"Profile", @"user_circle", @"interface_hide_profile_tab"),
                ]);
                g.searchKeywords = @"hide tab bar feed explore messages reels create profile";
                g;
            }),
            ({
                SPKSetting *s = [SPKSetting switchCellWithTitle:@"Hide tab bar"
                                                           icon:SPKSettingsIcon(@"eye_off")
                                                    defaultsKey:@"interface_hide_tab_bar_in_messages_only"];
                s.enabledProvider = ^BOOL {
                    return SPKIsMessagesOnlyMode();
                };
                s.helpText = @"Available once Messages is the only visible tab. Sparkle then opens from the ✦ button in the Messages header.";
                s.searchKeywords = @"tab bar space settings access";
                s;
            })
    ]];

    // Sparkle's own look, on by default.
    //
    // It lived in the action button page of all six surfaces while driving a
    // single preference, so changing it in Feed silently changed it everywhere.
    // It belongs here instead, beside the glass rows: it decides how things are
    // drawn, not what any one button does. It now covers the confirmations too,
    // hence the wider name.
    [screenRows addObject:
        ({
            SPKSetting *sparkleLook = [SPKSetting switchCellWithTitle:@"Sparkle style"
                                                                 icon:SPKSettingsIcon(@"list")
                                                          defaultsKey:kSPKPrefSparkleAppearance];
            sparkleLook.helpText = @"Draws Sparkle's menus and confirmations in its own material, with a line between every row. Off leaves them to Instagram and iOS.";
            sparkleLook.searchKeywords = @"menu style action button confirmation dialog alert native";
            sparkleLook;
        })];

    // The Notifications sub-page closes the Screen section (scale level 4).
    [screenRows addObject:
        [SPKSetting navigationCellWithTitle:@"Notifications"
                                   subtitle:nil
                                       icon:SPKSettingsIcon(@"notification")
                                navSections:[SPKNotificationSettingsProvider sections]]];
    [sections addObject:SPKTopicSection(@"Screen", screenRows, nil)];

    // Read as a sequence: what the bar shows, where it opens, how it behaves,
    // then how it is arranged. Hiding rows stay first and together, since the
    // second only unlocks once the first has been pushed to its end.
    [tabBarRows addObjectsFromArray:@[
        [SPKSetting menuCellWithTitle:@"Launch tab"
                                 icon:SPKSettingsIcon(@"home")
                                 menu:SPKLaunchTabMenu()],
        swipeBetweenTabs,
        tabBarBehaviorCell(),
        tabIconOrder,
    ]];
    [sections insertObject:SPKTopicSection(@"Tab bar", tabBarRows, nil) atIndex:0];

    return SPKTopicNavigationSetting(@"Interface", @"interface", 24.0, sections);
}

@end
