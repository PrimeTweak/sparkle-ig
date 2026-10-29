#import "../../InstagramHeaders.h"
#import "../../Utils.h"
#import "../../App/SPKPerfMeter.h"

%group SPKDisableScrollingReelsHooks

%hook IGUnifiedVideoCollectionView
- (void)didMoveToWindow {
    %orig;
    SPK_PERF_SCOPE(@"DisableScrollingReels.didMoveToWindow");

    if ([SPKUtils getBoolPref:@"reels_disable_scrolling"]) {
        SPKLog(@"General", @"[Sparkle] Disabling scrolling reels");

        self.scrollEnabled = false;
    }
}

- (void)setScrollEnabled:(BOOL)arg1 {
    if ([SPKUtils getBoolPref:@"reels_disable_scrolling"]) {
        SPKLog(@"General", @"[Sparkle] Disabling scrolling reels");

        return %orig(NO);
    }

    return %orig;
}
%end

// The auto scroll toggle in Reels goes through this setter, so One reel at a
// time keeps it off.
%hook _TtC19IGSundialAutoScroll19IGSundialAutoScroll
- (void)setUserEnabled:(BOOL)enabled {
    %orig([SPKUtils getBoolPref:@"reels_disable_scrolling"] ? NO : enabled);
}
%end

%end

void SPKInstallDisableScrollingReelsHooksIfEnabled(void) {
    if (![SPKUtils getBoolPref:@"reels_disable_scrolling"])
        return;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        %init(SPKDisableScrollingReelsHooks);
    });
}
