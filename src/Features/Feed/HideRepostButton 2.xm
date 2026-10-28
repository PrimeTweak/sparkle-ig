#import "../../InstagramHeaders.h"
#import "../../Utils.h"

static inline BOOL SPKHideFeedRepostEnabled(void) {
    return [SPKUtils getBoolPref:@"feed_hide_repost_btn"];
}

static inline BOOL SPKHideReelsRepostEnabled(void) {
    return [SPKUtils getBoolPref:@"reels_hide_repost_btn"];
}

static void SPKHideFeedRepostButtons(id view) {
    if (!SPKHideFeedRepostEnabled())
        return;

    for (NSString *ivarName in @[ @"_repostView", @"_undoRepostButton" ]) {
        id candidate = [SPKUtils getIvarForObj:view name:ivarName.UTF8String];
        if ([candidate isKindOfClass:[UIView class]]) {
            ((UIView *)candidate).hidden = YES;
        }
    }

    for (NSString *ivarName in @[ @"_lazyRepostButtonContainer", @"_lazyUndoRepostButtonContainer" ]) {
        id container = [SPKUtils getIvarForObj:view name:ivarName.UTF8String];
        if (container) {
            if ([container respondsToSelector:@selector(setIsHidden:)]) {
                [container setIsHidden:YES];
            }
            if ([container respondsToSelector:@selector(viewIfLoaded)]) {
                UIView *innerView = [container viewIfLoaded];
                if (innerView) {
                    innerView.hidden = YES;
                }
            }
        }
    }
}

%group SPKHideRepostButtonHooks

%hook IGUFIButtonBarView
- (void)updateUFIWithButtonsConfig:(id)config interactionCountProvider:(id)provider {
    %orig(config, provider);
    SPKHideFeedRepostButtons(self);
}
%end

%hook IGUFIInteractionCountsView
- (void)updateUFIWithButtonsConfig:(id)config interactionCountProvider:(id)provider {
    %orig(config, provider);
    SPKHideFeedRepostButtons(self);
}
%end

%hook IGSundialViewerUFIViewModel
- (BOOL)shouldShowRepostButton {
    if (SPKHideReelsRepostEnabled()) {
        return NO;
    }

    return %orig;
}
%end

%end

extern "C" void SPKInstallHideRepostButtonHooksIfEnabled(void) {
    if (!SPKHideFeedRepostEnabled() && !SPKHideReelsRepostEnabled())
        return;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        %init(SPKHideRepostButtonHooks);
    });
}
