#import "../../InstagramHeaders.h"
#import "../../Utils.h"
#import "../../App/SPKPerfMeter.h"

%group SPKHideTrendingSearchesHooks

%hook IGDSSegmentedPillBarView
- (void)didMoveToWindow {
    %orig;
    SPK_PERF_SCOPE(@"HideTrendingSearches.didMoveToWindow");

    if ([[self delegate] isKindOfClass:%c(IGSearchTypeaheadNavigationHeaderView)]) {
        if ([SPKUtils getBoolPref:@"interface_hide_trending_searches"]) {
            SPKLog(@"General", @"[Sparkle] Hiding trending searches");

            [self removeFromSuperview];
        }
    }
}
%end

%end

void SPKInstallHideTrendingSearchesHooksIfEnabled(void) {
    if (![SPKUtils getBoolPref:@"interface_hide_trending_searches"])
        return;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        %init(SPKHideTrendingSearchesHooks);
    });
}
