#import "SPKAboutSettingsProvider.h"

#import "../../AssetUtils.h"
#import "../../Tweak.h"
#import "../../Utils.h"
#import "../SPKTopicSettingsSupport.h"

@implementation SPKAboutSettingsProvider

+ (SPKSetting *)rootSetting {
    // Larger, bolder title so it reads in balance with the 45pt Ko-fi icon.

    return SPKTopicNavigationSetting(@"About", @"info", 24.0, @[
        SPKTopicSection(@"Information", @[
            [SPKSetting staticCellWithTitle:@"Sparkle"
                                   subtitle:SPKVersionString
                                       icon:SPKSettingsIcon(@"action")],
            [SPKSetting staticCellWithTitle:@"Instagram"
                                   subtitle:[SPKUtils IGVersionString]
                                       icon:SPKSettingsIcon(@"app")],
            [SPKSetting staticCellWithTitle:@"Bundle ID"
                                   subtitle:[[NSBundle mainBundle] bundleIdentifier]
                                       icon:SPKSettingsIcon(@"key")]
        ],
                        nil),
        SPKTopicSection(@"Credits", @[
            [SPKSetting linkCellWithTitle:@"waffle"
                                 subtitle:@"Sparkle developer"
                                 imageUrl:@"https://avatars.githubusercontent.com/u/117626247?v=4"
                                      url:@"https://github.com/efibalogh"],
            [SPKSetting linkCellWithTitle:@"SoCuul • SCInsta"
                                 subtitle:@"Base project Sparkle is built on"
                                 imageUrl:@"https://i.imgur.com/c9CbytZ.png"
                                      url:@"https://github.com/SoCuul/SCInsta"],
            [SPKSetting linkCellWithTitle:@"Ryuk • RyukGram"
                                 subtitle:@"Code, inspiration, help"
                                 imageUrl:@"https://avatars.githubusercontent.com/u/51106560?v=4"
                                      url:@"https://github.com/faroukbmiled/"],
            [SPKSetting linkCellWithTitle:@"@n3d1117 • InstaSane"
                                 subtitle:@"Following feed mode"
                                 imageUrl:@"https://avatars.githubusercontent.com/u/11541888?v=4"
                                      url:@"https://github.com/n3d1117/InstaSane"],
            [SPKSetting linkCellWithTitle:@"@asdfzxcvbn • zxPluginsInject"
                                 subtitle:@"Fixes for sideloaded installs"
                                 imageUrl:@"https://avatars.githubusercontent.com/u/109937991?v=4"
                                      url:@"https://github.com/asdfzxcvbn/zxPluginsInject"]
        ],
                        nil),
    ]);
}

@end
