#import "SPKInterfaceSettingsProvider.h"
#import "../../Shared/UI/SPKChrome.h"
#import "../../Utils.h"
#import "../SPKPreferenceAvailability.h"
#import "../SPKPreferences.h"
#import "../SPKTabEditorViewController.h"
#import "../SPKTopicSettingsSupport.h"
#import "SPKNotificationSettingsProvider.h"

@implementation SPKInterfaceSettingsProvider

+ (SPKSetting *)rootSetting {
    // ---- Tabs ----------------------------------------------------------
    // Layout, visible tabs, order, Saved, launch tab and swipe live on one page
    // that applies them together.
    SPKSetting *tabEditor = [SPKSetting navigationCellWithTitle:@"Tab editor"
                                                       subtitle:nil
                                                           icon:SPKSettingsIcon(@"edit")
                                                 viewController:[SPKTabEditorViewController new]];
    tabEditor.accessoryTextProvider = ^NSString * {
        return SPKTabEditorLayoutSummary();
    };
    tabEditor.searchKeywords = @"tab bar hide tabs order layout classic custom standard alternate saved launch tab swipe between tabs messages only single";

    SPKSetting *hideOnScroll = [SPKSetting menuCellWithTitle:@"Hide on scroll"
                                                        icon:SPKSettingsIcon(@"arrow_down")
                                                        menu:SPKLiquidGlassTabBarStateMenu()];
    hideOnScroll.defaultsKey = kSPKPrefInterfaceLiquidGlassTabBarMode;
    hideOnScroll.searchKeywords = @"tab bar behavior";

    // Everything about how the screen renders. The iOS 26 glass rows join it
    // below when available.
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
                s.switchChangeHandler = ^(BOOL isOn) {
                    SPKPreferenceSetObject(@(isOn), @"interface_hide_explore_grid");
                    [[NSNotificationCenter defaultCenter] postNotificationName:SPKHideExploreGridPreferenceDidChangeNotification object:nil];
                };
                s.searchKeywords = @"explore suggested grid";
                s;
            }),
            ({
                SPKSetting *s = [SPKSetting switchCellWithTitle:@"Square grid"
                                                           icon:SPKSettingsIcon(@"grid_square")
                                                    defaultsKey:@"interface_explore_square_grid"];
                s.helpText = @"Shows Explore tiles as squares instead of the taller 3:4 layout. Reopen Explore to apply.";
                s.searchKeywords = @"square grid tiles explore 3:4 ratio";
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

        SPKSetting *scrollEdge = [SPKSetting menuCellWithTitle:@"Scroll edge effect"
                                                          icon:SPKSettingsIcon(@"blend")
                                                          menu:SPKScrollEdgeStyleMenu()];
        scrollEdge.defaultsKey = kSPKPrefInterfaceScrollEdgeStyle;
        scrollEdge.helpText = @"How content meets the top bar as you scroll: Default follows iOS, Soft blurs it progressively, Hard ends it at a solid line. Off lets Instagram remove the effect and needs a restart.";
        scrollEdge.searchKeywords = @"progressive blur top bar soft hard";

        [screenRows addObjectsFromArray:@[ disableGlass, scrollEdge ]];

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

    [sections insertObject:SPKTopicSection(@"Tab bar", @[ tabEditor, hideOnScroll ], nil) atIndex:0];

    return SPKTopicNavigationSetting(@"Interface", @"interface", 24.0, sections);
}

@end
