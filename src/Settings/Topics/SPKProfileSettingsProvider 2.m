#import "SPKProfileSettingsProvider.h"

#import "../../AssetUtils.h"
#import "../../Features/Profile/FollowIndicator.h"
#import "../../Shared/ActionButton/SPKActionButtonConfiguration.h"
#import "../../Utils.h"
#import "../SPKToggleMenu.h"
#import "../SPKTopicSettingsSupport.h"

static NSString *const kSPKProfileActionNone = @"none";
static NSString *const kSPKProfileActionCopyInfo = @"copy_info";
static NSString *const kSPKProfileActionViewPicture = @"view_picture";
static NSString *const kSPKProfileActionSharePicture = @"share_picture";
static NSString *const kSPKProfileActionSavePictureToGallery = @"save_picture_gallery";
static NSString *const kSPKProfileActionOpenSettings = @"profile_settings";
static NSString *const kSPKProfileDefaultCopyInfoKey = @"profile_action_btn_default_copy_info_action";
static NSString *const kSPKProfileCopyInfoID = @"id";
static NSString *const kSPKProfileCopyInfoUsername = @"username";
static NSString *const kSPKProfileCopyInfoName = @"name";
static NSString *const kSPKProfileCopyInfoBio = @"bio";
static NSString *const kSPKProfileCopyInfoLink = @"link";
static CGFloat const kSPKProfileSettingsMenuIconPointSize = 22.0;

static UIImage *SPKProfileSettingsMenuIcon(NSString *resourceName) {
    return [SPKAssetUtils instagramIconNamed:resourceName pointSize:kSPKProfileSettingsMenuIconPointSize];
}

static UICommand *SPKProfileActionDefaultCommand(NSString *title, NSString *resourceName, NSString *value) {
    UIImage *image = SPKProfileSettingsMenuIcon(resourceName);
    return [UICommand commandWithTitle:title
                                 image:image
                                action:@selector(menuChanged:)
                          propertyList:@{
                              @"defaultsKey" : @"profile_action_btn_default_action",
                              @"value" : value,
                              @"iconName" : resourceName
                          }];
}

static UIMenu *SPKProfileActionDefaultMenu(void) {
    return [UIMenu menuWithChildren:@[
        SPKProfileActionDefaultCommand(@"Open menu", @"action", kSPKProfileActionNone),
        SPKProfileActionDefaultCommand(@"Copy Info", @"copy", kSPKProfileActionCopyInfo),
        SPKProfileActionDefaultCommand(@"View Picture", @"photo", kSPKProfileActionViewPicture),
        SPKProfileActionDefaultCommand(@"Share Picture", @"share", kSPKProfileActionSharePicture),
        SPKProfileActionDefaultCommand(@"Save to Gallery", @"sparkle_gallery", kSPKProfileActionSavePictureToGallery),
        SPKProfileActionDefaultCommand(@"Profile Settings", @"settings", kSPKProfileActionOpenSettings)
    ]];
}

static UICommand *SPKProfileDefaultCopyInfoCommand(NSString *title, NSString *resourceName, NSString *value) {
    UIImage *image = SPKProfileSettingsMenuIcon(resourceName);
    return [UICommand commandWithTitle:title
                                 image:image
                                action:@selector(menuChanged:)
                          propertyList:@{
                              @"defaultsKey" : kSPKProfileDefaultCopyInfoKey,
                              @"value" : value,
                              @"iconName" : resourceName
                          }];
}

static UIMenu *SPKProfileDefaultCopyInfoMenu(void) {
    return [UIMenu menuWithChildren:@[
        SPKProfileDefaultCopyInfoCommand(@"ID", @"key", kSPKProfileCopyInfoID),
        SPKProfileDefaultCopyInfoCommand(@"Username", @"username", kSPKProfileCopyInfoUsername),
        SPKProfileDefaultCopyInfoCommand(@"Name", @"text", kSPKProfileCopyInfoName),
        SPKProfileDefaultCopyInfoCommand(@"Bio", @"caption", kSPKProfileCopyInfoBio),
        SPKProfileDefaultCopyInfoCommand(@"Profile Link", @"link", kSPKProfileCopyInfoLink)
    ]];
}

