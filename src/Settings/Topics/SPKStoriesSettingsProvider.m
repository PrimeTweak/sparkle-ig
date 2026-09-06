#import "SPKStoriesSettingsProvider.h"

#import "../../Shared/ActionButton/SPKActionButtonConfiguration.h"
#import "../../Shared/Stories/SPKStoryContext.h"
#import "../../Utils.h"
#import "../SPKSettingsViewController.h"
#import "../SPKToggleMenu.h"
#import "../SPKTopicSettingsSupport.h"
static NSString *const kSPKStoriesActionButtonEnabledKey = @"stories_action_btn";

static NSDictionary *SPKStoriesSeenReceiptsSection(void);
static NSArray *SPKStoriesSettingsSections(void);

@interface SPKStoriesSettingsViewController : SPKSettingsViewController
@end

@implementation SPKStoriesSettingsViewController
- (instancetype)init {
    return [super initWithTitle:@"Stories" sections:SPKStoriesSettingsSections() reduceMargin:NO];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self replaceSections:SPKStoriesSettingsSections()];
}

- (void)switchChanged:(UISwitch *)sender {
    SPKSetting *row = [self settingForSender:sender];
    [super switchChanged:sender];
    if ([row.defaultsKey isEqualToString:@"stories_manual_seen"]) {
        [self replaceSections:SPKStoriesSettingsSections()];
    }
}
@end

static NSDictionary *SPKStoriesSeenReceiptsSection(void) {
    BOOL manualSeen = [SPKUtils getBoolPref:@"stories_manual_seen"];
    NSString *footer = manualSeen
                           ? @"1. Stories are not marked seen automatically, except users in Excluded Users.\n"
                             @"2. Mark the story as seen when you press like.\n"
                             @"3. Mark the story as seen when you send a reply.\n"
                             @"4. Excluded Users use Instagram's normal seen behavior and do not need the eye button."
                           : @"1. Stories use Instagram's normal seen behavior, except users in Included Users.\n"
                             @"2. Mark the story as seen when you press like.\n"
                             @"3. Mark the story as seen when you send a reply.\n"
                             @"4. Included Users require the eye button, story like, or story reply to mark seen.";
    SPKSetting *manualSeenList = [SPKSetting navigationCellWithTitle:SPKStoryManualSeenListTitle(manualSeen)
                                                            subtitle:nil
                                                                icon:SPKSettingsIcon(@"users")
                                                      viewController:SPKStoryManualSeenListViewController()];
    manualSeenList.userInfo = @{@"accessoryText" : [NSString stringWithFormat:@"%lu", (unsigned long)SPKStoryManualSeenUserList(manualSeen).count]};
manualSeenList.hiddenProvider = ^BOOL {
    // R5: the chat list only applies while manual seen is on.
    return ![SPKUtils getBoolPref:@"stories_manual_seen"];
};

    // The auto-seen triggers only do anything while manual seen is on. Keep their
    // stored value but lock the cells when manual seen is off.
    // Convention v1.3 gate — two items only, but the family is already gated
    // in Messages: transversal uniformity wins over the size threshold. The
    // shared guard moves onto the gate.
    SPKSetting *markSeenGate = ({
        SPKSetting *g = SPKToggleMenuRowSetting(@"Mark seen on…", @"eye", @[
            [SPKToggleMenuItem itemWithTitle:@"Like"
                                    iconName:@"heart"
                                 defaultsKey:@"stories_mark_seen_on_like"],
            [SPKToggleMenuItem itemWithTitle:@"Reply"
                                    iconName:@"reply"
                                 defaultsKey:@"stories_mark_seen_on_reply"],
        ]);
        g.hiddenProvider = ^BOOL {
            return ![SPKUtils getBoolPref:@"stories_manual_seen"];
        };
        g.searchKeywords = @"mark seen like reply auto";
        g;
    });

    return SPKTopicSection(@"Seen receipts", @[
            [SPKSetting switchCellWithTitle:@"Preview without being seen"
                                       icon:SPKSettingsIcon(@"story")
                                defaultsKey:@"stories_unlock_preview"],
            ({
            SPKSetting *row = [SPKSetting switchCellWithTitle:@"Manually mark seen"
                                       icon:SPKSettingsIcon(@"eye")
                                defaultsKey:@"stories_manual_seen"];
            row.reloadsTableOnSwitchChange = YES;  // R5: reveals the dependent seen-receipt rows in place.
            row.helpText = @"Stories stop sending read receipts until the eye button is tapped. Turning this on reveals Mark Seen On\u2026 and the viewer tools.";
            row;
        }),
            markSeenGate,
            manualSeenList,
            // Acts on the story viewer list; help text replaces the former
            // numbered footer note.
            ({
                SPKSetting *s = [SPKSetting switchCellWithTitle:@"Search viewer list"
                                                           icon:SPKSettingsIcon(@"search")
                                                    defaultsKey:@"stories_search_viewer_list"];
                s.helpText = @"Adds a search button to your story's viewer list, to search and filter viewers.";
                s;
            })],
                           footer);
}

