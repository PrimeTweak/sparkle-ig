#import <Foundation/Foundation.h>

@class SPKSetting;

/// Diagnostic page: switch individual hook installers off for the next launch,
/// to bisect a crash or a performance regression down to one installer. Backed
/// by SPKHookBisect (src/App/SPKHookBisect.h).
@interface SPKHookBisectSettingsProvider : NSObject
+ (SPKSetting *)rootSetting;
@end
