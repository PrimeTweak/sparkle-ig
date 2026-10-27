#import "../../InstagramHeaders.h"
#import "../../Utils.h"

%group SPKChangeThemeConfirmHooks

%hook IGDirectThreadThemePickerViewController
- (void)themeNewPickerSectionController:(id)arg1 didSelectTheme:(id)arg2 atIndex:(NSInteger)arg3 {
    if ([SPKUtils getBoolPref:@"msgs_confirm_theme_change"]) {
        SPKLog(@"General", @"[Sparkle] Confirm change direct theme triggered");

        [SPKUtils
            showConfirmation:^(void) {
                %orig;
            }
                       title:@"Confirm Change Chat Theme"
                     message:@"Everyone in the chat sees the new theme."];
    } else {
        return %orig;
    }
}
- (void)themePickerSectionController:(id)arg1 didSelectThemeId:(id)arg2 {
    if ([SPKUtils getBoolPref:@"msgs_confirm_theme_change"]) {
        SPKLog(@"General", @"[Sparkle] Confirm change direct theme triggered");

        [SPKUtils
            showConfirmation:^(void) {
                %orig;
            }
                       title:@"Confirm Change Chat Theme"
                     message:@"Everyone in the chat sees the new theme."];
    } else {
        return %orig;
    }
}
%end

%hook IGDirectThreadThemeKitSwift.IGDirectThreadThemePreviewController
- (void)primaryButtonTapped {
    if ([SPKUtils getBoolPref:@"msgs_confirm_theme_change"]) {
        SPKLog(@"General", @"[Sparkle] Confirm change direct theme triggered");

        [SPKUtils
            showConfirmation:^(void) {
                %orig;
            }
                       title:@"Confirm Change Chat Theme"
                     message:@"Everyone in the chat sees the new theme."];
    } else {
        return %orig;
    }
}
%end

%end

void SPKInstallChangeThemeConfirmHooksIfEnabled(void) {
    if (![SPKUtils getBoolPref:@"msgs_confirm_theme_change"])
        return;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        %init(SPKChangeThemeConfirmHooks);
    });
}
