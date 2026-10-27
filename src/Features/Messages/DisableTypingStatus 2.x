#import "../../Utils.h"

%group SPKDisableTypingStatusHooks

%hook IGDirectTypingStatusService
- (void)updateOutgoingStatusIsActive:(_Bool)active threadKey:(id)key threadMetadata:(id)metadata typingStatusType:(long long)type {
    if ([SPKUtils getBoolPref:@"msgs_disable_typing"])
        return;

    return %orig(active, key, metadata, type);
}
%end

%end

void SPKInstallDisableTypingStatusHooksIfEnabled(void) {
    if (![SPKUtils getBoolPref:@"msgs_disable_typing"])
        return;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        %init(SPKDisableTypingStatusHooks);
    });
}
