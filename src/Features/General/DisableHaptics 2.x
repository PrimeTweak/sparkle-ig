#import "../../Utils.h"

%group SPKDisableHapticsHooks

%hook UIImpactFeedbackGenerator
- (void)impactOccurred {
    if (![SPKUtils getBoolPref:@"general_disable_haptics"])
        %orig;
}
- (void)impactOccurredWithIntensity:(CGFloat)intensity {
    if (![SPKUtils getBoolPref:@"general_disable_haptics"])
        %orig(intensity);
}
%end

%hook UINotificationFeedbackGenerator
- (void)notificationOccurred:(UINotificationFeedbackType)notificationType {
    if (![SPKUtils getBoolPref:@"general_disable_haptics"])
        %orig(notificationType);
}
%end

%hook UISelectionFeedbackGenerator
- (void)selectionChanged {
    if (![SPKUtils getBoolPref:@"general_disable_haptics"])
        %orig;
}
%end

%hook CHHapticEngine
- (BOOL)startAndReturnError:(NSError **)outError {
    if (![SPKUtils getBoolPref:@"general_disable_haptics"]) {
        return %orig(outError);
    } else {
        return NO;
    }
}
%end

%end

void SPKInstallDisableHapticsHooksIfEnabled(void) {
    if (![SPKUtils getBoolPref:@"general_disable_haptics"])
        return;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        %init(SPKDisableHapticsHooks);
    });
}
