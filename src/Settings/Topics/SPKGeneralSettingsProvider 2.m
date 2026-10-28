#import "SPKGeneralSettingsProvider.h"

#import "../../AssetUtils.h"
#import "../../Shared/Account/SPKAccountManager.h"
#import "../../Features/Feed/HeaderActionButton.h"
#import "../../Shared/ActionButton/ActionButtonCore.h"
#import "../../Utils.h"
#import "../SPKActionSectionIconPickerViewController.h"
#import "../SPKToggleMenu.h"
#import "../SPKAppIconCatalog.h"
#import "../SPKAppIconPickerViewController.h"
#import "../SPKTopicSettingsSupport.h"

#pragma mark - Toggle groups behind a navigation row

// The accessory count and the rows are built from the same list, so a toggle
// added here can never fall out of the count shown on the parent row. Same
// principle as hanging `helpText` on the row instead of listing it in a footer:
// one source of truth, no second list to keep in sync.
//
// Spec keys: @"title" (required), @"key" (required), @"help" (optional).

/// State for a page of "Hide …" toggles, shown on the row that leads to it:
/// `Off`, `N hidden`, or `All hidden`. Re-read on every `viewWillAppear`, so it
/// refreshes on the way back from the sub-page with no extra plumbing.
static NSString *SPKGeneralHiddenCountAccessory(NSArray<NSDictionary<NSString *, NSString *> *> *specs) {
    NSUInteger on = 0;
    for (NSDictionary<NSString *, NSString *> *spec in specs) {
        if ([SPKUtils getBoolPref:spec[@"key"]]) {
            on++;
        }
    }

    if (on == 0)
        return @"Off";
    if (on == specs.count)
        return @"All hidden";
    return [NSString stringWithFormat:@"%lu hidden", (unsigned long)on];
}

#pragma mark -

@implementation SPKGeneralSettingsProvider

+ (SPKSetting *)defaultMenuIconSetting {
    SPKActionSectionIconPickerViewController *controller =
        [[SPKActionSectionIconPickerViewController alloc] initWithSelectedIconName:SPKActionButtonOpenMenuIconName()
                                                                          onSelect:^(NSString *iconName) {
                                                                              SPKPreferenceSetObject(iconName.length > 0 ? iconName : @"action", @"general_action_btn_default_menu_icon");
                                                                              [[NSNotificationCenter defaultCenter] postNotificationName:SPKActionButtonConfigurationDidChangeNotification object:nil];
                                                                          }];
    controller.title = @"Open Menu Icon";

    SPKSetting *setting = [SPKSetting navigationCellWithTitle:@"Open menu icon"
                                                     subtitle:nil
                                                         icon:SPKSettingsIcon(@"action")
                                               viewController:controller];
    // The row's icon mirrors the chosen glyph, so the (cryptic) catalog name is
    // redundant as accessory text — let the adaptive icon convey the selection.
    setting.iconProvider = ^UIImage * {
        return SPKSettingsIcon(SPKActionButtonOpenMenuIconName());
    };
    setting.searchKeywords = @"glyph action button open menu";
    return setting;
}

+ (SPKSetting *)appIconSetting {
    SPKAppIconPickerViewController *controller = [[SPKAppIconPickerViewController alloc] initWithSelectedIdentifier:[SPKAppIconCatalog currentAppIconIdentifier]
                                                                                                           onSelect:nil];
    SPKSetting *setting = [SPKSetting navigationCellWithTitle:@"App icon"
                                                     subtitle:nil
                                                         icon:SPKSettingsIcon(@"app")
                                               viewController:controller];
    setting.accessoryTextProvider = ^NSString * {
        SPKAppIconItem *currentIcon = [SPKAppIconCatalog currentAppIcon];
        return currentIcon.displayName.length > 0 ? currentIcon.displayName : @"Default";
    };
    setting.helpText = @"Only icons that ship inside the installed Instagram app can be used.";
    setting.searchKeywords = @"alternate icons bundle";
    return setting;
}

