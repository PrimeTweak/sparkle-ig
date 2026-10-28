#import "../../Utils.h"
#import <objc/message.h>
#import <objc/runtime.h>
#import "../../App/SPKPerfMeter.h"

// IG 436+ : the reels vertical UFI no longer drives the visible counts through
// its setNumLikes:/setNumComments:/... setters. Counts are rendered by per-type
// lazy count buttons (IGSundialLikeCountButton / IGSundialUFIButtonWithCount)
// that the UFI configures from an immutable IGSundialViewerUFIViewModel. We can't
// mutate that value object, so instead we reach the type-specific buttons after
// the UFI configures/lays out and suppress just their count display.

// Hides a lazily-created count button (stored as an IGLazyView ivar). The like
// and repost counts live in dedicated count buttons, so hiding the whole lazy
// view removes only the number, not the action button.
static void SPKHideLazyCountView(id owner, const char *ivarName) {
    id lazy = [SPKUtils getIvarForObj:owner name:ivarName];
    if (!lazy)
        return;
    if ([lazy respondsToSelector:@selector(hide)]) {
        ((void (*)(id, SEL))objc_msgSend)(lazy, @selector(hide));
    }
}

// Clears the count label on an IGSundialUFIButtonWithCount-style button (save /
// comment / reshare counts share the icon button, so we blank just the label).
static void SPKHideButtonCountLabel(id button) {
    if (!button || ![button respondsToSelector:@selector(label)])
        return;
    id label = ((id (*)(id, SEL))objc_msgSend)(button, @selector(label));
    if ([label isKindOfClass:[UILabel class]]) {
        ((UILabel *)label).text = @"";
        ((UILabel *)label).hidden = YES;
    }
}

static id SPKControlForSelector(id ufi, SEL sel) {
    if (![ufi respondsToSelector:sel])
        return nil;
    return ((id (*)(id, SEL))objc_msgSend)(ufi, sel);
}

static void SPKApplyReelsMetricHiding(id ufi) {
    if (!ufi)
        return;

    if ([SPKUtils getBoolPref:@"reels_hide_like_count"]) {
        SPKHideLazyCountView(ufi, "lazyLikeCountButton");
        SPKHideLazyCountView(ufi, "lazyLikesLabelButton");
    }
    if ([SPKUtils getBoolPref:@"reels_hide_repost_count"]) {
        SPKHideLazyCountView(ufi, "lazyRepostCountButton");
        SPKHideButtonCountLabel(SPKControlForSelector(ufi, @selector(repostButton)));
    }
    if ([SPKUtils getBoolPref:@"reels_hide_save_count"]) {
        SPKHideButtonCountLabel([SPKUtils getIvarForObj:ufi name:"saveButton"]);
    }
    if ([SPKUtils getBoolPref:@"reels_hide_comment_count"]) {
        SPKHideButtonCountLabel(SPKControlForSelector(ufi, @selector(commentButton)));
    }
    if ([SPKUtils getBoolPref:@"reels_hide_reshare_count"]) {
        SPKHideButtonCountLabel(SPKControlForSelector(ufi, @selector(sendButton)));
    }
}

%group SPKHideMetricsHooks

%hook IGSundialViewerVerticalUFI
- (void)configureWithViewModel:(id)model {
    %orig;
    SPKApplyReelsMetricHiding(self);
}
- (void)configureWithMedia:(id)media interactionCountVisibilityHelper:(id)helper {
    %orig;
    SPKApplyReelsMetricHiding(self);
}
- (void)layoutSubviews {
    %orig;
    SPK_PERF_SCOPE(@"HideMetrics.layoutSubviews");
    SPKApplyReelsMetricHiding(self);
}
%end

%hook IGUFIButtonWithCountsView
- (void)setCountString:(id)string showButton:(BOOL)showButton {
    if ([self.superview isKindOfClass:%c(IGUFIInteractionCountsView)]) {
        IGUFIInteractionCountsView *countsView = (IGUFIInteractionCountsView *)self.superview;
        UIView *likesView = [countsView valueForKey:@"_likesView"];
        UIView *commentsView = [countsView valueForKey:@"_commentsView"];
        UIView *repostView = [countsView valueForKey:@"_repostView"];
        UIView *sendView = [countsView valueForKey:@"_sendView"];

        if (self == likesView && [SPKUtils getBoolPref:@"feed_hide_like_count"]) {
            return %orig(@"", showButton);
        } else if (self == commentsView && [SPKUtils getBoolPref:@"feed_hide_comment_count"]) {
            return %orig(@"", showButton);
        } else if (self == repostView && [SPKUtils getBoolPref:@"feed_hide_repost_count"]) {
            return %orig(@"", showButton);
        } else if (self == sendView && [SPKUtils getBoolPref:@"feed_hide_reshare_count"]) {
            return %orig(@"", showButton);
        }
    }
    return %orig(string, showButton);
}
%end

%end

void SPKInstallHideMetricsHooksIfEnabled(void) {
    if (![SPKUtils getBoolPref:@"feed_hide_like_count"] &&
        ![SPKUtils getBoolPref:@"feed_hide_comment_count"] &&
        ![SPKUtils getBoolPref:@"feed_hide_repost_count"] &&
        ![SPKUtils getBoolPref:@"feed_hide_reshare_count"] &&
        ![SPKUtils getBoolPref:@"reels_hide_like_count"] &&
        ![SPKUtils getBoolPref:@"reels_hide_reshare_count"] &&
        ![SPKUtils getBoolPref:@"reels_hide_comment_count"] &&
        ![SPKUtils getBoolPref:@"reels_hide_repost_count"] &&
        ![SPKUtils getBoolPref:@"reels_hide_save_count"])
        return;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        %init(SPKHideMetricsHooks, IGSundialViewerVerticalUFI = SPKReelsVerticalUFIClass());
    });
}
