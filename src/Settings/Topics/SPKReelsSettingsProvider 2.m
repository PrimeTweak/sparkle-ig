#import "SPKReelsSettingsProvider.h"

#import "../../Shared/ActionButton/SPKActionButtonConfiguration.h"
#import "../../Utils.h"
#import "../SPKToggleMenu.h"
#import "../SPKTopicSettingsSupport.h"

static NSString *const kSPKReelsActionButtonEnabledKey = @"reels_action_btn";

@implementation SPKReelsSettingsProvider

+ (SPKSetting *)rootSetting {
    return SPKTopicNavigationSetting(@"Reels", @"reels", 24.0, @[
        SPKTopicSection(@"Layout", @[
            [SPKSetting switchCellWithTitle:@"Hide Reels header"
                                       icon:SPKSettingsIcon(@"reels")
                                defaultsKey:@"reels_hide_header"],
            ({
                SPKSetting *row = [SPKSetting switchCellWithTitle:@"Hide comment bar"
                                                             icon:SPKSettingsIcon(@"comment")
                                                      defaultsKey:@"reels_hide_viewer_comment_bar"
                                                  requiresRestart:YES];
                row.helpText = @"Removes the comment field at the bottom of the reels viewer.";
                row.searchKeywords = @"comment bar viewer reels hide field";
                row;
            }),
            [SPKSetting switchCellWithTitle:@"Hide repost button"
                                       icon:SPKSettingsIcon(@"repost")
                                defaultsKey:@"reels_hide_repost_btn"
                            requiresRestart:YES],
            ({
                SPKSetting *g = SPKToggleMenuRowSetting(@"Hide counts", @"heart", @[
                    [SPKToggleMenuItem itemWithTitle:@"Likes"
                                            iconName:@"poll"
                                         defaultsKey:@"reels_hide_like_count"],
                    [SPKToggleMenuItem itemWithTitle:@"Comments"
                                            iconName:@"comment"
                                         defaultsKey:@"reels_hide_comment_count"],
                    [SPKToggleMenuItem itemWithTitle:@"Reposts"
                                            iconName:@"repost"
                                         defaultsKey:@"reels_hide_repost_count"],
                    [SPKToggleMenuItem itemWithTitle:@"Reshares"
                                            iconName:@"shares"
                                         defaultsKey:@"reels_hide_reshare_count"],
                    [SPKToggleMenuItem itemWithTitle:@"Saves"
                                            iconName:@"save"
                                         defaultsKey:@"reels_hide_save_count"],
                ]);
                g.searchKeywords = @"hide like comment repost reshare save count metrics";
                g;
            }),
        ],
                        nil),
        SPKTopicSection(@"Playback", @[
            ({
                SPKSetting *row = [SPKSetting menuCellWithTitle:@"Tap action"
                                         icon:SPKSettingsIcon(@"play")
                                         menu:SPKReelsTapControlMenu()];
                row.searchKeywords = @"tap controls";
                row;
            }),
            [SPKSetting switchCellWithTitle:@"Show progress bar"
                                       icon:SPKSettingsIcon(@"slider")
                                defaultsKey:@"reels_show_scrubber"],
            ({
                SPKSetting *row = [SPKSetting switchCellWithTitle:@"Keep Reels muted"
                                       icon:SPKSettingsIcon(@"volume_off")
                                defaultsKey:@"reels_disable_auto_unmute"
                            requiresRestart:YES];
                row.helpText = @"Reels stay muted even after you press a volume button.";
                row;
            }),
            [SPKSetting switchCellWithTitle:@"Disable Reels tab refresh"
                                       icon:SPKSettingsIcon(@"arrow_cw")
                                defaultsKey:@"reels_disable_tab_refresh"]
        ],
                        @"Tap Controls changes what happens when you tap on a reel. Auto-unmuting controls prevent reels from unmuting when volume or silent mode changes."),
        SPKTopicSection(@"Limits", @[
            ({
                SPKSetting *row = [SPKSetting switchCellWithTitle:@"One reel at a time"
                                       icon:SPKSettingsIcon(@"autoscroll")
                                defaultsKey:@"reels_disable_scrolling"
                            requiresRestart:YES];
                row.helpText = @"Stops the next reel from scrolling in by itself when one ends.";
                row;
            }),
            ({
                SPKSetting *s = [SPKSetting switchCellWithTitle:@"Limit Reels per session"
                                                           icon:SPKSettingsIcon(@"arrow_down")
                                                    defaultsKey:@"reels_prevent_doom_scroll"];
                s.searchKeywords = @"doom scrolling doom scrolling limit";
                // R5: reveals the per-session counter below while on.
                s.reloadsTableOnSwitchChange = YES;
                s.helpText = @"Stops loading new reels once the limit is hit. Turning this on reveals the per-session counter.";
                s;
            }),
            ({
                SPKSetting *s = [SPKSetting stepperCellWithTitle:@"Reels per session"
                                    subtitle:@"Only loads %@ %@"
                            icon:SPKSettingsIcon(@"chest")
                                 defaultsKey:@"reels_doom_scroll_limit"
                                         min:1
                                         max:100
                                        step:1
                                       label:@"reels"
                               singularLabel:@"reel"];
                // R5: hidden while Limit Reels per Session is off.
                s.hiddenProvider = ^BOOL {
                    return ![SPKUtils getBoolPref:@"reels_prevent_doom_scroll"];
                };
                s;
            }),
        ],
                        @"1. Stop vertical swiping between reels so the current reel stays put.\n"
                        @"2. Stop loading more reels once the limit below is reached.\n"
                        @"3. How many reels load before Prevent Doom Scrolling kicks in."),
        // Convention v1.2 gate row — see SPKToggleMenu.h. "Reel Refresh" keeps
        // its qualifier: the page also has Disable Reels Tab Refresh.
        SPKTopicSection(@"", @[
            SPKActionButtonRowSetting(kSPKReelsActionButtonEnabledKey,
                                      @"Choose what tapping the action button does. Long press opens the full menu.",
                                      @[
                [SPKSetting switchCellWithTitle:@"Show action button"
                                           icon:SPKSettingsIcon(@"action")
                                    defaultsKey:kSPKReelsActionButtonEnabledKey],
                SPKActionButtonDefaultActionNavigationSetting(SPKActionButtonSourceReels),
                SPKActionButtonConfigurationNavigationSetting(SPKActionButtonSourceReels, @"Reels", SPKActionButtonSupportedActionsForSource(SPKActionButtonSourceReels), SPKActionButtonDefaultSectionsForSource(SPKActionButtonSourceReels))
                                      ]),
            SPKToggleMenuRowSetting(@"Confirmations", @"circle_check", @[
                [SPKToggleMenuItem itemWithTitle:@"Like"
                                        iconName:@"heart"
                                     defaultsKey:@"reels_confirm_like"],
                [SPKToggleMenuItem itemWithTitle:@"Double tap"
                                        iconName:@"heart"
                                     defaultsKey:@"reels_confirm_double_tap_like"],
                [SPKToggleMenuItem itemWithTitle:@"Reel refresh"
                                        iconName:@"arrow_cw"
                                     defaultsKey:@"reels_confirm_refresh"],
                [SPKToggleMenuItem itemWithTitle:@"Repost"
                                        iconName:@"repost"
                                     defaultsKey:@"reels_confirm_repost"],
            ])
        ],
                        nil)
    ]);
}

@end