+ (SPKSetting *)perAccountSetting {
    SPKSetting *setting = [SPKSetting switchCellWithTitle:@"Per-account settings"
                                                     icon:SPKSettingsIcon(@"user_circle")
                                              defaultsKey:kSPKPrefPerAccountSettings];
    // Changes which key namespace every feature reads, and most enabled-state is
    // captured at hook install, so a restart applies it cleanly.
    setting.requiresRestart = YES;
    // Was the "How It Works" alert button — same text, standard ⓘ sheet now.
    setting.helpText = @"Each logged-in account gets its own Sparkle settings. A newly seen "
                       @"account starts from your current settings until you change something.\n\n"
                       @"These stay shared across all accounts:\n"
                       @"•  App icon\n"
                       @"•  Appearance & Liquid Glass\n"
                       @"•  Tab bar order & visibility\n"
                       @"•  Quick access shortcuts (Settings & Gallery)\n"
                       @"•  Main feed mode (For You / Following)\n"
                       @"•  Disable video autoplay\n"
                       @"•  Reels doom scroll & limits\n"
                       @"•  Hide UI on capture\n"
                       @"•  Download encoding settings\n"
                       @"•  Gallery view, sort & lock\n"
                       @"•  Fix duplicate notifications\n"
                       @"•  Disable All (master switch)\n\n"
                       @"Gallery media ownership is controlled separately in Gallery settings.";
    setting.searchKeywords = @"how it works multi account shared";
    return setting;
}

