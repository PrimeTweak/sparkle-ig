#import "SPKFeedSettingsProvider.h"

#import "../../Features/Feed/HeaderActionButton.h"
#import "../../Shared/ActionButton/SPKActionButtonConfiguration.h"
#import "../../Utils.h"
#import "../SPKToggleMenu.h"
#import "../SPKTopicSettingsSupport.h"

static NSString *const kSPKFeedActionButtonEnabledKey = @"feed_action_btn";

@implementation SPKFeedSettingsProvider

static NSArray *SPKFeedCommentsSections(void) {
    SPKSetting *copyComment = [SPKSetting switchCellWithTitle:@"Copy comment"
                                                         icon:SPKSettingsIcon(@"copy")
                                                  defaultsKey:@"general_comments_copy_text"];
    copyComment.searchKeywords = @"clipboard comment menu";

    SPKSetting *commentMediaActions = [SPKSetting switchCellWithTitle:@"Media actions"
                                                                 icon:SPKSettingsIcon(@"action")
                                                          defaultsKey:@"general_comments_media_actions"];
    commentMediaActions.helpText = @"Adds Photos, Share, Gallery and link actions to GIF and photo comments.";
    commentMediaActions.searchKeywords = @"comment gif photos share gallery link";

    SPKSetting *commentGalleryUpload = [SPKSetting switchCellWithTitle:@"Attach photo to comments"
                                                                  icon:SPKSettingsIcon(@"photo")
                                                           defaultsKey:@"general_comments_gallery_upload"];
    commentGalleryUpload.helpText = @"Long-press the composer's photo button to attach from your Sparkle Gallery.";
    commentGalleryUpload.searchKeywords = @"attach composer sparkle gallery upload photo gallery";

    SPKSetting *swipeCloseComments = [SPKSetting switchCellWithTitle:@"Swipe to close"
                                                                icon:SPKSettingsIcon(@"left_right")
                                                         defaultsKey:@"general_comments_swipe_close"];
    swipeCloseComments.helpText = @"Close comments with a swipe. Turning this on reveals the direction picker.";
    swipeCloseComments.searchKeywords = @"comments gesture horizontal dismiss";
    // Greys Swipe Direction out immediately instead of after leaving the page.
    swipeCloseComments.reloadsTableOnSwitchChange = YES;

    SPKSetting *swipeDirection = SPKSettingApplySelectedMenuIcon([SPKSetting menuCellWithTitle:@"Swipe direction"
                                                                                          icon:SPKSettingsIcon(@"left_right")
                                                                                          menu:SPKSwipeCloseCommentsDirectionMenu()],
                                                                 SPKSettingsIcon(@"left_right"));
    swipeDirection.hiddenProvider = ^BOOL {
        return ![SPKUtils getBoolPref:@"general_comments_swipe_close"];
    };

    SPKSetting *commentSort = [SPKSetting switchCellWithTitle:@"Sort comments"
                                                         icon:SPKSettingsIcon(@"sort")
                                                  defaultsKey:@"feed_comments_sort_menu"
                                              requiresRestart:YES];
    commentSort.helpText = @"Reorders the thread by the date each comment was posted, and adds a button on the thread to switch order. Only loaded comments are reordered.";
    commentSort.searchKeywords = @"comment sort order chronological newest oldest top recent date";

    SPKSetting *commentSortMode = [SPKSetting menuCellWithTitle:@"Comment order"
                                                           icon:SPKSettingsIcon(@"clock")
                                                           menu:SPKCommentSortModeMenu()];
    commentSortMode.helpText = @"Order the thread opens in. The button on the thread cycles through the same three.";
    commentSortMode.searchKeywords = @"comment order newest oldest chronological date";
    commentSortMode.hiddenProvider = ^BOOL {
        return ![SPKUtils getBoolPref:@"feed_comments_sort_menu"];
    };

    SPKSetting *hideCommentShopping = [SPKSetting switchCellWithTitle:@"Hide shopping carousel"
                                                                 icon:SPKSettingsIcon(@"shopping_bag")
                                                          defaultsKey:@"general_comments_hide_shopping"];
    hideCommentShopping.helpText = @"Removes commerce carousels from comment threads.";
    hideCommentShopping.searchKeywords = @"comment commerce carousel shop shopping";

    SPKSetting *hideGiftsButton = [SPKSetting switchCellWithTitle:@"Hide gifts button"
                                                             icon:SPKSettingsIcon(@"gift")
                                                      defaultsKey:@"general_comments_hide_gifts_button"];
    hideGiftsButton.helpText = @"Removes the gift shortcut from the composer.";
    hideGiftsButton.searchKeywords = @"gift composer shortcut";

    // Comment settings relocated from General; keys unchanged.
    return @[
    SPKTopicSection(@"Comments", @[
                commentSort,
                commentSortMode,
                copyComment,
                commentMediaActions,
                commentGalleryUpload,
                swipeCloseComments,
                swipeDirection,
                hideCommentShopping,
                hideGiftsButton
            ],
                            nil)
    ];
}

