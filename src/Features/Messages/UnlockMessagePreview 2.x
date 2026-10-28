#import "../../InstagramHeaders.h"
#import "../../Utils.h"

// "Message Preview" (peek a DM thread from the inbox without sending read receipts)
// is an Instagram Plus feature. Overriding these classes allows unlocking it.
//
// These classes are Swift; their runtime names are the mangled _TtC form and do
// not exist on IG 410 (iOS 15) where Instagram Plus is absent, so %hook binds
// nothing there.

static inline BOOL SPKUnlockMessagePreviewEnabled(void) {
    return [SPKUtils getBoolPref:@"msgs_unlock_preview"];
}

%group SPKUnlockMessagePreviewHooks

// Demangled: IGConsumerSubsDirectChatPeeks.IGConsumerSubsDirectChatPeekEligibility
%hook _TtC29IGConsumerSubsDirectChatPeeks39IGConsumerSubsDirectChatPeekEligibility

+ (BOOL)isChatPeekFeatureEligibleWithLauncherSet:(id)set consumerSubsService:(id)service {
    if (SPKUnlockMessagePreviewEnabled()) {
        return YES;
    }
    return %orig;
}

+ (BOOL)isUpsellEligibleWithLauncherSet:(id)set consumerSubsService:(id)service {
    if (SPKUnlockMessagePreviewEnabled()) {
        return NO;
    }
    return %orig;
}

+ (BOOL)isThreadEligibleForPreview:(id)preview {
    if (SPKUnlockMessagePreviewEnabled()) {
        return YES;
    }
    return %orig;
}

%end

// Demangled: IGConsumerSubsDirectChatPeeks.IGConsumerSubsDirectChatPeekNuxHelper
%hook _TtC29IGConsumerSubsDirectChatPeeks37IGConsumerSubsDirectChatPeekNuxHelper

+ (BOOL)shouldShowNuxOnTapWithLauncherSet:(id)set userSession:(id)session {
    if (SPKUnlockMessagePreviewEnabled()) {
        return NO;
    }
    return %orig;
}

%end

// Objective-C class managing direct inbox features
%hook IGDirectInboxFeatureManager

- (BOOL)_isChatPeekEligibleForThreadId:(id)threadId {
    if (SPKUnlockMessagePreviewEnabled()) {
        return YES;
    }
    return %orig;
}

%end

%end

void SPKInstallUnlockMessagePreviewHooksIfEnabled(void) {
    if (!SPKUnlockMessagePreviewEnabled())
        return;

    // Check if the eligibility class exists in the current Instagram runtime
    if (NSClassFromString(@"_TtC29IGConsumerSubsDirectChatPeeks39IGConsumerSubsDirectChatPeekEligibility") == nil) {
        return;
    }

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        %init(SPKUnlockMessagePreviewHooks);
    });
}