static NSString *const kSPKFollowIndicatorModeKey = @"profile_follow_indicator_mode";
static NSString *const kSPKFollowIndicatorModeOff = @"off";
static NSString *const kSPKFollowIndicatorModeText = @"text";
static NSString *const kSPKFollowIndicatorModeIcon = @"icon";
static NSString *const kSPKFollowIndicatorModeIconText = @"icontext";

// Mirrors FollowIndicator.x: no default is registered for the mode key, so an
// empty value means "use the legacy on/off bool" for pre-mode-menu users.
static NSString *SPKFollowIndicatorEffectiveMode(void) {
    NSString *mode = [SPKUtils getStringPref:kSPKFollowIndicatorModeKey];
    if (mode.length > 0)
        return mode;
    return [SPKUtils getBoolPref:@"profile_follow_indicator"] ? kSPKFollowIndicatorModeText
                                                              : kSPKFollowIndicatorModeOff;
}

static NSString *const kSPKFollowIndicatorColorfulKey = @"profile_follow_indicator_colorful";

// Mirrors FollowIndicator.x: no default is registered, so a never-set value
// falls back to the legacy bool (pre-menu enabled users keep colored).
static BOOL SPKFollowIndicatorColorfulEnabled(void) {
    id value = SPKPreferenceObjectForKey(kSPKFollowIndicatorColorfulKey);
    if (value == nil)
        return [SPKUtils getBoolPref:@"profile_follow_indicator"];
    return [value boolValue];
}

// No per-item icons: the menu is a plain title list. The cell keeps a static
// leading icon instead of reflecting the selection.
static UICommand *SPKFollowIndicatorModeCommand(NSString *title, NSString *value, NSString *iconName) {
    return [UICommand commandWithTitle:title
                                 image:nil
                                action:@selector(menuChanged:)
                          propertyList:@{
                              @"defaultsKey" : kSPKFollowIndicatorModeKey,
                              @"value" : value,
                              @"iconName" : iconName
                          }];
}

static UIMenu *SPKFollowIndicatorModeMenu(void) {
    return [UIMenu menuWithChildren:@[
        SPKFollowIndicatorModeCommand(@"Off", kSPKFollowIndicatorModeOff, @"circle_off"),
        SPKFollowIndicatorModeCommand(@"Icon", kSPKFollowIndicatorModeIcon, @"user_check"),
        SPKFollowIndicatorModeCommand(@"Text", kSPKFollowIndicatorModeText, @"text"),
        SPKFollowIndicatorModeCommand(@"Icon & Text", kSPKFollowIndicatorModeIconText, @"users")
    ]];
}

@implementation SPKProfileSettingsProvider

