#import "../../Utils.h"

// Instagram's "Custom App Icon" is an Instagram Plus feature reachable by
// long-pressing the Instagram logo/wordmark in the home feed header. Sparkle
// ships its own app-icon picker, so this native gesture is redundant (and just
// an upsell for non-subscribers). When the pref is on we no-op the gesture at
// both the view (gesture target) and the view-controller (delegate callback)
// so nothing is presented regardless of which path IG routes through.
//
// The header classes are Swift; their runtime names are the mangled
// _TtC<len><Module><len><Class> form. These classes/selectors do not exist on
// IG 410 (iOS 15), so the %hook simply binds nothing there.

%group SPKDisableAppIconGestureHooks

// Demangled: IGHomeFeedHeader.IGHomeFeedHeaderView (gesture target)
%hook _TtC16IGHomeFeedHeader20IGHomeFeedHeaderView
- (void)_logoLongPressed:(id)arg1 {
    if ([SPKUtils getBoolPref:@"feed_disable_appicon_gesture"]) {
        SPKLog(@"General", @"[Sparkle] Blocked feed logo long-press (app icon picker)");
        return;
    }
    %orig(arg1);
}
%end

// Demangled: IGHomeFeedHeader.IGHomeFeedHeaderViewController (delegate callback)
%hook _TtC16IGHomeFeedHeader30IGHomeFeedHeaderViewController
- (void)headerDidLongPressLogo:(id)arg1 {
    if ([SPKUtils getBoolPref:@"feed_disable_appicon_gesture"]) {
        return;
    }
    %orig(arg1);
}
%end

%end

void SPKInstallDisableAppIconGestureHooksIfEnabled(void) {
    if (![SPKUtils getBoolPref:@"feed_disable_appicon_gesture"])
        return;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        %init(SPKDisableAppIconGestureHooks);
    });
}
