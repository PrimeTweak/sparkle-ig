#import "../../InstagramHeaders.h"
#import "../../Utils.h"

#import <objc/message.h>
#import "../../App/SPKPerfMeter.h"

static NSString *const kSPKHideCommentGiftsButtonPref = @"general_comments_hide_gifts_button";

static inline BOOL SPKHideCommentGiftsButtonEnabled(void) {
    return [SPKUtils getBoolPref:kSPKHideCommentGiftsButtonPref];
}

static BOOL SPKViewMatchesCommentGiftButton(UIView *view) {
    if (![view isKindOfClass:[UIControl class]])
        return NO;

    // Language-independent signals first: a gift tap action or the gift glyph asset
    // name. accessibilityLabel ("Gifts button") is localized, so it's the fallback.
    // The primary code path finds this button via the composer's _giftButton /
    // _lazyGiftButton ivar; this matcher only gates the subtree-search fallback.
    if ([SPKUtils control:(UIControl *)view hasTapActionContaining:@"gift"])
        return YES;
    if ([view isKindOfClass:UIButton.class]) {
        NSString *iconName = [SPKUtils igImageNameForImage:((UIButton *)view).currentImage];
        if ([iconName containsString:@"gift"])
            return YES;
    }

    return [view.accessibilityLabel isEqualToString:@"Gifts button"];
}

static UIView *SPKCommentGiftButtonInView(UIView *view, NSUInteger depth) {
    if (!view || depth > 8)
        return nil;
    if (SPKViewMatchesCommentGiftButton(view))
        return view;

    for (UIView *subview in view.subviews) {
        UIView *candidate = SPKCommentGiftButtonInView(subview, depth + 1);
        if (candidate)
            return candidate;
    }

    return nil;
}

static UIView *SPKCommentGiftButtonFromCandidate(id candidate) {
    if (![candidate isKindOfClass:[UIView class]])
        return nil;

    UIView *view = (UIView *)candidate;
    if (SPKViewMatchesCommentGiftButton(view))
        return view;

    UIView *nested = SPKCommentGiftButtonInView(view, 0);
    return nested ?: view;
}

static UIView *SPKCommentComposerGiftButton(UIView *composerView) {
    for (NSString *ivarName in @[ @"_lazyGiftButton", @"_giftButton" ]) {
        UIView *candidate = SPKCommentGiftButtonFromCandidate([SPKUtils getIvarForObj:composerView name:ivarName.UTF8String]);
        if (candidate)
            return candidate;
    }

    return SPKCommentGiftButtonInView(composerView, 0);
}

static void SPKSetCommentComposerGiftButtonEnabled(id composerView, BOOL enabled) {
    SEL selector = @selector(setGiftButtonEnabled:);
    if ([composerView respondsToSelector:selector]) {
        ((void (*)(id, SEL, BOOL))objc_msgSend)(composerView, selector, enabled);
    }
}

static void SPKHideCommentComposerGiftButton(UIView *composerView) {
    if (!SPKHideCommentGiftsButtonEnabled())
        return;

    SPKSetCommentComposerGiftButtonEnabled(composerView, NO);

    UIView *giftButton = SPKCommentComposerGiftButton(composerView);
    if (!giftButton)
        return;

    CGRect giftFrame = [giftButton.superview convertRect:giftButton.frame toView:composerView];
    giftButton.hidden = YES;
    giftButton.userInteractionEnabled = NO;
    giftButton.alpha = 0.0;

    UIView *textView = [SPKUtils getIvarForObj:composerView name:"_growingTextView"];
    UIView *backgroundView = [SPKUtils getIvarForObj:composerView name:"_roundedBackgroundImageView"];
    if (![textView isKindOfClass:[UIView class]])
        return;

    CGRect textFrame = [textView.superview convertRect:textView.frame toView:composerView];
    CGFloat trailingTarget = CGRectGetMaxX(giftFrame);
    if (trailingTarget <= CGRectGetMaxX(textFrame) + 1.0)
        return;
    if (CGRectGetMinX(giftFrame) < CGRectGetMaxX(textFrame) - 2.0)
        return;

    CGRect expandedTextFrame = textFrame;
    expandedTextFrame.size.width = trailingTarget - CGRectGetMinX(textFrame);
    textView.frame = [composerView convertRect:expandedTextFrame toView:textView.superview];

    if ([backgroundView isKindOfClass:[UIView class]]) {
        CGRect backgroundFrame = [backgroundView.superview convertRect:backgroundView.frame toView:composerView];
        if (CGRectGetMaxX(backgroundFrame) <= trailingTarget + 1.0 &&
            CGRectGetMinX(backgroundFrame) <= CGRectGetMinX(textFrame) + 2.0) {
            backgroundFrame.size.width = trailingTarget - CGRectGetMinX(backgroundFrame);
            backgroundView.frame = [composerView convertRect:backgroundFrame toView:backgroundView.superview];
        }
    }
}

%group SPKHideCommentGiftsButtonHooks

%hook IGCommentComposerView

- (void)setGiftButtonEnabled:(BOOL)enabled {
    %orig(SPKHideCommentGiftsButtonEnabled() ? NO : enabled);
}

- (BOOL)giftButtonEnabled {
    if (SPKHideCommentGiftsButtonEnabled())
        return NO;
    return %orig;
}

- (void)layoutSubviews {
    SPK_PERF_SCOPE(@"HideCommentGiftsButton.layoutSubviews");
    if (SPKHideCommentGiftsButtonEnabled()) {
        SPKSetCommentComposerGiftButtonEnabled(self, NO);
    }

    %orig;

    SPKHideCommentComposerGiftButton((UIView *)self);
}

- (CGSize)sizeThatFits:(CGSize)size {
    if (SPKHideCommentGiftsButtonEnabled()) {
        SPKSetCommentComposerGiftButtonEnabled(self, NO);
    }

    return %orig(size);
}

%end

%end

extern "C" void SPKInstallHideCommentGiftsButtonHooksIfEnabled(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        %init(SPKHideCommentGiftsButtonHooks);
    });
}
