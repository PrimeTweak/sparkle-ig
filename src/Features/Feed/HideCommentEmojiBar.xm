#import "../../InstagramHeaders.h"
#import "../../Utils.h"

#import <objc/runtime.h>

static NSString *const kSPKHideCommentEmojiBarPref = @"general_comments_hide_emoji_bar";

static inline BOOL SPKHideCommentEmojiBarEnabled(void) {
    return [SPKUtils getBoolPref:kSPKHideCommentEmojiBarPref];
}

// The composer controller reserves a fixed band for the emoji row through its
// stored emojiSelectionViewHeight, whether or not a row is attached. Zeroing it
// lets the composer collapse to its own height.
static void SPKZeroCommentComposerEmojiBarHeight(id controller) {
    if (!controller)
        return;

    Ivar ivar = class_getInstanceVariable(object_getClass(controller), "emojiSelectionViewHeight");
    if (!ivar)
        return;

    *(CGFloat *)((uint8_t *)(__bridge void *)controller + ivar_getOffset(ivar)) = 0.0;
}

%group SPKHideCommentEmojiBarHooks

// The composer controller hands its quick-reaction row (IGEmojiSelectionView) to
// the composer view through this setter. Keeping the property nil leaves the row
// out of the composer's layout.
%hook IGCommentComposerView

- (void)setEmojiBar:(UIView *)emojiBar {
    if (!SPKHideCommentEmojiBarEnabled()) {
        %orig;
        return;
    }

    if ([emojiBar isKindOfClass:[UIView class]]) {
        emojiBar.hidden = YES;
        if (emojiBar.superview == (UIView *)self)
            [emojiBar removeFromSuperview];
    }
    %orig(nil);
}

%end

%end

// emojiSelectionViewHeight is a constant assigned in the controller's init, and
// the comment thread reads it when sizing the composer, so it has to be cleared
// as soon as init returns.
typedef id (*SPKCommentComposerInit)(id, SEL, id, id, id, id, id, id, id, id, id, id);
static SPKCommentComposerInit orig_SPKCommentComposerInit;

static id hook_SPKCommentComposerInit(id self, SEL _cmd, id session, id media, id loggingDelegate, id presenter, id module, id navigationState, id keyboardObserver, id options, id configurations, id sessionID) {
    id result = orig_SPKCommentComposerInit(self, _cmd, session, media, loggingDelegate, presenter, module, navigationState, keyboardObserver, options, configurations, sessionID);
    if (SPKHideCommentEmojiBarEnabled())
        SPKZeroCommentComposerEmojiBarHeight(result);
    return result;
}

extern "C" void SPKInstallHideCommentEmojiBarHooksIfEnabled(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        %init(SPKHideCommentEmojiBarHooks);

        Class controllerClass = objc_getClass("_TtC17IGCommentComposer27IGCommentComposerController");
        SEL init = @selector(initWithUserSession:media:loggingDelegate:presentingViewController:analyticsModule:navigationState:keyboardObserver:composerOptions:composerConfigurations:commentSheetSessionID:);
        if (controllerClass && class_getInstanceMethod(controllerClass, init))
            MSHookMessageEx(controllerClass, init, (IMP)hook_SPKCommentComposerInit, (IMP *)&orig_SPKCommentComposerInit);
    });
}