+ (SPKSetting *)rootSetting {
    // ---- Action Button -------------------------------------------------

    SPKSetting *masterActionButton = [SPKSetting switchCellWithTitle:@"Show action button"
                                                                icon:SPKSettingsIcon(@"action")
                                                         defaultsKey:kSPKFeedActionButtonEnabledKey];
    // Same wording as the Messages master toggle — the six action-button pages
    // share one gesture template, so the sheets must read identically everywhere.
    masterActionButton.helpText = @"Tap runs the default action. Long-press opens the full action menu.";



    // ---- Layout --------------------------------------------------------

    SPKSetting *mainFeedMode = SPKSettingApplySelectedMenuIcon(({
                                                                   SPKSetting *row = [SPKSetting menuCellWithTitle:@"Default feed" icon:SPKSettingsIcon(@"feed") menu:SPKMainFeedModeMenu()];
                                                                   row.searchKeywords = @"main feed";
                                                                   row;
                                                               }), SPKSettingsIcon(@"feed"));
    mainFeedMode.helpText = @"Following is the chronological feed of accounts you follow — Instagram keeps labelling the tab \"For you\".";
    mainFeedMode.searchKeywords = @"following chronological algorithm for you";


    SPKSetting *hideEntireFeed = [SPKSetting switchCellWithTitle:@"Hide entire feed"
                                                            icon:SPKSettingsIcon(@"feed")
                                                     defaultsKey:@"feed_hide_entire_feed"];
    hideEntireFeed.helpText = @"Hides every post and leaves only the feed header.";

    // ---- Media ---------------------------------------------------------

    SPKSetting *longPressExpand = [SPKSetting switchCellWithTitle:@"Long press to expand"
                                                             icon:SPKSettingsIcon(@"expand")
                                                      defaultsKey:@"feed_long_press_expand"];
    longPressExpand.helpText = @"Long-press any feed photo or video to open it full screen.";
    longPressExpand.searchKeywords = @"full screen viewer";

    // ---- Refresh -------------------------------------------------------

    SPKSetting *disableHomeRefresh = [SPKSetting switchCellWithTitle:@"Disable home tab refresh"
                                                                icon:SPKSettingsIcon(@"home")
                                                         defaultsKey:@"feed_disable_home_refresh"];
    disableHomeRefresh.helpText = @"Re-tapping the Home tab scrolls back to top without reloading the feed.";

    return SPKTopicNavigationSetting(@"Feed", @"feed", 24.0, @[
        SPKTopicSection(@"Layout", @[
            mainFeedMode,
            hideEntireFeed,
            // Stays a full row: requiresRestart disqualifies it from a gate
            // (doctrine R4) — the restart prompt needs the regular switch path.
            [SPKSetting switchCellWithTitle:@"Hide repost button"
                                       icon:SPKSettingsIcon(@"repost")
                                defaultsKey:@"feed_hide_repost_btn"
                            requiresRestart:YES],
            ({
                SPKSetting *g = SPKToggleMenuRowSetting(@"Hide feed elements", @"eye_off", @[
                    [SPKToggleMenuItem itemWithTitle:@"Stories tray"
                                            iconName:@"story"
                                         defaultsKey:@"feed_hide_stories_tray"],
                    [SPKToggleMenuItem itemWithTitle:@"Suggested posts"
                                            iconName:@"carousel"
                                         defaultsKey:@"feed_hide_suggested_posts"],
                    [SPKToggleMenuItem itemWithTitle:@"Suggested Reels"
                                            iconName:@"reels"
                                         defaultsKey:@"feed_hide_suggested_reels"],
                    [SPKToggleMenuItem itemWithTitle:@"Suggested Threads"
                                            iconName:@"threads"
                                         defaultsKey:@"feed_hide_suggested_threads"],
                ]);
                g.searchKeywords = @"hide stories tray suggested posts reels threads";
                g;
            }),
            ({
                SPKSetting *g = SPKToggleMenuRowSetting(@"Hide counts", @"heart", @[
                    [SPKToggleMenuItem itemWithTitle:@"Likes"
                                            iconName:@"poll"
                                         defaultsKey:@"feed_hide_like_count"],
                    [SPKToggleMenuItem itemWithTitle:@"Comments"
                                            iconName:@"comment"
                                         defaultsKey:@"feed_hide_comment_count"],
                    [SPKToggleMenuItem itemWithTitle:@"Reposts"
                                            iconName:@"repost"
                                         defaultsKey:@"feed_hide_repost_count"],
                    [SPKToggleMenuItem itemWithTitle:@"Reshares"
                                            iconName:@"shares"
                                         defaultsKey:@"feed_hide_reshare_count"],
                ]);
                g.searchKeywords = @"hide like comment repost reshare count metrics";
                g;
            }),
        ],
                        nil),
        SPKTopicSection(@"Playback & refresh", @[
            longPressExpand,
            ({
                SPKSetting *row = [SPKSetting switchCellWithTitle:@"Tap to play videos"
                                       icon:SPKSettingsIcon(@"autoplay_off")
                                defaultsKey:@"feed_disable_autoplay"
                            requiresRestart:YES];
                row.helpText = @"Videos wait for a tap instead of starting on their own. Takes effect after a restart.";
                row;
            }),
            ({
                SPKSetting *row = [SPKSetting switchCellWithTitle:@"Expand videos muted"
                                       icon:SPKSettingsIcon(@"volume_off")
                                defaultsKey:@"feed_expanded_vid_start_muted"];
                row.helpText = @"A video opened full screen starts with no sound.";
                row;
            }),
            disableHomeRefresh,
            [SPKSetting switchCellWithTitle:@"Disable background refresh"
                                       icon:SPKSettingsIcon(@"arrow_cw")
                                defaultsKey:@"feed_disable_bg_refresh"]
        ],
                        nil),
        // Comments is a full section again: eight rows deep enough to stand on
        // their own page were one tap away for no reason.
        SPKFeedCommentsSections().firstObject,
        SPKTopicSection(@"", @[
            SPKActionButtonRowSetting(kSPKFeedActionButtonEnabledKey,
                                      nil,
                                      @[
                masterActionButton,
                SPKActionButtonDefaultActionNavigationSetting(SPKActionButtonSourceFeed),
                SPKActionButtonConfigurationNavigationSetting(SPKActionButtonSourceFeed, @"Feed", SPKActionButtonSupportedActionsForSource(SPKActionButtonSourceFeed), SPKActionButtonDefaultSectionsForSource(SPKActionButtonSourceFeed))
                                      ]),
            SPKToggleMenuRowSetting(@"Confirmations", @"circle_check", @[
                [SPKToggleMenuItem itemWithTitle:@"Like"
                                        iconName:@"heart"
                                     defaultsKey:@"feed_confirm_post_like"],
                [SPKToggleMenuItem itemWithTitle:@"Double tap"
                                        iconName:@"heart"
                                     defaultsKey:@"feed_confirm_double_tap_like"],
                [SPKToggleMenuItem itemWithTitle:@"Repost"
                                        iconName:@"repost"
                                     defaultsKey:@"feed_confirm_repost"],
                [SPKToggleMenuItem itemWithTitle:@"Comment"
                                        iconName:@"comment"
                                     defaultsKey:@"feed_confirm_post_comment"],
            ])
        ],
                        nil)
    ]);
}

@end
