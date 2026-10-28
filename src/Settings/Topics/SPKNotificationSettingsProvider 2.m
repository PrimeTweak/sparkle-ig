#import "SPKNotificationSettingsProvider.h"
#import "../../Shared/UI/SPKNotificationCenter.h"
#import "../../Utils.h"
#import "../SPKPreferenceAvailability.h"
#import "../SPKPreferences.h"
#import "../SPKTopicSettingsSupport.h"

@implementation SPKNotificationSettingsProvider

// One switch per section.
//
// The screen used to build sixty-five switches from this table, then build them
// a second time for haptics on a twin screen. A section covers every banner of
// its kind, and the haptic master in Appearance covers all of them at once.
+ (NSArray<SPKSetting *> *)spk_sectionRows {
    NSDictionary<NSString *, NSString *> *icons = @{
        @"Action Buttons" : @"action",
        @"Auto-Save" : @"download",
        @"Stories" : @"story",
        @"Messages" : @"messages",
        @"Instants" : @"instants_burst",
        @"Profile" : @"user_circle",
        @"Comments" : @"comment",
        @"Media" : @"photo_gallery",
        @"Gallery" : @"sparkle_gallery",
        @"Settings & Tools" : @"settings",
    };

    NSMutableArray<SPKSetting *> *rows = [NSMutableArray array];
    for (NSDictionary *section in SPKNotificationPreferenceSections()) {
        NSString *title = section[@"title"] ?: @"";
        if (title.length == 0)
            continue;

        NSString *sentenceCased = title.length > 1
            ? [[[title substringToIndex:1] uppercaseString]
                  stringByAppendingString:[[title substringFromIndex:1] lowercaseString]]
            : title;

        SPKSetting *row = [SPKSetting switchCellWithTitle:sentenceCased
                                                 subtitle:@""
                                                     icon:SPKSettingsIcon(icons[title] ?: @"notification")
                                              defaultsKey:SPKPrefNotificationSectionKey(SPKNotificationSectionIdentifier(title))];
        row.userInfo = @{@"defaultValue" : @YES};
        [rows addObject:row];
    }
    return [rows copy];
}

+ (void)spk_showNextNotificationPreview {
    static NSUInteger toneIndex = 0;

    NSArray<NSDictionary *> *configs = @[
        @{
            @"title" : @"Saved to Gallery",
            @"subtitle" : @"Notification preview: success tone.",
            @"iconResource" : @"circle_check_filled",
            @"tone" : @(SPKNotificationToneSuccess)
        },
        @{
            @"title" : @"Something Went Wrong",
            @"subtitle" : @"Notification preview: error tone.",
            @"iconResource" : @"error_filled",
            @"tone" : @(SPKNotificationToneError)
        },
        @{
            @"title" : @"Heads Up",
            @"subtitle" : @"Notification preview: info tone.",
            @"iconResource" : @"info_filled",
            @"tone" : @(SPKNotificationToneInfo)
        }
    ];

    NSDictionary *config = configs[toneIndex % configs.count];
    toneIndex++;

    SPKNotify(kSPKNotificationSettingsClearCache,
              config[@"title"],
              config[@"subtitle"],
              config[@"iconResource"],
              [config[@"tone"] unsignedIntegerValue]);
}

+ (NSArray *)sections {
    NSMutableArray *sections = [NSMutableArray arrayWithArray:@[
        SPKTopicSection(@"Appearance", @[
            ({
                SPKSetting *row = [SPKSetting switchCellWithTitle:@"Glow effect"
                                   subtitle:@""
                           icon:SPKSettingsIcon(@"aura")
                                defaultsKey:kSPKNotificationPillGlowEnabledKey];
                row;
            }),
            [SPKSetting switchCellWithTitle:@"Liquid Glass"
                                   subtitle:@""
                                       icon:SPKSettingsIcon(@"mirror")
                                defaultsKey:kSPKNotificationPillLiquidGlassEnabledKey],
            // Banner haptics only, beside the other rows that describe the banner.
            // Disable haptics in General sits above it and silences everything.
            [SPKSetting switchCellWithTitle:@"Haptics with banners"
                                   subtitle:@""
                                       icon:SPKSettingsIcon(@"haptics")
                                defaultsKey:kSPKNotificationHapticsEnabledKey],
            [SPKSetting menuCellWithTitle:@"Download progress"
                                 subtitle:nil
                                icon:SPKSettingsIcon(@"download")
                                     menu:SPKNotificationProgressSubtitleStyleMenu()],
            [SPKSetting menuCellWithTitle:@"Banner position"
                                 subtitle:nil
                                icon:SPKSettingsIcon(@"pin")
                                     menu:SPKNotificationPillPositionMenu()],
            [SPKSetting stepperCellWithTitle:@"Duration"
                                    subtitle:@"Dismiss after %@%@"
                            icon:SPKSettingsIcon(@"clock")
                                 defaultsKey:kSPKNotificationPillDurationKey
                                         min:0.5
                                         max:5.0
                                        step:0.25
                                       label:@" seconds"
                               singularLabel:@" second"]
        ],
                        @"Glow effect draws a soft halo so a banner reads against a busy screen. "
                        @"Liquid Glass renders it in the iOS 26 material and needs iOS 26. "
                        @"Haptics with banners covers the banners only \u2014 Disable haptics in "
                        @"General silences every haptic the tweak produces."),
        SPKTopicSection(@"Notifications",
                        [self spk_sectionRows],
                        @"Each switch covers every banner of its kind. Action buttons are the ones a "
                        @"download or a copy raises; Auto-save covers the toasts a running save puts up."),
        SPKTopicSection(@"", @[
            [SPKSetting buttonCellWithTitle:@"Test notification"
                                   subtitle:nil
                                       icon:SPKSettingsIcon(@"notification")
                                     action:^{
                                         [self spk_showNextNotificationPreview];
                                     }],
        ],
                        nil)
    ]];

    return [sections copy];
}

@end
