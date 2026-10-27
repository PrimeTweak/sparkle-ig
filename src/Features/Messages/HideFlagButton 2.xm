#import "../../Utils.h"

%group SPKHideFlagButtonHooks

%hook IGDirectThreadLabelButtonComponent

- (id)makeLabelButtonWithTintColor:(id)color {
    if ([SPKUtils getBoolPref:@"msgs_hide_flag_btn"]) {
        return nil;
    }
    return %orig;
}

%end

%hook IGDirectThreadViewRightBarButtonsFeatureController

- (id)labelButtonWithTintColor:(id)color {
    if ([SPKUtils getBoolPref:@"msgs_hide_flag_btn"]) {
        return nil;
    }
    return %orig;
}

%end

%hook IGDirectThreadFlagController

- (id)initWithUserSession:(id)session threadId:(id)threadId threadIsFlagged:(_Bool)flagged flagButton:(id)button presentingViewController:(id)controller {
    if ([SPKUtils getBoolPref:@"msgs_hide_flag_btn"]) {
        if ([button isKindOfClass:[UIView class]]) {
            ((UIView *)button).hidden = YES;
        }
        return %orig(session, threadId, flagged, nil, controller);
    }
    return %orig;
}

- (void)updateThreadIsFlagged:(_Bool)flagged {
    %orig;
    if ([SPKUtils getBoolPref:@"msgs_hide_flag_btn"]) {
        UIBarButtonItem *barBtn = MSHookIvar<UIBarButtonItem *>(self, "_flagBarButtonItem");
        if ([barBtn respondsToSelector:@selector(customView)]) {
            barBtn.customView.hidden = YES;
        }
    }
}

%end

%end

extern "C" void SPKInstallHideFlagButtonHooksIfEnabled(void) {
    if (![SPKUtils getBoolPref:@"msgs_hide_flag_btn"])
        return;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        %init(SPKHideFlagButtonHooks);
    });
}
