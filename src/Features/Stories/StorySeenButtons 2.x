#import <objc/message.h>
#import <objc/runtime.h>
#import <substrate.h>

#import "../../AssetUtils.h"
#import "../../InstagramHeaders.h"
#import "../../Shared/Messages/SPKDirectSeenContext.h"
#import "../../Shared/Stories/SPKStoryButtonPlacement.h"
#import "../../Shared/Stories/SPKStoryContext.h"
#import "../../Shared/Stories/SPKStoryDynamicRange.h"
#import "../../Shared/UI/SPKChrome.h"
#import "../../Tweak.h"
#import "../../Utils.h"
#import "../../App/SPKPerfMeter.h"
#ifdef __cplusplus
extern "C" {
#endif
void SPKApplyButtonStyle(UIButton *button, NSInteger source);
#ifdef __cplusplus
}
#endif

#ifdef __cplusplus
extern "C" {
#endif
void SPKUpdateStoryMentionsButton(UIView *overlayView, CGFloat x, CGFloat y, CGFloat size);
void SPKRemoveStoryMentionsButton(UIView *overlayView);
#ifdef __cplusplus
}
#endif

static NSString *const kSPKSeenMessagesBarIconResource = @"eye";
static NSInteger const kSPKActionButtonSourceDirect = 4;
static NSInteger const kSPKStorySeenButtonTag = 926001;
static NSInteger const kSPKStoryMentionsButtonTag = 926002;
static NSInteger const kSPKStoriesActionButtonTag = 921343;
static const void *kSPKStoryOverlayObservedFooterAssocKey = &kSPKStoryOverlayObservedFooterAssocKey;
static const void *kSPKStoryOverlayHasObserverAssocKey = &kSPKStoryOverlayHasObserverAssocKey;
static void *kSPKStoryOverlayAlphaObserverContext = &kSPKStoryOverlayAlphaObserverContext;
static __weak UIView *SPKActiveStoryOverlayView = nil;

static id SPKKVCObject(id target, NSString *key);
static id SPKObjectForSelector(id target, NSString *selectorName);
static id SPKFirstObjectForSelectors(id target, NSArray<NSString *> *selectors);
void SPKMarkStoryAsSeenForViewWithAdvancePref(UIView *view, NSString *advancePrefKey);

static inline BOOL SPKManualStorySeenEnabled(void) {
    return [SPKUtils getBoolPref:@"stories_manual_seen"];
}
static inline BOOL SPKStorySeenHooksNeeded(void) {
    return [SPKUtils getBoolPref:@"stories_manual_seen"] ||
           SPKStoryManualSeenUserList(NO).count > 0 ||
           [SPKUtils getBoolPref:@"stories_mentions_btn"] ||
           [SPKUtils getBoolPref:@"stories_mark_seen_on_reply"] ||
           [SPKUtils getBoolPref:@"stories_advance_on_reply_seen"];
}
static id SPKKVCObject(id target, NSString *key) {
    if (!target || key.length == 0)
        return nil;

    @try {
        return [target valueForKey:key];
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

static id SPKObjectForSelector(id target, NSString *selectorName) {
    if (!target || selectorName.length == 0)
        return nil;

    SEL selector = NSSelectorFromString(selectorName);
    if (![target respondsToSelector:selector])
        return nil;

    return ((id (*)(id, SEL))objc_msgSend)(target, selector);
}

static id SPKFirstObjectForSelectors(id target, NSArray<NSString *> *selectors) {
    if (!target || selectors.count == 0)
        return nil;
    for (NSString *selectorName in selectors) {
        id value = SPKObjectForSelector(target, selectorName);
        if (value)
            return value;
    }
    return nil;
}

static void SPKPlayButtonTappedHaptic(void) {
    UISelectionFeedbackGenerator *feedback = [UISelectionFeedbackGenerator new];
    [feedback selectionChanged];
}
static BOOL SPKOverlayIsDirectVisualOverlay(UIView *overlayView) {
    static Class directViewerClass;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        directViewerClass = NSClassFromString(@"IGDirectVisualMessageViewerController");
    });
    if (!directViewerClass)
        return NO;
    UIViewController *nearestVC = [SPKUtils nearestViewControllerForView:overlayView];
    return [nearestVC isKindOfClass:directViewerClass];
}
static UIButton *SPKStorySeenButtonWithTag(UIView *container, NSInteger tag) {
    UIView *existing = [container viewWithTag:tag];
    if ([existing isKindOfClass:SPKChromeButton.class]) {
        return (UIButton *)existing;
    }
    [existing removeFromSuperview];

    SPKChromeButton *button = [[SPKChromeButton alloc] initWithSymbol:@"" pointSize:24.0 diameter:44.0];
    button.tag = tag;
    button.adjustsImageWhenHighlighted = YES;
    button.showsMenuAsPrimaryAction = NO;
    button.clipsToBounds = NO;
    [container addSubview:button];
    return button;
}

