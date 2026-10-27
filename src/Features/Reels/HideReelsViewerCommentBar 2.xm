#import <objc/runtime.h>

#import "../../InstagramHeaders.h"
#import "../../Utils.h"

// Both values below are Swift stored properties with no @objc accessor, so
// valueForKey: raises for every one of them and silently leaves the caller with
// zero. Reading the ivar storage directly is the only way to see them.
static BOOL SPKReelsBarFloatIvar(id obj, const char *name, CGFloat *out) {
    if (!obj || !name || !out)
        return NO;

    Ivar ivar = class_getInstanceVariable(object_getClass(obj), name);
    if (!ivar)
        return NO;

    const char *encoding = ivar_getTypeEncoding(ivar);
    if (!encoding)
        return NO;

    const void *base = (__bridge const void *)obj;
    const void *slot = (const char *)base + ivar_getOffset(ivar);
    if (encoding[0] == 'd') {
        double value = 0.0;
        memcpy(&value, slot, sizeof(value));
        *out = (CGFloat)value;
        return YES;
    }
    if (encoding[0] == 'f') {
        float value = 0.0f;
        memcpy(&value, slot, sizeof(value));
        *out = (CGFloat)value;
        return YES;
    }
    return NO;
}

static UIView *SPKReelsBarViewIvar(id obj, const char *name) {
    if (!obj || !name)
        return nil;

    Ivar ivar = class_getInstanceVariable(object_getClass(obj), name);
    if (!ivar)
        return nil;

    id value = object_getIvar(obj, ivar);
    return [value isKindOfClass:UIView.class] ? (UIView *)value : nil;
}

static CGFloat SPKCommentContentViewTabBarInset(UIView *view) {
    CGFloat inset = 0.0;
    if (!SPKReelsBarFloatIvar(view, "cachedTabBarBottomInset", &inset))
        return 0.0;
    return MAX(0.0, inset);
}

static BOOL SPKModernReelsViewerBarIsCommentBar(_TtC19IGSundialFeedFooter24IGSundialViewerBottomBar *bar) {
    Class commentConfigClass = NSClassFromString(@"_TtC19IGSundialFeedFooter37IGSundialViewerBottomBarCommentConfig");
    return commentConfigClass && [bar.config isKindOfClass:commentConfigClass];
}

%group SPKModernReelsViewerCommentBarHooks

%hook _TtC19IGSundialFeedFooter24IGSundialViewerBottomBar

- (CGSize)sizeThatFits:(CGSize)size {
    if (SPKModernReelsViewerBarIsCommentBar(self)) {
        UIView *cv = SPKReelsBarViewIvar(self, "contentView");
        if (cv) {
            return [cv sizeThatFits:size];
        }
        return CGSizeMake(size.width, 0.0);
    }
    return %orig(size);
}

%end

// Hides only the comment composer UI (the pill container, text field, save button)
// while preserving any tab bar bottom insets on screens where the tab bar is shown.
%hook _TtC19IGSundialFeedFooter42IGSundialViewerBottomBarCommentContentView

- (void)didMoveToWindow {
    %orig;
    for (UIView *subview in self.subviews) {
        subview.hidden = YES;
    }
}

- (void)layoutSubviews {
    %orig;
    for (UIView *subview in self.subviews) {
        subview.hidden = YES;
    }
}

- (CGSize)sizeThatFits:(CGSize)size {
    CGFloat tabInset = SPKCommentContentViewTabBarInset(self);
    return CGSizeMake(size.width, tabInset);
}

%end

%end

%group SPKLegacyReelsViewerCommentBarHooks

%hook IGSundialViewerBottomBar

- (instancetype)initWithCTAButtonType:(NSInteger)type
                   fakeComposerEnabled:(BOOL)enabled
                      commentBarDisabled:(BOOL)disabled {
    // Only disable the fake comment composer while preserving the commentBarDisabled flag
    // (modifying commentBarDisabled causes IGSundialFeedViewController to hide the tab bar).
    return %orig(type, NO, disabled);
}

%end

%end


extern "C" void SPKInstallHideReelsViewerCommentBarHooksIfEnabled(void) {
    if (![SPKUtils getBoolPref:@"reels_hide_viewer_comment_bar"])
        return;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        BOOL installedModern = NSClassFromString(@"_TtC19IGSundialFeedFooter24IGSundialViewerBottomBar") != Nil;
        BOOL installedLegacy = NSClassFromString(@"IGSundialViewerBottomBar") != Nil;

        if (installedModern)
            %init(SPKModernReelsViewerCommentBarHooks);
        if (installedLegacy)
            %init(SPKLegacyReelsViewerCommentBarHooks);

        SPKLog(@"Reels", @"Hide viewer comment bar hooks installed modern=%d legacy=%d",
               installedModern,
               installedLegacy);
    });
}
