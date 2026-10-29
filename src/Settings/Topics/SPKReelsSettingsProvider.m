#import "SPKReelsSettingsProvider.h"

#import "../../Features/Reels/HideReelsHeader.h"
#import "../../Features/Reels/ReelsAutoScrollDefault.h"
#import "../../Shared/ActionButton/SPKActionButtonConfiguration.h"
#import "../../Utils.h"
#import "../SPKToggleMenu.h"
#import "../SPKTopicSettingsSupport.h"

static NSString *const kSPKReelsActionButtonEnabledKey = @"reels_action_btn";

@implementation SPKReelsSettingsProvider

+ (SPKSetting *)rootSetting {
    return SPKTopicNavigationSetting(@"Reels", @"reels", 24.0, @[
        SPKTopicSection(@"Layout", @[
            ({
                // The reels viewer builds its bar once per session, so a change has to reach
                // the bar already on screen.
                SPKSetting *hideHeader = [SPKSetting switchCellWithTitle:@"Hide Reels header"
                                                                    icon:SPKSettingsIcon(@"reels")
                                                             defaultsKey:@"reels_hide_header"];
                hideHeader.action = ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:SPKHideReelsHeaderDidChangeNotification
                                                                        object:nil];
                };
                hideHeader;
            }),
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
                SPKSetting *row = [SPKSetting switchCellWithTitle:@"Hide visual search button"
                                                             icon:SPKSettingsIcon(@"visual_search")
                                                      defaultsKey:@"reels_hide_visual_search_btn"];
                row.helpText = @"Removes the visual search button from reels.";
                row.searchKeywords = @"visual search lens image button";
                row;
            }),
            ({
                SPKSetting *row = [SPKSetting switchCellWithTitle:@"Show repost date"
                                                             icon:SPKSettingsIcon(@"calendar")
                                                      defaultsKey:@"reels_show_repost_date"];
                row.helpText = @"Shows when the reel was reposted, under the name in the sheet opened from the repost bubble.";
                row.searchKeywords = @"repost date time reposted when";
                row;
            }),
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
                SPKSetting *row = [SPKSetting switchCellWithTitle:@"Playback controls"
                                                             icon:SPKSettingsIcon(@"playback")
                                                      defaultsKey:@"reels_playback_controls"];
                row.helpText = @"Long press a reel's more button for speed, seeking and pause controls. Turning this on reveals Keep speed for.";
                row.searchKeywords = @"speed seek pause playback rate faster slower";
                // R5: reveals Keep speed for in place.
                row.reloadsTableOnSwitchChange = YES;
                row;
            }),
            ({
                SPKSetting *row = [SPKSetting menuCellWithTitle:@"Keep speed for"
                                                           icon:SPKSettingsIcon(@"clock")
                                                           menu:SPKPlaybackSpeedScopeMenu(@"reels_playback_speed_scope")];
                row.defaultsKey = @"reels_playback_speed_scope";
                row.helpText = @"Whether a picked speed applies to that reel, until you leave Reels, or to every reel. The playback panel can change it too.";
                row.hiddenProvider = ^BOOL {
                    return ![SPKUtils getBoolPref:@"reels_playback_controls"];
                };
                row;
            }),
            ({
                SPKSetting *row = [SPKSetting switchCellWithTitle:@"Start Reels muted"
                                       icon:SPKSettingsIcon(@"volume_off")
                                defaultsKey:@"reels_disable_auto_unmute"
                            requiresRestart:YES];
                row.helpText = @"Reels start without sound until you unmute them. Applies to every account.";
                row.searchKeywords = @"keep muted sound volume mute";
                row;
            }),
            [SPKSetting switchCellWithTitle:@"Disable Reels tab refresh"
                                       icon:SPKSettingsIcon(@"arrow_cw")
                                defaultsKey:@"reels_disable_tab_refresh"],
            ({
                SPKSetting *row = [SPKSetting menuCellWithTitle:@"Auto scroll"
                                                           icon:SPKSettingsIcon(@"autoscroll")
                                                           menu:SPKReelsAutoScrollDefaultMenu()];
                row.helpText = @"Turns Reels auto scroll on or off at each launch; Default keeps Instagram's choice. The switch in Reels still works until the next launch, on accounts where Instagram offers it.";
                row.searchKeywords = @"auto scroll autoscroll next reel launch";
                // One reel at a time forces auto scroll off.
                row.enabledProvider = ^BOOL {
                    return ![SPKUtils getBoolPref:@"reels_disable_scrolling"];
                };
                row;
            })
        ],
                        @"Tap Controls changes what happens when you tap on a reel. Auto-unmuting controls prevent reels from unmuting when volume or silent mode changes."),
        SPKTopicSection(@"Limits", @[
            ({
                SPKSetting *row = [SPKSetting switchCellWithTitle:@"Disable looping"
                                                             icon:SPKSettingsIcon(@"loop")
                                                      defaultsKey:@"reels_stop_looping"];
                row.helpText = @"Reels stop on their last frame instead of looping; tap play to watch again. Paused while Auto scroll is On.";
                row.searchKeywords = @"stop looping loop replay repeat end";
                // Auto scroll in force overrides it.
                row.enabledProvider = ^BOOL {
                    return ![SPKReelsAutoScrollEffectiveMode() isEqualToString:@"on"];
                };
                row;
            }),
            ({
                SPKSetting *row = [SPKSetting switchCellWithTitle:@"One reel at a time"
                                       icon:SPKSettingsIcon(@"autoscroll")
                                defaultsKey:@"reels_disable_scrolling"
                            requiresRestart:YES];
                row.helpText = @"Stops the next reel from scrolling in by itself when one ends.";
                // Gates the Auto scroll and Disable looping rows.
                row.reloadsTableOnSwitchChange = YES;
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
