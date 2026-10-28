#import "SPKInstantsSettingsProvider.h"
#include <UIKit/UIKit.h>

#import "../../Shared/ActionButton/ActionButtonCore.h"
#import "../../Shared/ActionButton/SPKActionButtonConfiguration.h"
#import "../../Utils.h"
#import "../SPKPreferenceAvailability.h"
#import "../SPKSettingsViewController.h"
#import "../SPKToggleMenu.h"
#import "../SPKTopicSettingsSupport.h"

static NSString *const kSPKInstantsActionButtonEnabledKey = @"instants_action_btn";

static NSArray *SPKInstantsSettingsSections(void);

@interface SPKInstantsSettingsViewController : SPKSettingsViewController
@end

@implementation SPKInstantsSettingsViewController
- (instancetype)init {
    return [super initWithTitle:@"Camera" sections:SPKInstantsSettingsSections() reduceMargin:NO];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self replaceSections:SPKInstantsSettingsSections()];
}
@end

static NSArray *SPKInstantsSettingsSections(void) {
    return @[
        // "Privacy" held a single row; screenshots are part of what the camera
        // does, so the two sections become one.
        SPKTopicSection(@"Instants", @[
            ({
                SPKSetting *row = [SPKSetting switchCellWithTitle:@"Disable screenshot detection"
                                       icon:SPKSettingsIcon(@"warning")
                                defaultsKey:@"instants_allow_screenshot"];
                row.helpText = @"Screenshot an Instant without the sender being told.";
                row;
            }),
            ({
                SPKSetting *s = [SPKSetting switchCellWithTitle:@"Disable Instants creation" icon:SPKSettingsIcon(@"instants") defaultsKey:@"instants_disable_creation"];
    s.helpText = @"Blocks capture in the Instants camera.";
                s.reloadsTableOnSwitchChange = YES;
    s.searchKeywords = @"disable camera control";
                s.switchChangeHandler = ^(BOOL isOn) {
                    SPKPreferenceSetObject(@(isOn), @"instants_disable_creation");
                    [[NSNotificationCenter defaultCenter] postNotificationName:@"SPKQuickSnapCreationPrefChangedNotification" object:nil];
                };
                s;
            })
        ],
                        nil),
        // The capture screen itself: what happens once you are in the camera.
        SPKTopicSection(@"Capture screen", @[
            ({
                SPKSetting *row = [SPKSetting switchCellWithTitle:@"Skip camera after sending"
                                       icon:SPKSettingsIcon(@"photo")
                                defaultsKey:@"instants_skip_camera_after_viewing"];
                row.helpText = @"Return to the conversation instead of staying on the camera.";
                row;
            }),
            // Same glyph the button itself wears: the global "Open Menu Icon" choice.
            // Merged in from its own untitled one-row section — it is a camera
            // setting like the three above.
            ({
                SPKSetting *row = [SPKSetting switchCellWithTitle:@"Camera view button"
                                       icon:SPKSettingsIcon(SPKActionButtonOpenMenuIconName())
                                defaultsKey:@"instants_camera_btn"];
                row.helpText = @"Adds the Sparkle button to the camera, for the actions you picked in Action Button.";
                row;
            }),
            ({
                BOOL cameraControlAvailable = SPKPrefIsAvailable(@"instants_disable_camera_control");
                SPKSetting *s = [SPKSetting switchCellWithTitle:@"Ignore camera button"
                                                       subtitle:cameraControlAvailable ? @"" : @"Requires an iPhone with Camera Control"
                                                           icon:SPKSettingsSystemIcon(@"button.vertical.right.press", SPKSettingsCellIconPointSize, UIImageSymbolWeightSemibold)
                                                    defaultsKey:@"instants_disable_camera_control"];
                s.helpText = @"Stops the iPhone's Camera Control from opening the Instants camera.";
                s;
            })
        ],
                        nil),
        // Convention v1.2 gate row — see SPKToggleMenu.h. "Instants ›
        // Confirmations › Capture": both dropped words sit right above.
        // Capture keeps its disabled state (feature suspended).
        SPKTopicSection(@"", @[
            SPKActionButtonRowSetting(kSPKInstantsActionButtonEnabledKey,
                                      @"Choose what tapping the action button does. Long press opens the full menu.",
                                      @[
                [SPKSetting switchCellWithTitle:@"Show action button"
                                           icon:SPKSettingsIcon(@"action")
                                    defaultsKey:kSPKInstantsActionButtonEnabledKey],
                SPKActionButtonDefaultActionNavigationSetting(SPKActionButtonSourceInstants),
                SPKActionButtonConfigurationNavigationSetting(SPKActionButtonSourceInstants, @"Instants", SPKActionButtonSupportedActionsForSource(SPKActionButtonSourceInstants), SPKActionButtonDefaultSectionsForSource(SPKActionButtonSourceInstants))
        
                                      ]),
            SPKToggleMenuRowSetting(@"Confirmations", @"circle_check", @[
                [SPKToggleMenuItem itemWithTitle:@"Reaction"
                                        iconName:@"reactions"
                                     defaultsKey:@"instants_confirm_reaction"],
            ])
        ],
                        nil),
    ];
}

@implementation SPKInstantsSettingsProvider

+ (UIViewController *)makeSettingsViewController {
    return [[SPKInstantsSettingsViewController alloc] init];
}

+ (SPKSetting *)rootSetting {
    SPKSetting *setting = [SPKSetting navigationCellWithTitle:@"Camera"
                                                     subtitle:nil
                                                         icon:SPKSettingsIcon(@"instants")
                                               viewController:[[SPKInstantsSettingsViewController alloc] init]];
    setting.searchKeywords = @"instants quick snap camera";
    setting.searchSectionsProvider = ^NSArray * {
        return SPKInstantsSettingsSections();
    };
    return SPKSettingApplyIconTint(setting, [SPKUtils SPKColor_InstagramPrimaryText]);
}

@end
