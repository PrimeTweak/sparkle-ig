#import "../../Utils.h"

%group SPKVisualMsgModifierHooks

%hook IGDirectVisualMessage
- (NSInteger)viewMode {
    NSInteger mode = %orig;

    // * Modes *
    // 0 - View Once
    // 1 - Replayable

    if ([SPKUtils getBoolPref:@"msgs_disable_view_once"]) {
        if (mode == 0) {
            mode = 1;

            SPKLog(@"General", @"[Sparkle] Modifying visual message from read-once to replayable");
        }
    }

    return mode;
}
%end

%end

void SPKInstallVisualMsgModifierHooksIfEnabled(void) {
    if (![SPKUtils getBoolPref:@"msgs_disable_view_once"])
        return;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        %init(SPKVisualMsgModifierHooks);
    });
}
