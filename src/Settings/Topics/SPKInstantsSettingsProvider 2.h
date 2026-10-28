#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class SPKSetting;

@interface SPKInstantsSettingsProvider : NSObject
+ (SPKSetting *)rootSetting;

/// A standalone Instants settings screen, for presenting outside the main
/// settings tree (e.g. from the Instants gallery-upload sheet).
+ (UIViewController *)makeSettingsViewController;
@end
