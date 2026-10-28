#import "SPKMessagesSettingsProvider.h"

#import "../../Features/Messages/DeletedMessagesLog/SPKDeletedMessagesStorage.h"
#import "../../Features/Messages/DeletedMessagesLog/SPKDeletedMessagesViewController.h"
#import "../../Shared/Account/SPKAccountManager.h"
#import "../../Shared/ActionButton/SPKActionButtonConfiguration.h"
#import "../../Shared/Messages/SPKDirectSeenContext.h"
#import "../../Utils.h"
#import "../SPKSettingsViewController.h"
#import "../SPKToggleMenu.h"
#import "../SPKTopicSettingsSupport.h"

static NSString *const kSPKMessagesActionButtonEnabledKey = @"msgs_action_btn";
static NSString *const kSPKMessagesActionButtonChatMediaKey = @"msgs_action_btn_chat_media";
static NSString *const kSPKMessagesAudioCallConfirmKey = @"msgs_confirm_audio_call";
static NSString *const kSPKMessagesVideoCallConfirmKey = @"msgs_confirm_video_call";

static NSArray *SPKMessagesSettingsSections(void);

// A switch cell that stays visible but is disabled while the "Audio Downloads"
// master toggle is off (keeping its stored value).
static SPKSetting *SPKAudioGatedSwitch(NSString *title, UIImage *icon, NSString *defaultsKey) {
    SPKSetting *setting = [SPKSetting switchCellWithTitle:title icon:icon defaultsKey:defaultsKey];
    setting.hiddenProvider = ^BOOL {
        return ![SPKUtils getBoolPref:@"downloads_audio_enabled"];
    };
    return setting;
}

@interface SPKMessagesSettingsViewController : SPKSettingsViewController
@end

@implementation SPKMessagesSettingsViewController
- (instancetype)init {
    return [super initWithTitle:@"Messages" sections:SPKMessagesSettingsSections() reduceMargin:NO];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self replaceSections:SPKMessagesSettingsSections()];
}

- (void)switchChanged:(UISwitch *)sender {
    SPKSetting *row = [self settingForSender:sender];
    [super switchChanged:sender];
    if ([row.defaultsKey isEqualToString:@"msgs_manual_seen"] ||
        [row.defaultsKey isEqualToString:@"msgs_manual_visual_seen"]) {
        [self replaceSections:SPKMessagesSettingsSections()];
    }
}
@end