+ (SPKSetting *)rootSetting {
    SPKSetting *clearCacheSetting = [SPKSetting buttonCellWithTitle:@"Clear cache"
                                                           subtitle:nil
                                                               icon:SPKSettingsIcon(@"trash")
                                                             action:^(void) {
                                                                 unsigned long long freedBytes = [SPKUtils cleanCacheReturningFreedBytes];
                                                                 NSString *subtitle = freedBytes > 0
                                                                                          ? [NSString stringWithFormat:@"Freed %@", [NSByteCountFormatter stringFromByteCount:(long long)freedBytes countStyle:NSByteCountFormatterCountStyleFile]]
                                                                                          : @"Cache was already empty";
                                                                 SPKNotify(kSPKNotificationSettingsClearCache, @"Cache cleared", subtitle, @"circle_check_filled", SPKNotificationToneForIconResource(@"circle_check_filled"));
                                                             }];
    clearCacheSetting.tintColor = [SPKUtils SPKColor_InstagramDestructive];
    clearCacheSetting.iconTintColor = [SPKUtils SPKColor_InstagramDestructive];
    clearCacheSetting.accessoryTextProvider = ^NSString * {
        return [SPKUtils formattedCacheSize];
    };

    // ---- Behavior ------------------------------------------------------

    SPKSetting *copyText = [SPKSetting switchCellWithTitle:@"Copy text"
                                                      icon:SPKSettingsIcon(@"text")
                                               defaultsKey:@"general_copy_text"];
    copyText.helpText = @"Long-press any text field in the app.";
    copyText.searchKeywords = @"long press clipboard select";

    SPKSetting *stripTracking = [SPKSetting switchCellWithTitle:@"Copy links without tracking"
                                                           icon:SPKSettingsIcon(@"user_unfollow")
                                                    defaultsKey:@"general_strip_share_link_tracking"];
    stripTracking.helpText = @"The copied link loses the IDs Instagram uses to track who shared it.";
    stripTracking.searchKeywords = @"igshid utm referrer identifiers url";

    SPKSetting *holdSendCopyLink = [SPKSetting switchCellWithTitle:@"Long-press send to copy link"
                                                              icon:SPKSettingsIcon(@"link")
                                                       defaultsKey:@"general_hold_send_copy_link"];
    holdSendCopyLink.helpText = @"Long-press the send or share button to get the post link.";
    holdSendCopyLink.searchKeywords = @"long press share button post link hold send";

    // ---- Sharing -------------------------------------------------------


    // ---- Media Preview & Menu ------------------------------------------

    SPKSetting *showMediaInfo = [SPKSetting switchCellWithTitle:@"Show media info"
                                                           icon:SPKSettingsIcon(@"info")
                                                    defaultsKey:@"general_preview_show_metadata"];
    showMediaInfo.searchKeywords = @"author date overlay metadata";

    SPKSetting *showDateInMenu = [SPKSetting switchCellWithTitle:@"Show date in menu"
                                                            icon:SPKSettingsIcon(@"calendar")
                                                     defaultsKey:@"general_action_btn_show_date"];
    showDateInMenu.searchKeywords = @"timestamp posted exact time";



    // ---- Storage -------------------------------------------------------

    SPKSetting *autoClearCache = [SPKSetting menuCellWithTitle:@"Auto clear cache"
                                                          icon:SPKSettingsIcon(@"clock")
                                                          menu:SPKCacheAutoClearMenu()];
    autoClearCache.helpText = @"Runs each time you open Instagram — not on a timer.";
    autoClearCache.searchKeywords = @"foreground launch active schedule";

    // ---- App -----------------------------------------------------------

    // The footer line only restated the title; "vibrations" was the one word
    // worth keeping, so it moves to the search keywords.
    SPKSetting *disableHaptics = [SPKSetting switchCellWithTitle:@"Disable haptics"
                                                            icon:SPKSettingsIcon(@"haptics")
                                                     defaultsKey:@"general_disable_haptics"];
    disableHaptics.searchKeywords = @"app vibration vibrations taptic feedback";

    SPKSetting *root = SPKTopicNavigationSetting(@"General", @"settings", 24.0, @[

        // Behavior + Sharing merged: four rows, one subject — copying and
        // sharing. (No Recent Searches moved to Interface › Explore & Search;
        // the two Confirm rows live in the Confirmations gate row below.)
        SPKTopicSection(@"Sharing & media", @[
            copyText,
            stripTracking,
            holdSendCopyLink,
            showMediaInfo,
            showDateInMenu],
                        nil),
        // Kept as a footer: it describes the section, not any one row, so it has
        // no row to hang off and no ⓘ to open.
        // Three homogeneous "Hide in X" sub-pages become three gates — the
        // state reads at a glance ("Hide Ads · 4 on") and General loses all
        // its depth. Meta AI's two per-item helps live in its gate's ⓘ.
        SPKTopicSection(@"Recommendations", @[
            ({
                SPKSetting *gate = SPKToggleMenuRowSetting(@"Hide ads", @"ads", @[
                    [SPKToggleMenuItem itemWithTitle:@"Feed"
                                            iconName:@"feed"
                                         defaultsKey:@"general_hide_ads_feed"],
                    [SPKToggleMenuItem itemWithTitle:@"Stories"
                                            iconName:@"story"
                                         defaultsKey:@"general_hide_ads_stories"],
                    [SPKToggleMenuItem itemWithTitle:@"Reels"
                                            iconName:@"reels"
                                         defaultsKey:@"general_hide_ads_reels"],
                    [SPKToggleMenuItem itemWithTitle:@"Explore"
                                            iconName:@"explore_grid"
                                         defaultsKey:@"general_hide_ads_explore"],
                    [SPKToggleMenuItem itemWithTitle:@"Reels shopping button"
                                            iconName:@"shopping_bag"
                                         defaultsKey:@"general_hide_reels_shopping_cta"],
                ]);
                gate.searchKeywords = @"ads advertising sponsored promoted cta";
                gate;
            }),
            ({
                SPKSetting *gate = SPKToggleMenuRowSetting(@"Hide Meta AI", @"meta_ai", @[
                    [SPKToggleMenuItem itemWithTitle:@"Messages"
                                            iconName:@"messages"
                                         defaultsKey:@"general_hide_meta_ai_msgs"],
                    [SPKToggleMenuItem itemWithTitle:@"Explore & search"
                                            iconName:@"search"
                                         defaultsKey:@"general_hide_meta_ai_explore"],
                    [SPKToggleMenuItem itemWithTitle:@"Comments"
                                            iconName:@"comment"
                                         defaultsKey:@"general_hide_meta_ai_comments"],
                    [SPKToggleMenuItem itemWithTitle:@"Creation tools"
                                            iconName:@"photo"
                                         defaultsKey:@"general_hide_meta_ai_creation"],
                    [SPKToggleMenuItem itemWithTitle:@"Everywhere else"
                                            iconName:@"app"
                                         defaultsKey:@"general_hide_meta_ai_global"],
                ]);
                // Was the two per-item helps of the old sub-page.
                gate.helpText = @"Direct covers the inbox, composer, recipients, themes and message menus."
                                @"Global AI Chrome removes generic Meta AI buttons, placeholders and branded entry points.";
                gate.searchKeywords = @"ai assistant llama global ai chrome direct";
                gate;
            }),
            ({
                SPKSetting *gate = SPKToggleMenuRowSetting(@"Hide suggested users", @"users", @[
                    [SPKToggleMenuItem itemWithTitle:@"Feed"
                                            iconName:@"feed"
                                         defaultsKey:@"general_hide_suggested_users_feed"],
                    [SPKToggleMenuItem itemWithTitle:@"Reels"
                                            iconName:@"reels"
                                         defaultsKey:@"general_hide_suggested_users_reels"],
                    [SPKToggleMenuItem itemWithTitle:@"Messages"
                                            iconName:@"messages"
                                         defaultsKey:@"general_hide_suggested_users_msgs"],
                    [SPKToggleMenuItem itemWithTitle:@"Search"
                                            iconName:@"search"
                                         defaultsKey:@"general_hide_suggested_users_search"],
                    [SPKToggleMenuItem itemWithTitle:@"Profile"
                                            iconName:@"user_circle"
                                         defaultsKey:@"general_hide_suggested_users_profile"],
                    [SPKToggleMenuItem itemWithTitle:@"Activity"
                                            iconName:@"notification"
                                         defaultsKey:@"general_hide_suggested_users_activity"],
                    [SPKToggleMenuItem itemWithTitle:@"Followers & following"
                                            iconName:@"users"
                                         defaultsKey:@"general_hide_suggested_users_follow_lists"],
                    [SPKToggleMenuItem itemWithTitle:@"Subscriptions"
                                            iconName:@"users"
                                         defaultsKey:@"general_hide_suggested_users_subscriptions"],
                ]);
                gate.searchKeywords = @"suggestions recommended accounts follow lists";
                gate;
            }),
        ],
                        nil),
        SPKTopicSection(@"App", @[
            // Moved in from Feed: the gesture opens Instagram's icon picker and
            // Sparkle's own picker is two rows up — they belong side by side.
            ({
                SPKSetting *row = [SPKSetting switchCellWithTitle:@"Disable app icon gesture"
                                                             icon:SPKSettingsIcon(@"app")
                                                      defaultsKey:@"feed_disable_appicon_gesture"];
                row.helpText = @"Stops the header-logo long-press from opening Instagram's icon picker. Sparkle's own picker is App Icon, above.";
                row.searchKeywords = @"logo long press picker";
                row;
            }),
            disableHaptics,
            [self perAccountSetting],
            [self appIconSetting],
            [self defaultMenuIconSetting]],
                        nil),

        // Clearing and scheduling the cache is storage, not an app preference.
        SPKTopicSection(@"Storage", @[
            autoClearCache,
            clearCacheSetting],
                        nil),

        // Convention v1.2 gate row — see SPKToggleMenu.h. The three Confirm
        // rows that lived in Sharing and Comments, short residues like
        // everywhere else.
        SPKTopicSection(@"", @[
            ({
                SPKSetting *confirmations = SPKToggleMenuRowSetting(@"Confirmations", @"circle_check", @[
                [SPKToggleMenuItem itemWithTitle:@"New post"
                                        iconName:@"messages"
                                     defaultsKey:@"general_confirm_send"],
                [SPKToggleMenuItem itemWithTitle:@"Comment like"
                                        iconName:@"heart"
                                     defaultsKey:@"general_comments_confirm_like"],
                [SPKToggleMenuItem itemWithTitle:@"Opening a link"
                                        iconName:@"external_link"
                                     defaultsKey:@"general_confirm_open_link"],
                ]);
                confirmations;
            })
        ],
                        nil),
    ]);
    // The only root tab whose name doesn't describe its content — the native
    // "Accounts Center" pattern. Mirrors the six real sections.
    root.subtitle = @"Recommendations, sharing, media, accounts, storage";
    return root;
}

@end