static void SPKSetSeenButtonImage(UIButton *button, UIImage *image, NSString *logMessage) {
    UIImage *templatedImage = [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    if ([button isKindOfClass:SPKChromeButton.class]) {
        SPKChromeButton *chromeButton = (SPKChromeButton *)button;
        chromeButton.iconView.image = templatedImage;
        chromeButton.iconTint = UIColor.whiteColor;
        [button setImage:nil forState:UIControlStateNormal];
    } else {
        [button setImage:templatedImage forState:UIControlStateNormal];
    }

    SPKLog(@"Capture", @"%@ tag=%ld button=%@<%p> subviews=%@ imageView=%@<%p> imageSuperview=%@<%p>",
           logMessage,
           (long)button.tag,
           NSStringFromClass(button.class),
           button,
           button.subviews,
           NSStringFromClass(button.imageView.class),
           button.imageView,
           NSStringFromClass(button.imageView.superview.class),
           button.imageView.superview);
}

static void SPKApplyStorySeenButtonStyle(UIButton *button) {
    if (!button)
        return;
    SPKApplyButtonStyle(button, kSPKActionButtonSourceDirect);
    SPKStoryApplyDynamicRangeToButton(button);
}

static UIView *SPKStoryFooterContainerFromOverlay(UIView *overlayView) {
    if (!overlayView)
        return nil;

    UIView *footerContainer = [SPKUtils getIvarForObj:overlayView name:"_footerContainerView"];
    if (![footerContainer isKindOfClass:[UIView class]]) {
        id selectorFooter = SPKObjectForSelector(overlayView, @"footerContainerView");
        footerContainer = [selectorFooter isKindOfClass:[UIView class]] ? (UIView *)selectorFooter : nil;
    }
    return footerContainer;
}

static void SPKUpdateStoryButtonsAlpha(UIView *overlayView, CGFloat alpha) {
    if (!overlayView)
        return;

    // Our buttons are added directly to the overlay, so a single non-recursive
    // pass over the immediate subviews avoids three full-subtree -viewWithTag:
    // searches. This runs on every cross-fade frame via the footer alpha KVO,
    // so keeping it cheap matters during story-to-story transitions.
    for (UIView *subview in overlayView.subviews) {
        NSInteger tag = subview.tag;
        if (tag == kSPKStoriesActionButtonTag || tag == kSPKStorySeenButtonTag || tag == kSPKStoryMentionsButtonTag) {
            subview.alpha = alpha;
        }
    }
}

static void SPKRemoveStoryOverlayAlphaObserverIfNeeded(UIView *overlayView) {
    UIView *observedFooter = objc_getAssociatedObject(overlayView, kSPKStoryOverlayObservedFooterAssocKey);
    BOOL hasObserver = [objc_getAssociatedObject(overlayView, kSPKStoryOverlayHasObserverAssocKey) boolValue];
    if (observedFooter && hasObserver) {
        [observedFooter removeObserver:overlayView forKeyPath:@"alpha" context:kSPKStoryOverlayAlphaObserverContext];
    }

    objc_setAssociatedObject(overlayView, kSPKStoryOverlayObservedFooterAssocKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(overlayView, kSPKStoryOverlayHasObserverAssocKey, @NO, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void SPKEnsureStoryOverlayAlphaObserver(UIView *overlayView) {
    if (!overlayView)
        return;

    UIView *footerContainer = SPKStoryFooterContainerFromOverlay(overlayView);
    UIView *observedFooter = objc_getAssociatedObject(overlayView, kSPKStoryOverlayObservedFooterAssocKey);
    BOOL hasObserver = [objc_getAssociatedObject(overlayView, kSPKStoryOverlayHasObserverAssocKey) boolValue];
    if (observedFooter && observedFooter != footerContainer && hasObserver) {
        [observedFooter removeObserver:overlayView forKeyPath:@"alpha" context:kSPKStoryOverlayAlphaObserverContext];
        objc_setAssociatedObject(overlayView, kSPKStoryOverlayHasObserverAssocKey, @NO, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        hasObserver = NO;
    }

    if (observedFooter != footerContainer) {
        objc_setAssociatedObject(overlayView, kSPKStoryOverlayObservedFooterAssocKey, footerContainer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    if (footerContainer && !hasObserver) {
        [footerContainer addObserver:overlayView
                          forKeyPath:@"alpha"
                             options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                             context:kSPKStoryOverlayAlphaObserverContext];
        objc_setAssociatedObject(overlayView, kSPKStoryOverlayHasObserverAssocKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

static CGRect SPKStorySeenBaseFrame(UIView *overlayView) {
    // Match the SPKChromeButton diameter (44) and the stories action button size so
    // the seen/mentions buttons keep the same size and trailing anchor whether or not
    // the action button is present.
    return SPKStoryFloatingButtonFrame(overlayView, 44.0);
}

static id SPKStorySectionControllerFromOverlayView(UIView *overlayView) {
    if (!overlayView)
        return nil;

    NSArray<NSString *> *delegateSelectors = @[ @"mediaOverlayDelegate", @"retryDelegate", @"tappableOverlayDelegate", @"buttonDelegate" ];
    Class sectionControllerClass = NSClassFromString(@"IGStoryFullscreenSectionController");

    for (NSString *selectorName in delegateSelectors) {
        SEL selector = NSSelectorFromString(selectorName);
        if (![overlayView respondsToSelector:selector])
            continue;

        id delegate = ((id (*)(id, SEL))objc_msgSend)(overlayView, selector);
        if (!delegate)
            continue;

        if (!sectionControllerClass || [delegate isKindOfClass:sectionControllerClass]) {
            return delegate;
        }
    }

    return nil;
}

static NSString *SPKStringFromValue(id value) {
    if (!value || value == (id)kCFNull)
        return nil;
    if ([value isKindOfClass:[NSString class]]) {
        NSString *string = (NSString *)value;
        return string.length > 0 ? string : nil;
    }
    if ([value respondsToSelector:@selector(stringValue)]) {
        NSString *string = [value stringValue];
        return string.length > 0 ? string : nil;
    }
    return [[value description] length] > 0 ? [value description] : nil;
}

static id SPKStoryMediaFromAnyObject(id object) {
    if (!object)
        return nil;
    id candidate = SPKFirstObjectForSelectors(object, @[ @"media", @"mediaItem", @"storyItem", @"item", @"model" ]);
    return candidate ?: object;
}

static BOOL SPKResolveStoryContextFromOverlay(UIView *overlayView, id *outMarkTarget, id *outSectionController, id *outMedia) {
    SPKStoryContext *sharedContext = SPKStoryContextFromOverlay(overlayView);
    if (sharedContext) {
        if (outMarkTarget)
            *outMarkTarget = sharedContext.markSeenTarget;
        if (outSectionController)
            *outSectionController = sharedContext.sectionController;
        if (outMedia)
            *outMedia = sharedContext.media;
        return (sharedContext.media != nil);
    }

    if (!overlayView)
        return NO;

    SEL markSelector = NSSelectorFromString(@"fullscreenSectionController:didMarkItemAsSeen:");
    UIViewController *viewerController = [SPKUtils nearestViewControllerForView:overlayView];

    id sectionController = SPKStorySectionControllerFromOverlayView(overlayView);
    id markTarget = nil;
    id sectionDelegate = SPKObjectForSelector(sectionController, @"delegate");
    if (sectionDelegate && [sectionDelegate respondsToSelector:markSelector]) {
        markTarget = sectionDelegate;
    } else if (viewerController && [viewerController respondsToSelector:markSelector]) {
        markTarget = viewerController;
    } else {
        id overlayAncestor = SPKObjectForSelector(overlayView, @"_viewControllerForAncestor");
        if (overlayAncestor && [overlayAncestor respondsToSelector:markSelector]) {
            markTarget = overlayAncestor;
        }
    }

    if (!sectionController && markTarget) {
        sectionController = SPKFirstObjectForSelectors(markTarget, @[ @"currentSectionController" ]);
        if (!sectionController) {
            sectionController = [SPKUtils getIvarForObj:markTarget name:"_currentSectionController"];
        }
    }

    id media = SPKFirstObjectForSelectors(sectionController, @[ @"currentStoryItem", @"currentItem", @"item" ]);
    if (!media)
        media = SPKFirstObjectForSelectors(markTarget, @[ @"currentStoryItem", @"currentItem", @"item" ]);
    if (!media && viewerController)
        media = SPKFirstObjectForSelectors(viewerController, @[ @"currentStoryItem", @"currentItem", @"item" ]);
    media = SPKStoryMediaFromAnyObject(media);

    if (outMarkTarget)
        *outMarkTarget = markTarget;
    if (outSectionController)
        *outSectionController = sectionController;
    if (outMedia)
        *outMedia = media;

    return (media != nil);
}

static void SPKAdvanceStoryAfterManualSeenIfNeeded(UIView *overlayView, NSString *advancePrefKey) {
    SPKStoryContext *sharedContext = SPKStoryContextFromOverlay(overlayView);
    if (sharedContext) {
        SPKStoryAdvanceContextIfNeeded(sharedContext, advancePrefKey);
        return;
    }

    if (advancePrefKey.length == 0 || ![SPKUtils getBoolPref:advancePrefKey])
        return;

    id sectionController = SPKStorySectionControllerFromOverlayView(overlayView);
    if (!sectionController)
        return;

    SPKForceStoryAutoAdvance = YES;
    BOOL advanced = NO;
    SEL advanceSelector = NSSelectorFromString(@"advanceToNextItemWithNavigationAction:");
    if ([sectionController respondsToSelector:advanceSelector]) {
        ((void (*)(id, SEL, NSInteger))objc_msgSend)(sectionController, advanceSelector, 1);
        advanced = YES;
    }

    if (!advanced) {
        advanceSelector = NSSelectorFromString(@"storyPlayerMediaViewDidPlayToEnd:");
        if ([sectionController respondsToSelector:advanceSelector]) {
            id mediaView = [SPKUtils getIvarForObj:sectionController name:"_mediaView"];
            if (!mediaView)
                mediaView = [SPKUtils getIvarForObj:overlayView name:"_mediaView"];
            ((void (*)(id, SEL, id))objc_msgSend)(sectionController, advanceSelector, mediaView);
        }
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        SPKForceStoryAutoAdvance = NO;
    });
}

// Forward declaration — implemented in StoryMentions.x
extern void SPKPresentStoryMentionsSheet(UIView *overlayView);

static void SPKMarkCurrentStoryAsSeenFromOverlayWithAdvancePref(UIView *overlayView, NSString *advancePrefKey) {
    if (!overlayView)
        return;

    SPKStoryContext *sharedContext = SPKStoryContextFromOverlay(overlayView);
    if (sharedContext) {
        if (!sharedContext.markSeenTarget || !sharedContext.sectionController || !sharedContext.media) {
            SPKNotify(kSPKNotificationStoryMarkSeen, @"Unable to mark story as seen", nil, @"error_filled", SPKNotificationToneError);
            return;
        }
        if (!SPKStoryMarkContextAsSeen(sharedContext)) {
            SPKNotify(kSPKNotificationStoryMarkSeen, @"Unable to mark story as seen", nil, @"error_filled", SPKNotificationToneError);
            return;
        }
        SPKStoryAdvanceContextIfNeeded(sharedContext, advancePrefKey);
        SPKNotify(kSPKNotificationStoryMarkSeen, @"Marked story as seen", nil, @"circle_check_filled", SPKNotificationToneSuccess);
        return;
    }

    id markTarget = nil;
    id sectionController = nil;
    id media = nil;
    BOOL resolved = SPKResolveStoryContextFromOverlay(overlayView, &markTarget, &sectionController, &media);
    if (!markTarget || !sectionController || !media) {
        SPKNotify(kSPKNotificationStoryMarkSeen, @"Unable to mark story as seen", nil, @"error_filled", SPKNotificationToneError);
        return;
    }

    SEL markSelector = NSSelectorFromString(@"fullscreenSectionController:didMarkItemAsSeen:");
    SPKForcedStorySeenMediaPK = [SPKStoryMediaIdentifier(media) copy];
    SPKForceMarkStoryAsSeen = YES;
    @try {
        ((void (*)(id, SEL, id, id))objc_msgSend)(markTarget, markSelector, sectionController, media);
    } @finally {
        SPKForceMarkStoryAsSeen = NO;
        SPKForcedStorySeenMediaPK = nil;
    }

    if (resolved) {
        SPKAdvanceStoryAfterManualSeenIfNeeded(overlayView, advancePrefKey);
    }

    SPKNotify(kSPKNotificationStoryMarkSeen, @"Marked story as seen", nil, @"circle_check_filled", SPKNotificationToneSuccess);
}

static void SPKMarkCurrentStoryAsSeenFromOverlay(UIView *overlayView) {
    SPKMarkCurrentStoryAsSeenFromOverlayWithAdvancePref(overlayView, @"stories_advance_on_manual_seen");
}

void SPKMarkStoryAsSeenForViewWithAdvancePref(UIView *view, NSString *advancePrefKey) {
    UIView *walker = view;
    for (NSInteger depth = 0; walker && depth < 24; depth++, walker = walker.superview) {
        if ([walker isKindOfClass:%c(IGStoryFullscreenOverlayView)]) {
            SPKMarkCurrentStoryAsSeenFromOverlayWithAdvancePref(walker, advancePrefKey);
            return;
        }
    }
}

UIView *SPKActiveStoryOverlayForInteractions(void) {
    return SPKStoryActiveOverlay() ?: SPKActiveStoryOverlayView;
}

%group SPKStorySeenButtonHooks

%hook IGStoryFullscreenOverlayView
- (void)layoutSubviews {
    %orig;
    SPK_PERF_SCOPE(@"StorySeenButtons.layoutSubviews");

    UIView *overlayView = (UIView *)self;
    SPKActiveStoryOverlayView = overlayView;
    SPKStorySetActiveOverlay(overlayView);
    SPKEnsureStoryOverlayAlphaObserver(overlayView);

    UIButton *seenButton = (UIButton *)[(UIView *)self viewWithTag:kSPKStorySeenButtonTag];
    if (SPKOverlayIsDirectVisualOverlay((UIView *)self)) {
        [seenButton removeFromSuperview];
        SPKRemoveStoryMentionsButton(overlayView);
        UIView *footerContainer = SPKStoryFooterContainerFromOverlay(overlayView);
        if (footerContainer) {
            SPKUpdateStoryButtonsAlpha(overlayView, footerContainer.alpha);
        }
        return;
    }

    SPKStoryContext *storyContext = SPKStoryContextFromOverlay(overlayView);
    BOOL showSeenButton = SPKStoryManualSeenAppliesToContext(storyContext);
    if (!showSeenButton && SPKManualStorySeenEnabled() && SPKStoryManualSeenListContainsUser(SPKStoryUserPKFromMediaObject(storyContext.media), YES)) {
        static NSMutableSet<NSString *> *autoSeenMarked;
        static dispatch_once_t autoSeenOnceToken;
        dispatch_once(&autoSeenOnceToken, ^{
            autoSeenMarked = [NSMutableSet set];
        });
        NSString *mediaIdentifier = SPKStoryMediaIdentifierForContext(storyContext);
        if (mediaIdentifier.length > 0 && ![autoSeenMarked containsObject:mediaIdentifier]) {
            [autoSeenMarked addObject:mediaIdentifier];
            SPKStoryMarkContextAsSeen(storyContext);
        }
    }
    if (!showSeenButton) {
        [seenButton removeFromSuperview];
        UIView *footerContainer = SPKStoryFooterContainerFromOverlay(overlayView);
        if (footerContainer) {
            SPKUpdateStoryButtonsAlpha(overlayView, footerContainer.alpha);
        }
    }

    if (showSeenButton && !seenButton) {
        seenButton = SPKStorySeenButtonWithTag((UIView *)self, kSPKStorySeenButtonTag);
        [seenButton addTarget:self action:@selector(spk_storySeenButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
        UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(spk_storySeenButtonLongPressed:)];
        longPress.minimumPressDuration = 0.5;
        [seenButton addGestureRecognizer:longPress];

        UIImage *seenImage = [SPKAssetUtils instagramIconNamed:kSPKSeenMessagesBarIconResource pointSize:24.0];
        SPKSetSeenButtonImage(seenButton, seenImage, @"Story seen custom icon assigned");
    }
    if (showSeenButton) {
        SPKApplyStorySeenButtonStyle(seenButton);
    }

    UIButton *storyActionButton = (UIButton *)[overlayView viewWithTag:kSPKStoriesActionButtonTag];
    BOOL actionVisible = [storyActionButton isKindOfClass:[UIButton class]] && !storyActionButton.hidden && storyActionButton.superview == overlayView && CGRectGetWidth(storyActionButton.frame) > 0.0 && CGRectGetHeight(storyActionButton.frame) > 0.0;
    CGRect baseFrame = SPKStorySeenBaseFrame(overlayView);
    CGFloat size = CGRectGetWidth(baseFrame);
    if (actionVisible) {
        size = CGRectGetWidth(storyActionButton.frame);
    }
    if (size <= 0.0)
        size = 44.0;

    CGFloat spacingReduction = 2.0;
    CGFloat y = actionVisible ? CGRectGetMinY(storyActionButton.frame) : CGRectGetMinY(baseFrame);
    CGFloat nextX = actionVisible
                        ? (CGRectGetMinX(storyActionButton.frame) - size + spacingReduction)
                        : CGRectGetMinX(baseFrame);

    if (showSeenButton && seenButton) {
        seenButton.frame = CGRectMake(nextX, y, size, size);
        [overlayView bringSubviewToFront:seenButton];
        nextX -= (size - spacingReduction);
    } else if (seenButton) {
        [seenButton removeFromSuperview];
        seenButton = nil;
    }

    SPKUpdateStoryMentionsButton(overlayView, nextX, y, size);

    UIView *footerContainer = SPKStoryFooterContainerFromOverlay(overlayView);
    if (footerContainer) {
        SPKUpdateStoryButtonsAlpha(overlayView, footerContainer.alpha);
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey, id> *)change context:(void *)context {
    if (context == kSPKStoryOverlayAlphaObserverContext && [keyPath isEqualToString:@"alpha"]) {
        CGFloat alpha = 1.0;
        id newAlphaValue = change[NSKeyValueChangeNewKey];
        if ([newAlphaValue respondsToSelector:@selector(floatValue)]) {
            alpha = [newAlphaValue floatValue];
        } else if ([object isKindOfClass:[UIView class]]) {
            alpha = ((UIView *)object).alpha;
        }
        SPKUpdateStoryButtonsAlpha((UIView *)self, alpha);
        return;
    }

    %orig(keyPath, object, change, context);
}

- (void)dealloc {
    SPKRemoveStoryOverlayAlphaObserverIfNeeded((UIView *)self);
    if (SPKStoryActiveOverlay() == (UIView *)self) {
        SPKStorySetActiveOverlay(nil);
    }
    if (SPKActiveStoryOverlayView == (UIView *)self) {
        SPKActiveStoryOverlayView = nil;
    }
    %orig;
}

%new - (void)spk_storySeenButtonTapped:(UIButton *)sender {
(void)sender;
SPKPlayButtonTappedHaptic();
SPKMarkCurrentStoryAsSeenFromOverlay((UIView *)self);
}

%new - (void)spk_storySeenButtonLongPressed:(UILongPressGestureRecognizer *)gesture {
if (gesture.state != UIGestureRecognizerStateBegan)
    return;
SPKPlayButtonTappedHaptic();
SPKStoryContext *context = SPKStoryContextFromOverlay((UIView *)self);
NSString *title = SPKStoryCurrentUserRuleConfirmationTitle(context);
NSString *message = SPKStoryCurrentUserRuleConfirmationMessage(context);
if (title.length == 0 || message.length == 0) {
    SPKNotify(kSPKNotificationStorySeenUserRule, @"Story user not found", nil, @"error_filled", SPKNotificationToneError);
    return;
}
[SPKUtils
    showConfirmation:^{
        NSString *notificationTitle = nil;
        NSString *notificationSubtitle = nil;
        if (!SPKStoryToggleCurrentUserRule(context, &notificationTitle, &notificationSubtitle)) {
            SPKNotify(kSPKNotificationStorySeenUserRule, @"Story user not found", nil, @"error_filled", SPKNotificationToneError);
            return;
        }
        SPKNotify(kSPKNotificationStorySeenUserRule, notificationTitle, notificationSubtitle, @"circle_check_filled", SPKNotificationToneSuccess);
        [(UIView *)self setNeedsLayout];
    }
               title:title
             message:message];
}

%end

void SPKInstallStorySeenButtonHooksIfNeeded(void) {
    if (!SPKStorySeenHooksNeeded())
        return;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        %init(SPKStorySeenButtonHooks);
    });
}
