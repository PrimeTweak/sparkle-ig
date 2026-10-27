#import "../../Utils.h"
#import "../../App/SPKPerfMeter.h"

static BOOL SPKShouldHideDirectCallButton(UIView *button) {
    if (![button isKindOfClass:NSClassFromString(@"IGDirectCallButton")])
        return NO;
    NSString *identifier = button.accessibilityIdentifier;
    if ([identifier isEqualToString:@"audio-call"])
        return [SPKUtils getBoolPref:@"msgs_hide_audio_call_btn"];
    if ([identifier isEqualToString:@"video-chat"])
        return [SPKUtils getBoolPref:@"msgs_hide_video_call_btn"];
    return NO;
}

static BOOL SPKViewContainsHiddenDirectCallButton(UIView *rootView) {
    NSMutableArray<UIView *> *queue = [NSMutableArray arrayWithObject:rootView];
    while (queue.count > 0) {
        UIView *view = queue.firstObject;
        [queue removeObjectAtIndex:0];
        if (SPKShouldHideDirectCallButton(view))
            return YES;
        [queue addObjectsFromArray:view.subviews];
    }
    return NO;
}

static NSArray<UIBarButtonItem *> *SPKFilterHiddenDirectCallBarButtonItems(NSArray<UIBarButtonItem *> *items) {
    if (items.count == 0)
        return items;

    return [items filteredArrayUsingPredicate:
                      [NSPredicate predicateWithBlock:^BOOL(UIBarButtonItem *item, NSDictionary *_) {
                          return !SPKShouldHideDirectCallButton(item.customView);
                      }]];
}

static void SPKRepackNavigationBarPlatters(UIView *container) {
    NSMutableArray<UIView *> *platters = [NSMutableArray array];
    for (UIView *subview in container.subviews) {
        if ([NSStringFromClass(subview.class) isEqualToString:@"_UINavigationBarPlatterView"]) {
            [platters addObject:subview];
        }
    }

    CGFloat hiddenWidth = 0.0;
    NSMutableArray<UIView *> *visiblePlatters = [NSMutableArray array];
    for (UIView *platter in platters) {
        if (SPKViewContainsHiddenDirectCallButton(platter)) {
            hiddenWidth += CGRectGetWidth(platter.frame);
            platter.hidden = YES;
        } else {
            platter.hidden = NO;
            [visiblePlatters addObject:platter];
        }
    }

    for (UIView *platter in visiblePlatters) {
        platter.transform = (hiddenWidth > 0.0 && CGRectGetMinX(platter.frame) >= 60.0)
                                ? CGAffineTransformMakeTranslation(hiddenWidth, 0.0)
                                : CGAffineTransformIdentity;
    }
}

%group SPKHideDirectCallButtonsHooks

%hook IGDirectThreadCallButtonsCoordinator

- (void)_didTapAudioButton {
    if ([SPKUtils getBoolPref:@"msgs_hide_audio_call_btn"])
        return;
    %orig;
}

- (void)_didTapAudioButton:(id)button {
    if ([SPKUtils getBoolPref:@"msgs_hide_audio_call_btn"])
        return;
    %orig;
}

- (void)_didTapVideoButton {
    if ([SPKUtils getBoolPref:@"msgs_hide_video_call_btn"])
        return;
    %orig;
}

- (void)_didTapVideoButton:(id)button {
    if ([SPKUtils getBoolPref:@"msgs_hide_video_call_btn"])
        return;
    %orig;
}

%end

%hook IGDirectCallButton

- (void)didMoveToWindow {
    %orig;
    SPK_PERF_SCOPE(@"HideCallButtons.didMoveToWindow");
    UIView *button = (UIView *)self;
    if (button.window && SPKShouldHideDirectCallButton(button)) {
        button.hidden = YES;
    }
}

%end

%hook IGTallNavigationBarView

- (void)setRightBarButtonItems:(NSArray<UIBarButtonItem *> *)items {
    %orig(SPKFilterHiddenDirectCallBarButtonItems(items));
}

%end

%hook IGNavigationBar

- (void)layoutSubviews {
    %orig;
    SPK_PERF_SCOPE(@"HideCallButtons.layoutSubviews");

    NSMutableArray<UIView *> *queue = [NSMutableArray arrayWithObject:(UIView *)self];
    while (queue.count > 0) {
        UIView *view = queue.firstObject;
        [queue removeObjectAtIndex:0];
        if ([NSStringFromClass(view.class) containsString:@"NavigationBarPlatterContainer"]) {
            SPKRepackNavigationBarPlatters(view);
            break;
        }
        [queue addObjectsFromArray:view.subviews];
    }
}

%end

%end

extern "C" void SPKInstallHideDirectCallButtonsHooksIfEnabled(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        %init(SPKHideDirectCallButtonsHooks);
    });
}