static NSArray *SPKStoriesSettingsSections(void) {
    return @[
        // Leads the page: seen receipts govern what viewing a story reports.


        // "Other" was the confession that no subject had been found — these four
        // all act while viewing a story.
        SPKTopicSection(@"While viewing", @[
            ({
                // Renamed from "Stop Auto Advance" — aligned with the Messages
                // twin (lot 1) and the Disable lexicon; "stop" stays searchable.
                SPKSetting *s = [SPKSetting switchCellWithTitle:@"Stay on current story"
                                                           icon:SPKSettingsIcon(@"autoplay_off")
                                                    defaultsKey:@"stories_stop_auto_advance"];
                s.searchKeywords = @"stop next skip";
                s;
            }),
            // The three "Advance on…" rows, one gate. Their three footer notes
            // become the gate's ⓘ — a numbered footer can only point at rows.
            ({
                SPKSetting *g = SPKToggleMenuRowSetting(@"Advance on…", @"autoscroll", @[
                    [SPKToggleMenuItem itemWithTitle:@"Eye button"
                                            iconName:@"eye"
                                         defaultsKey:@"stories_advance_on_manual_seen"],
                    [SPKToggleMenuItem itemWithTitle:@"Like"
                                            iconName:@"heart"
                                         defaultsKey:@"stories_advance_on_like_seen"],
                    [SPKToggleMenuItem itemWithTitle:@"Reply"
                                            iconName:@"reply"
                                         defaultsKey:@"stories_advance_on_reply_seen"],
                ]);
                g.helpText = @"Moves to the next story when you press the eye button, like it, or reply.";
                g.searchKeywords = @"advance auto next story eye button like reply";
                g;
            }),
            [SPKSetting switchCellWithTitle:@"Hide trending prompts"
                                       icon:SPKSettingsIcon(@"arrow_up_right")
                                defaultsKey:@"stories_hide_join_trending"],
            ({
                SPKSetting *row = [SPKSetting switchCellWithTitle:@"Hide recent highlights"
                                                             icon:SPKSettingsIcon(@"highlights")
                                                      defaultsKey:@"stories_hide_recent_highlights"];
                row.helpText = @"Drops resurfaced highlights from the tray, from tapping forward and from swiping sideways.";
                row.searchKeywords = @"highlights recent resurfaced tray hide";
                row;
            }),
            [SPKSetting switchCellWithTitle:@"Show story mentions"
                                       icon:SPKSettingsIcon(@"mention")
                                defaultsKey:@"stories_mentions_btn"],
            [SPKSetting switchCellWithTitle:@"Show poll vote counts"
                                       icon:SPKSettingsIcon(@"poll")
                                defaultsKey:@"stories_poll_vote_counts"],
            [SPKSetting switchCellWithTitle:@"Hide Instagram plus button"
                                       icon:SPKSettingsIcon(@"aura")
                                defaultsKey:@"stories_hide_ig_plus_button"]],
                        @"1. Prevent automatically moving to the next story.\n"
                        @"2. Choose which gestures move to the next story.\n"
                        @"3. Hide the the \"Join a trending\" / \"Add Yours\" promo cards from stories.\n"
                        @"4. Enabling this will add a button above the bottom story bar, where you can see all mentioned users.\n"
                        @"5. Display the vote counts for each option the poll has.\n"
                        @"6. Unlock \"Story Preview\": the story long-press menu shows the actual story without appearing on the viewer list.\n"
                        @"7. Hide the Instagram Plus button in your story's viewer list."),
        SPKStoriesSeenReceiptsSection(),

        // Convention v1.2 gate row — see SPKToggleMenu.h. Was the "Confirmations"
        // section (mid-page, plural header); now closes the page like everywhere.
        SPKTopicSection(@"Creation", @[
            ({
                SPKSetting *row = [SPKSetting switchCellWithTitle:@"Allow videos in photo sticker"
                                       icon:SPKSettingsIcon(@"video")
                                defaultsKey:@"stories_allow_video_sticker"];
                row.helpText = @"Lets the photo sticker pick a video from your library, not just a still.";
                row;
            }),
            [SPKSetting switchCellWithTitle:@"Show gallery upload button"
                                       icon:SPKSettingsIcon(@"sparkle_gallery")
                                defaultsKey:@"stories_gallery_upload_sticker"],
            ({
                SPKSetting *row = [SPKSetting switchCellWithTitle:@"Use detailed color picker"
                                       icon:SPKSettingsIcon(@"eyedropper")
                                defaultsKey:@"stories_detailed_color_picker"];
                row.helpText = @"Long-press the eyedropper to open the full colour picker instead of the swatches.";
                row;
            })
        ],
                        @"1. Allow selecting videos from your library in the story photo sticker.\n"
                        @"2. Use media from Sparkle Gallery as stickers.\n"
                        @"3. Long press on the eyedropper tool in stories to customize text color more precisely."),
        SPKTopicSection(@"", @[
            SPKActionButtonRowSetting(kSPKStoriesActionButtonEnabledKey,
                                      @"1. Add an action button above the bottom story bar.\n"
                                      @"2. Choose the default action. Long press opens the full menu.",
                                      @[
                [SPKSetting switchCellWithTitle:@"Show action button"
                                           icon:SPKSettingsIcon(@"action")
                                    defaultsKey:kSPKStoriesActionButtonEnabledKey],
                SPKActionButtonDefaultActionNavigationSetting(SPKActionButtonSourceStories),
                SPKActionButtonConfigurationNavigationSetting(SPKActionButtonSourceStories, @"Stories", SPKActionButtonSupportedActionsForSource(SPKActionButtonSourceStories), SPKActionButtonDefaultSectionsForSource(SPKActionButtonSourceStories))
        
                                      ]),
            SPKToggleMenuRowSetting(@"Confirmations", @"circle_check", @[
                [SPKToggleMenuItem itemWithTitle:@"Like"
                                        iconName:@"heart"
                                     defaultsKey:@"stories_confirm_like"],
                [SPKToggleMenuItem itemWithTitle:@"Quick reaction"
                                        iconName:@"reactions"
                                     defaultsKey:@"stories_confirm_quick_reaction"],
                [SPKToggleMenuItem itemWithTitle:@"Sticker interaction"
                                        iconName:@"sticker"
                                     defaultsKey:@"stories_confirm_sticker"],
            ])
        ],
                        nil)
    ];
}

@implementation SPKStoriesSettingsProvider

+ (SPKSetting *)rootSetting {
    SPKSetting *setting = [SPKSetting navigationCellWithTitle:@"Stories"
                                                     subtitle:nil
                                                         icon:SPKSettingsIcon(@"story")
                                               viewController:[[SPKStoriesSettingsViewController alloc] init]];
    setting.searchSectionsProvider = ^NSArray * {
        return SPKStoriesSettingsSections();
    };
    return SPKSettingApplyIconTint(setting, [SPKUtils SPKColor_InstagramPrimaryText]);
}

@end
