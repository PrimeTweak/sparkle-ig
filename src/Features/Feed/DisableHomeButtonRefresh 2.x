#import "../../Utils.h"

static NSInteger const kSPKFeedRefreshReasonHomeButton = 5;

static BOOL spkShouldBlockFeedRefresh(void) {
    return [SPKUtils getBoolPref:@"feed_disable_home_refresh"];
}

static BOOL spkScrollViewToTopWithoutRefresh(UIScrollView *scrollView) {
    if (![scrollView isKindOfClass:[UIScrollView class]]) {
        return NO;
    }

    CGPoint topOffset = CGPointMake(scrollView.contentOffset.x, -scrollView.adjustedContentInset.top);
    if (CGPointEqualToPoint(scrollView.contentOffset, topOffset)) {
        return NO;
    }

    [scrollView setContentOffset:topOffset animated:YES];
    return NO;
}

%group SPKDisableHomeButtonRefreshHooks

%hook IGMainFeedViewController
- (void)refreshFeedWithFetchReason:(NSInteger)reason animated:(BOOL)animated {
    if (spkShouldBlockFeedRefresh() && reason == kSPKFeedRefreshReasonHomeButton) {
        SPKLog(@"General", @"[Sparkle] Blocking home-button feed refresh");
        return;
    }

    %orig;
}
%end

%hook IGMainFeedScrollViewDelegateDistributor
- (BOOL)scrollViewShouldScrollToTop:(UIScrollView *)scrollView {
    if (spkShouldBlockFeedRefresh()) {
        return spkScrollViewToTopWithoutRefresh(scrollView);
    }

    return %orig;
}
%end

// Swift class from IGHomeSundialFeedScrollOrchestrator.
%hook _TtC35IGHomeSundialFeedScrollOrchestrator35IGHomeSundialFeedScrollOrchestrator
- (BOOL)scrollViewShouldScrollToTop:(UIScrollView *)scrollView {
    if (spkShouldBlockFeedRefresh()) {
        return spkScrollViewToTopWithoutRefresh(scrollView);
    }

    return %orig;
}
%end

%end

void SPKInstallDisableHomeButtonRefreshHooksIfEnabled(void) {
    if (![SPKUtils getBoolPref:@"feed_disable_home_refresh"])
        return;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        %init(SPKDisableHomeButtonRefreshHooks);
    });
}