static NSArray *SPKMessagesSettingsSections(void) {
    BOOL manualSeen = [SPKUtils getBoolPref:@"msgs_manual_seen"];
    SPKSetting *manualSeenList = [SPKSetting navigationCellWithTitle:SPKDirectManualSeenListTitle(manualSeen)
                                                            subtitle:nil
                                                                icon:SPKSettingsIcon(@"users")
                                                      viewController:SPKDirectManualSeenListViewController()];
    manualSeenList.userInfo = @{@"accessoryText" : [NSString stringWithFormat:@"%lu", (unsigned long)SPKDirectManualSeenThreadCount(manualSeen)]};
manualSeenList.hiddenProvider = ^BOOL {
    // R5: the chat list only applies while manual seen is on.
    return ![SPKUtils getBoolPref:@"msgs_manual_seen"];
};
    manualSeenList.helpText = @"Excluded chats keep Instagram's normal read receipts; in Included mode only the listed chats are held. Also manageable from the eye button or a long-press in the inbox.";

    // ---- Action Button -------------------------------------------------

    SPKSetting *masterActionButton = [SPKSetting switchCellWithTitle:@"Show action button"
                                                                icon:SPKSettingsIcon(@"action")
                                                         defaultsKey:kSPKMessagesActionButtonEnabledKey];
    // Same wording as the Feed master toggle — the six action-button pages share
    // one gesture template, so the sheets must read identically everywhere.
    masterActionButton.helpText = @"Tap runs the default action. Long-press opens the full action menu.";

    // Extends the action button to the full-screen viewer for permanent chat media
    // (camera-roll photos/videos, chat-menu media), replacing IG's native Save.
    // Only meaningful while the master action button toggle is on.
    SPKSetting *chatMediaActionButton = [SPKSetting switchCellWithTitle:@"Also show on chat media"
                                                                  icon:SPKSettingsIcon(@"photo")
                                                           defaultsKey:kSPKMessagesActionButtonChatMediaKey];
    chatMediaActionButton.enabledProvider = ^BOOL {
        return [SPKUtils getBoolPref:kSPKMessagesActionButtonEnabledKey];
    };
    chatMediaActionButton.helpText = @"Also covers camera-roll photos and videos opened full screen in a chat, where it replaces Instagram's Save button.";

    // ---- Messaging -----------------------------------------------------

    SPKSetting *unlockPreview = [SPKSetting switchCellWithTitle:@"Preview without being seen"
                                                           icon:SPKSettingsIcon(@"story")
                                                    defaultsKey:@"msgs_unlock_preview"];
    unlockPreview.searchKeywords = @"unlock preview";
    unlockPreview.helpText = @"The chat long-press menu shows the real messages without marking them seen.";

    SPKSetting *manualSeenSwitch = [SPKSetting switchCellWithTitle:@"Manually mark chats seen"
                                                              icon:SPKSettingsIcon(@"eye")
                                                       defaultsKey:@"msgs_manual_seen"];
manualSeenSwitch.reloadsTableOnSwitchChange = YES;
    manualSeenSwitch.helpText = @"Chats stop sending read receipts until you tap the eye button. The list below picks which chats are excluded or included.";

    // Auto-seen triggers only act while manual seen is on. Keep their stored value
    // but lock the cells when manual seen is off.
    // Convention v1.3 gate: the four auto-seen triggers, one row. Their shared
    // guard moves onto the gate itself — the family greys out together when
    // Manually Mark Seen is off.
    SPKSetting *markSeenGate = ({
        SPKSetting *g = SPKToggleMenuRowSetting(@"Mark seen on…", @"eye", @[
            [SPKToggleMenuItem itemWithTitle:@"Message send"
                                    iconName:@"messages"
                                 defaultsKey:@"msgs_seen_on_send"],
            [SPKToggleMenuItem itemWithTitle:@"Message reply"
                                    iconName:@"reply"
                                 defaultsKey:@"msgs_seen_on_reply"],
            [SPKToggleMenuItem itemWithTitle:@"Reaction"
                                    iconName:@"reactions"
                                 defaultsKey:@"msgs_seen_on_reaction"],
            [SPKToggleMenuItem itemWithTitle:@"Typing"
                                    iconName:@"keyboard"
                                 defaultsKey:@"msgs_seen_on_typing"],
        ]);
        g.hiddenProvider = ^BOOL {
            return ![SPKUtils getBoolPref:@"msgs_manual_seen"];
        };
        g.searchKeywords = @"mark seen send reply reaction typing auto";
        g;
    });

    // Chooses where the manual-seen eye button lives: the top nav bar, or a
    // draggable bubble above the composer. Only meaningful while manual seen is on.
    // Up/Down arrows mirror the placement on both the menu items and the cell.
    SPKSetting *seenButtonPosition = SPKSettingApplySelectedMenuIcon([SPKSetting menuCellWithTitle:@"Seen button position"
                                                                                              icon:SPKSettingsIcon(@"pin")
                                                                                              menu:SPKSeenButtonPositionMenu()],
                                                                     SPKSettingsIcon(@"arrow_up"));
    seenButtonPosition.hiddenProvider = ^BOOL {
        return ![SPKUtils getBoolPref:@"msgs_manual_seen"];
    };
    seenButtonPosition.helpText = @"The eye button lives in the top bar, or as a draggable bubble above the composer — scroll to snap the bubble back.";

    // ---- Deleted Messages ----------------------------------------------

    SPKSetting *keepDeleted = [SPKSetting switchCellWithTitle:@"Keep deleted messages"
                                                         icon:SPKSettingsIcon(@"undo_circle")
                                                  defaultsKey:@"msgs_keep_deleted"];
    keepDeleted.reloadsTableOnSwitchChange = YES;
    keepDeleted.helpText = @"Unsent messages stay in the chat with an undo marker until the inbox reloads.";


    // Counted once per page appearance (the sections are rebuilt in
    // viewWillAppear), like the manual-seen thread count above — never from an
    // accessoryTextProvider, which would re-read the log JSON on every cell pass.
    NSString *ownerPK = SPKAccountManager.currentAccountPK;
    NSUInteger deletedLogCount = ownerPK.length > 0 ? [SPKDeletedMessagesStorage allMessagesForOwnerPK:ownerPK].count : 0;
    SPKSetting *viewDeletedLog = [SPKSetting navigationCellWithTitle:@"Saved messages"
                                                            subtitle:nil
                                                                icon:SPKSettingsIcon(@"trash")
                                                      viewController:[SPKDeletedMessagesViewController new]];
    viewDeletedLog.hiddenProvider = ^BOOL {
        return ![SPKUtils getBoolPref:@"msgs_keep_deleted"];
    };
    viewDeletedLog.userInfo = @{@"accessoryText" : [NSString stringWithFormat:@"%lu", (unsigned long)deletedLogCount]};

    // ---- Interface -----------------------------------------------------

    // Tri-state control for reformatting the chat-header last-active presence
    // label: Off / Smart / Date & Time.
    SPKSetting *hideCreateGroup = [SPKSetting switchCellWithTitle:@"Hide create group button"
                                                             icon:SPKSettingsIcon(@"group")
                                                      defaultsKey:@"general_hide_create_group"];
    hideCreateGroup.searchKeywords = @"send share sheet";

    SPKSetting *lastActiveFormat = SPKSettingApplySelectedMenuIcon([SPKSetting menuCellWithTitle:@"Last active"
                                                                                            icon:SPKSettingsIcon(@"clock")
                                                                                            menu:SPKLastActiveFormatMenu()],
                                                                   SPKSettingsIcon(@"clock"));
    lastActiveFormat.searchKeywords = @"presence status smart date time exact";

    // Lexicon rename ("No …" → "Hide …"); old phrasing kept searchable.

    // ---- Visual Messages -----------------------------------------------

    // Advancing after a manual seen only applies while visual manual seen is on.
    SPKSetting *advanceVisual = [SPKSetting switchCellWithTitle:@"Advance after manual seen" icon:SPKSettingsIcon(@"autoscroll") defaultsKey:@"msgs_advance_visual_on_seen"];
advanceVisual.helpText = @"Moves to the next photo once you mark the current one as seen yourself.";
    advanceVisual.hiddenProvider = ^BOOL {
        return ![SPKUtils getBoolPref:@"msgs_manual_visual_seen"];
    };

    // Lexicon rename ("Stop …" → "Disable …"); old phrasing kept searchable.
    SPKSetting *disableAutoAdvance = [SPKSetting switchCellWithTitle:@"Stay on current message"
                                                                icon:SPKSettingsIcon(@"autoplay_off")
                                                         defaultsKey:@"msgs_stop_visual_auto_advance"];
disableAutoAdvance.helpText = @"Keeps a vanishing photo open instead of jumping to the next one on its own.";
    disableAutoAdvance.searchKeywords = @"stop next replay end";

    SPKSetting *disableViewOnce = [SPKSetting switchCellWithTitle:@"Disable view-once limitations"
                                                             icon:SPKSettingsIcon(@"view_once")
                                                      defaultsKey:@"msgs_disable_view_once"];
    disableViewOnce.searchKeywords = @"replay view twice limit";

    // ---- Audio & Media -------------------------------------------------
    // The composer entry points used to live in the section footers; they stay
    // findable through the search keywords below.

    SPKSetting *downloadVoice = SPKAudioGatedSwitch(@"Download voice messages", SPKSettingsIcon(@"audio_download"), @"msgs_download_audio_messages");
    // Its master lives on another page, so the row names where to find it.
    downloadVoice.helpText = @"Shown while Audio Downloads is on in the Downloads page.";
    downloadVoice.searchKeywords = @"voice message audio save";

    SPKSetting *uploadAudio = [SPKSetting switchCellWithTitle:@"Upload audio"
                                                         icon:SPKSettingsIcon(@"audio_upload")
                                                  defaultsKey:@"msgs_upload_audio_messages"];
uploadAudio.helpText = @"Send an audio file from your device as a voice message.";
    uploadAudio.searchKeywords = @"composer plus menu voice video send";

    SPKSetting *trimAudio = [SPKSetting switchCellWithTitle:@"Trim before sending"
                                                       icon:SPKSettingsIcon(@"trim")
                                                defaultsKey:@"msgs_audio_upload_trim"];
trimAudio.helpText = @"Adds a Trim & Send option so you can cut the file before it goes out.";
    trimAudio.searchKeywords = @"cut editor length";

    SPKSetting *uploadGalleryPhoto = [SPKSetting switchCellWithTitle:@"Send photo from gallery"
                                                                icon:SPKSettingsIcon(@"photo")
                                                         defaultsKey:@"msgs_upload_gallery_media"];
    uploadGalleryPhoto.searchKeywords = @"composer plus menu picture send upload photo gallery";

    // ---- Notes ---------------------------------------------------------

    SPKSetting *downloadNotesAudio = SPKAudioGatedSwitch(@"Download Notes audio", SPKSettingsIcon(@"audio"), @"msgs_download_notes_audio");
    downloadNotesAudio.helpText = @"Long-press a note in the tray — the option appears when the note has audio.";

    SPKSetting *copyNoteText = [SPKSetting switchCellWithTitle:@"Copy note text"
                                                          icon:SPKSettingsIcon(@"copy")
                                                   defaultsKey:@"msgs_copy_note_text"];
    copyNoteText.helpText = @"Long-press a note in the tray — the option appears when the note has text.";

    return @[
        // Everything about the chat screen itself. Was split across "Messaging"
        // and a section literally called "Interface".
        // One subject: what disappears, and what is kept of it. The master switch
        // sits with the behaviours it follows from, and the two rows under it
        // appear only while it is on, so their context is the row above them.
        SPKTopicSection(@"Disappearing & deleted", @[
            ({
                // One switch for both surfaces: view-once media and vanish mode
                // keep their own keys, written together so they never diverge.
                SPKSetting *sw = [SPKSetting switchCellWithTitle:@"Disable screenshot detection"
                                                            icon:SPKSettingsIcon(@"warning")
                                                     defaultsKey:@""];
                sw.switchValueProvider = ^BOOL {
                    return [SPKUtils getBoolPref:@"msgs_disable_screenshot_detection"]
                        && [SPKUtils getBoolPref:@"msgs_hide_vanish_screenshot"];
                };
                sw.switchChangeHandler = ^(BOOL isOn) {
                    SPKPreferenceSetObject(@(isOn), @"msgs_disable_screenshot_detection");
                    SPKPreferenceSetObject(@(isOn), @"msgs_hide_vanish_screenshot");
                };
                sw.helpText = @"Stops the screenshot alert on view-once media and in vanish mode.";
                sw.searchKeywords = @"screenshot detection vanish view once media";
                sw;
            }),
            disableAutoAdvance,
            disableViewOnce,
            ({
                SPKSetting *sw = [SPKSetting switchCellWithTitle:@"Disable vanish swipe-up"
                                                            icon:SPKSettingsIcon(@"arrow_up")
                                                     defaultsKey:@"msgs_disable_vanish_swipe_up"];
                sw.searchKeywords = @"gesture vanish mode";
                sw;
            }),
            keepDeleted,
            ({
                SPKSetting *g = SPKToggleMenuRowSetting(@"What to save", @"notes", @[
                    [SPKToggleMenuItem itemWithTitle:@"Log deleted messages"
                                            iconName:@"logs"
                                         defaultsKey:@"msgs_deleted_log"],
                    [SPKToggleMenuItem itemWithTitle:@"Log removed reactions"
                                            iconName:@"reactions"
                                         defaultsKey:@"msgs_deleted_log_reactions"],
                    [SPKToggleMenuItem itemWithTitle:@"Skip excluded chats"
                                            iconName:@"eye"
                                         defaultsKey:@"msgs_deleted_log_respect_seen_list"],
                ]);
                g.helpText = @"Saves each message before it disappears, including view-once media, until you clear the log. "
                             @"Skip excluded chats leaves the chats on your seen list out of the log and its notifications.";
                g.searchKeywords = @"log deleted removed reactions seen chat list respect seen chat list";
                // R5: hidden while Keep Deleted Messages is off.
                g.hiddenProvider = ^BOOL {
                    return ![SPKUtils getBoolPref:@"msgs_keep_deleted"];
                };
                g;
            }),
            viewDeletedLog],
                        nil),
        // Ordered so each master switch is followed by what it controls:
        // conversations first, then photos and videos.
        SPKTopicSection(@"Seen receipts", @[
            unlockPreview,
            manualSeenSwitch,
            markSeenGate,
            seenButtonPosition,
            manualSeenList,
            ({
                SPKSetting *row = [SPKSetting switchCellWithTitle:@"Manually mark media seen"
                                           icon:SPKSettingsIcon(@"eye")
                                    defaultsKey:@"msgs_manual_visual_seen"];
                row.reloadsTableOnSwitchChange = YES;  // R5: reveals Advance After Manual Seen in place.
                row.helpText = @"Photos and videos stop sending read receipts until the eye is tapped. Turning this on reveals Advance After Manual Seen.";
                row;
            }),
            advanceVisual,
        ],
                        nil),
        SPKTopicSection(@"Chat screen", @[
            ({
                // Lives with the inbox it changes. Kept tied to Disable Instants
                // Creation: hiding the entry without disabling capture would
                // leave a shutter with no way back.
                SPKSetting *hideInstants = [SPKSetting switchCellWithTitle:@"Hide Instants button"
                                                                     icon:SPKSettingsIcon(@"instants")
                                                              defaultsKey:@"instants_hide_inbox_entry"];
                hideInstants.helpText = @"Removes the + from the inbox. Requires Disable Instants Creation, on the Camera page.";
                hideInstants.searchKeywords = @"instants inbox plus button";
                hideInstants.hiddenProvider = ^BOOL {
                    return ![SPKUtils getBoolPref:@"instants_disable_creation"];
                };
                hideInstants;
            }),
            hideCreateGroup,
            // Six hides of the same screen, one gate — the verb lives on the
            // row; Typing Status keeps its noun (it is not a button).
            ({
                SPKSetting *g = SPKToggleMenuRowSetting(@"Hide chat elements", @"eye_off", @[
                    [SPKToggleMenuItem itemWithTitle:@"Typing status"
                                            iconName:@"keyboard"
                                         defaultsKey:@"msgs_disable_typing"],
                    [SPKToggleMenuItem itemWithTitle:@"Reels blend"
                                            iconName:@"blend"
                                         defaultsKey:@"msgs_hide_reels_blend"],
                    [SPKToggleMenuItem itemWithTitle:@"Audio call"
                                            iconName:@"call"
                                         defaultsKey:@"msgs_hide_audio_call_btn"],
                    [SPKToggleMenuItem itemWithTitle:@"Video call"
                                            iconName:@"video"
                                         defaultsKey:@"msgs_hide_video_call_btn"],
                    [SPKToggleMenuItem itemWithTitle:@"Flag button"
                                            iconName:@"flag"
                                         defaultsKey:@"msgs_hide_flag_btn"],
                    [SPKToggleMenuItem itemWithTitle:@"Suggested chats"
                                            iconName:@"question"
                                         defaultsKey:@"msgs_hide_suggested_chats"],
                ]);
                g.searchKeywords = @"hide typing status reels blend audio video call flag suggested chats button no suggestions inbox flag";
                g;
            }),
            lastActiveFormat],
                        nil),
// Visual Messages ∪ Vanish Mode: same territory (messages that
        // disappear) — and it resolves the duplicated "Disable Screenshot
        // Detection" row: one gate, two context-named items.
SPKTopicSection(@"Notes", @[
            [SPKSetting switchCellWithTitle:@"Hide Notes tray"
                                       icon:SPKSettingsIcon(@"notes")
                                defaultsKey:@"msgs_hide_notes_tray"],
            [SPKSetting switchCellWithTitle:@"Hide friends map"
                                       icon:SPKSettingsIcon(@"map")
                                defaultsKey:@"msgs_hide_friends_map"],
            downloadNotesAudio,
            copyNoteText,
        ],
                        nil),
        SPKTopicSection(@"Audio & media", @[
            downloadVoice,
            uploadAudio,
            trimAudio,
            uploadGalleryPhoto,
        ],
                        nil),
        // Convention v1.2: the "Confirmations" gate row closes every page — one
        // tap opens the multi-toggle menu (icon left, checkmark right, stays
        // open while toggling). Items keep the old switches' keys and icons.
        SPKTopicSection(@"", @[
            SPKActionButtonRowSetting(kSPKMessagesActionButtonEnabledKey,
                                      nil,
                                      @[
                masterActionButton,
                chatMediaActionButton,
                SPKActionButtonDefaultActionNavigationSetting(SPKActionButtonSourceDirect),
                SPKActionButtonConfigurationNavigationSetting(SPKActionButtonSourceDirect, @"Messages", SPKActionButtonSupportedActionsForSource(SPKActionButtonSourceDirect), SPKActionButtonDefaultSectionsForSource(SPKActionButtonSourceDirect))
        
                                      ]),
            ({
                SPKSetting *g = SPKToggleMenuRowSetting(@"Confirmations", @"circle_check", @[
                [SPKToggleMenuItem itemWithTitle:@"Create group"
                                        iconName:@"group"
                                     defaultsKey:@"general_confirm_create_group"],
                // Was a row in "Deleted Messages" — it is a confirmation like
                // the others, and it belongs where the user looks for them.
                [SPKToggleMenuItem itemWithTitle:@"Inbox refresh"
                                        iconName:@"arrow_cw"
                                     defaultsKey:@"msgs_confirm_refresh"],
                [SPKToggleMenuItem itemWithTitle:@"Audio call"
                                        iconName:@"call"
                                     defaultsKey:kSPKMessagesAudioCallConfirmKey],
                [SPKToggleMenuItem itemWithTitle:@"Video call"
                                        iconName:@"video"
                                     defaultsKey:kSPKMessagesVideoCallConfirmKey],
                [SPKToggleMenuItem itemWithTitle:@"Double tap"
                                        iconName:@"heart"
                                     defaultsKey:@"msgs_confirm_double_tap"],
                [SPKToggleMenuItem itemWithTitle:@"Reactions"
                                        iconName:@"reactions"
                                     defaultsKey:@"msgs_confirm_reaction"],
                [SPKToggleMenuItem itemWithTitle:@"Voice messages"
                                        iconName:@"voice"
                                     defaultsKey:@"msgs_confirm_voice_msg"],
                [SPKToggleMenuItem itemWithTitle:@"Follow requests"
                                        iconName:@"user_request"
                                     defaultsKey:@"msgs_confirm_follow_request"],
                [SPKToggleMenuItem itemWithTitle:@"Vanish mode"
                                        iconName:@"vanish"
                                     defaultsKey:@"msgs_confirm_vanish_mode"],
                [SPKToggleMenuItem itemWithTitle:@"Theme change"
                                        iconName:@"palette"
                                     defaultsKey:@"msgs_confirm_theme_change"],
            ]);
                g;
            })
        ],
                        nil)
    ];
}

@implementation SPKMessagesSettingsProvider


+ (SPKSetting *)rootSetting {
    SPKSetting *setting = [SPKSetting navigationCellWithTitle:@"Messages"
                                                     subtitle:nil
                                                         icon:SPKSettingsIcon(@"messages")
                                               viewController:[[SPKMessagesSettingsViewController alloc] init]];
    setting.searchSectionsProvider = ^NSArray * {
        return SPKMessagesSettingsSections();
    };
    return SPKSettingApplyIconTint(setting, [SPKUtils SPKColor_InstagramPrimaryText]);
}

@end