+ (SPKSetting *)rootSetting {
    return SPKTopicNavigationSetting(@"Profile", @"user_circle", 24.0, @[
        // "Profile Screen" names what these rows change; a header repeating the
        // page name would say nothing — and without a header there is no ⓘ.
        SPKTopicSection(@"Profile screen", @[
            ({
                SPKSetting *fullRes = [SPKSetting switchCellWithTitle:@"Full-resolution photo"
                                                                 icon:SPKSettingsIcon(@"hd")
                                                          defaultsKey:@"profile_full_res_photo"
                                                      requiresRestart:YES];
                fullRes.helpText = @"Loads the original profile picture in the header instead of the small square Instagram serves.";
                fullRes.searchKeywords = @"profile picture resolution hd avatar";
                fullRes;
            }),
            ({
                SPKSetting *row = [SPKSetting switchCellWithTitle:@"Expand photo"
                                       icon:SPKSettingsIcon(@"expand")
                                defaultsKey:@"profile_photo_zoom"];
                row.helpText = @"Long-press a profile picture to open it full screen.";
                row;
            }),
            ({
                SPKSetting *row = [SPKSetting switchCellWithTitle:@"Hide Notes bubble"
                                       icon:SPKSettingsIcon(@"notes")
                                defaultsKey:@"profile_hide_notes_bubble"];
                row.helpText = @"Removes the note bubble above your own profile picture.";
                row;
            }),
            ({
                SPKSetting *row = [SPKSetting switchCellWithTitle:@"Hide Threads button"
                                       icon:SPKSettingsIcon(@"threads")
                                defaultsKey:@"profile_hide_threads_btn"];
                row.helpText = @"Removes the Threads badge from the profile header.";
                row;
            }),
            ({
                SPKSetting *mode = [SPKSetting menuCellWithTitle:@"Following indicator"
                                                            icon:SPKSettingsIcon(@"user_check")
                                                            menu:SPKFollowIndicatorModeMenu()];
    mode.helpText = @"Marks profiles that already follow you, as an icon, a label, or both.";
                mode.accessoryTextProvider = ^NSString * {
                    NSString *value = SPKFollowIndicatorEffectiveMode();
                    if ([value isEqualToString:kSPKFollowIndicatorModeText])
                        return @"Text";
                    if ([value isEqualToString:kSPKFollowIndicatorModeIcon])
                        return @"Icon";
                    if ([value isEqualToString:kSPKFollowIndicatorModeIconText])
                        return @"Icon + Text";
                    return @"Off";
                };
                mode;
            }),
            ({
                // Off (default) = Instagram's native gray for both states, so it
                // doesn't stand out as modded. On = the colored green/red. Uses a
                // custom value provider so the legacy fallback (pre-menu users who
                // had the indicator on keep colored) is reflected accurately.
                SPKSetting *colorful = [SPKSetting switchCellWithTitle:@"Colorful indicator"
                                                                  icon:SPKSettingsIcon(@"palette")
                                                           defaultsKey:kSPKFollowIndicatorColorfulKey];
    colorful.helpText = @"Tint that mark instead of showing it in grey.";
                colorful.switchValueProvider = ^BOOL {
                    return SPKFollowIndicatorColorfulEnabled();
                };
                colorful.switchChangeHandler = ^(BOOL isOn) {
                    SPKPreferenceSetObject(@(isOn), kSPKFollowIndicatorColorfulKey);
                    [[NSNotificationCenter defaultCenter] postNotificationName:SPKFollowIndicatorDidChangeNotification object:nil];
                };
                colorful.hiddenProvider = ^BOOL {
                    return [SPKFollowIndicatorEffectiveMode() isEqualToString:kSPKFollowIndicatorModeOff];
                };
                colorful;
            })],
                        @"1. Long press a profile picture to open it expanded.\n"
                        @"2. Following Indicator shows whether a profile follows you back, under their stats. Text or Icon; it's Instagram's native gray unless you turn on Colorful Indicator for green/red."),
        // Convention v1.2 gate row — see SPKToggleMenu.h.
        SPKTopicSection(@"", @[
            SPKActionButtonRowSetting(@"profile_action_btn",
                                      @"Choose what tapping the action button does. Copy Info Default controls what gets copied when Default Tap Action is Copy Info.",
                                      @[
                [SPKSetting switchCellWithTitle:@"Show action button"
                                           icon:SPKSettingsIcon(@"action")
                                    defaultsKey:@"profile_action_btn"],
                SPKActionButtonDefaultActionNavigationSetting(SPKActionButtonSourceProfile),
                SPKActionButtonConfigurationNavigationSetting(SPKActionButtonSourceProfile, @"Profile", SPKActionButtonSupportedActionsForSource(SPKActionButtonSourceProfile), SPKActionButtonDefaultSectionsForSource(SPKActionButtonSourceProfile)),
                SPKSettingApplySelectedMenuIcon([SPKSetting menuCellWithTitle:@"What copy info copies" icon:SPKSettingsIcon(@"copy") menu:SPKProfileDefaultCopyInfoMenu()], SPKSettingsIcon(@"copy"))
        
                                      ]),
            SPKToggleMenuRowSetting(@"Confirmations", @"circle_check", @[
                [SPKToggleMenuItem itemWithTitle:@"Follow"
                                        iconName:@"user_follow"
                                     defaultsKey:@"profile_confirm_follow"],
                [SPKToggleMenuItem itemWithTitle:@"Unfollow"
                                        iconName:@"user_unfollow"
                                     defaultsKey:@"profile_confirm_unfollow"],
            ])
        ],
                        nil)
    ]);
}

@end
