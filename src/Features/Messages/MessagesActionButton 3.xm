#import <objc/runtime.h>

#import "../../Shared/ActionButton/ActionButtonCore.h"
#import "../../Shared/ActionButton/SPKActionButtonConfiguration.h"
#import "../../Utils.h"
#import "../../App/SPKPerfMeter.h"

static NSInteger const kSPKDirectActionButtonTag = 921344;
static const void *kSPKDirectActionBottomConstraintAssocKey = &kSPKDirectActionBottomConstraintAssocKey;
static const void *kSPKDirectActionTrailingConstraintAssocKey = &kSPKDirectActionTrailingConstraintAssocKey;
static const void *kSPKDirectActionWidthConstraintAssocKey = &kSPKDirectActionWidthConstraintAssocKey;
static const void *kSPKDirectActionHeightConstraintAssocKey = &kSPKDirectActionHeightConstraintAssocKey;
static const void *kSPKDirectActionButtonMediaKey = &kSPKDirectActionButtonMediaKey;

static UIView *SPKDirectOverlayView(UIViewController *controller) {
    if (!controller)
        return nil;
    id viewerContainer = [SPKUtils getIvarForObj:controller name:"_viewerContainerView"];
    if (!viewerContainer)
        viewerContainer = SPKKVCObject(controller, @"viewerContainerView");
    id overlay = SPKObjectForSelector(viewerContainer, @"overlayView");
    return [overlay isKindOfClass:[UIView class]] ? (UIView *)overlay : nil;
}

static CGFloat SPKHeightFromFrameLikeObject(id object) {
    if (!object)
        return 0.0;
    if ([object isKindOfClass:[UIView class]])
        return ((UIView *)object).frame.size.height;

    @try {
        id frameValue = [object valueForKey:@"frame"];
        if ([frameValue isKindOfClass:[NSValue class]])
            return ((NSValue *)frameValue).CGRectValue.size.height;
    } @catch (__unused NSException *exception) {
    }

    return 0.0;
}

static CGFloat SPKDirectBottomOffset(UIViewController *controller) {
    id inputView = [SPKUtils getIvarForObj:controller name:"_inputView"];
    CGFloat offset = controller.view.safeAreaInsets.bottom + 12.0;
    if (inputView)
        offset += SPKHeightFromFrameLikeObject(inputView);
    return offset;
}

static NSArray *SPKDirectVisualMessageItemsFromController(UIViewController *controller) {
    if (!controller)
        return nil;
    id dataSource = [SPKUtils getIvarForObj:controller name:"_dataSource"];
    if (!dataSource)
        dataSource = SPKKVCObject(controller, @"dataSource");
    if (!dataSource)
        return nil;

    for (NSString *key in @[ @"visualMessages", @"messages", @"items", @"visualMessageItems", @"viewerItems" ]) {
        id value = SPKObjectForSelector(dataSource, key) ?: SPKKVCObject(dataSource, key);
        if ([value isKindOfClass:[NSArray class]] || [value isKindOfClass:[NSOrderedSet class]] || [value isKindOfClass:[NSSet class]]) {
            NSArray *arr = SPKArrayFromCollection(value);
            if (arr.count > 0)
                return arr;
        }
    }

    for (Class cls = [dataSource class]; cls && cls != [NSObject class]; cls = class_getSuperclass(cls)) {
        unsigned int ivarCount = 0;
        Ivar *ivars = class_copyIvarList(cls, &ivarCount);
        for (unsigned int i = 0; i < ivarCount; i++) {
            const char *typeEncoding = ivar_getTypeEncoding(ivars[i]);
            if (typeEncoding && typeEncoding[0] == '@') {
                const char *name = ivar_getName(ivars[i]);
                id value = [SPKUtils getIvarForObj:dataSource name:name];
                if ([value isKindOfClass:[NSArray class]] || [value isKindOfClass:[NSOrderedSet class]] || [value isKindOfClass:[NSSet class]]) {
                    NSArray *arr = SPKArrayFromCollection(value);
                    if (arr.count > 1) {
                        free(ivars);
                        return arr;
                    }
                }
            }
        }
        free(ivars);
    }

    return nil;
}

static SPKActionButtonContext *SPKMessagesActionContext(UIViewController *controller) {
    SPKActionButtonContext *context = [[SPKActionButtonContext alloc] init];
    context.source = SPKActionButtonSourceDirect;
    context.controller = controller;
    context.settingsTitle = SPKActionButtonTopicTitleForSource(SPKActionButtonSourceDirect);
    context.supportedActions = SPKActionButtonSupportedActionsForSource(SPKActionButtonSourceDirect);
    context.mediaResolver = ^id(SPKActionButtonContext *resolvedContext) {
        return SPKDirectResolvedMediaFromController(resolvedContext.controller);
    };
    context.bulkMediaResolver = ^id(SPKActionButtonContext *resolvedContext) {
        return SPKDirectVisualMessageItemsFromController(resolvedContext.controller) ?: SPKDirectResolvedMediaFromController(resolvedContext.controller);
    };
    context.currentIndexResolver = ^NSInteger(SPKActionButtonContext *resolvedContext) {
        return SPKDirectCurrentIndexFromController(resolvedContext.controller);
    };
    return context;
}

static BOOL SPKDirectConstraintMatches(NSLayoutConstraint *constraint, CGFloat constant) {
    return constraint && constraint.active && ABS(constraint.constant - constant) < 0.5;
}

static BOOL SPKDirectActionButtonLayoutIsCurrent(UIButton *button, CGFloat bottomOffset) {
    if (![button isKindOfClass:[UIButton class]] || button.hidden || !button.superview)
        return NO;

    NSLayoutConstraint *bottomConstraint = objc_getAssociatedObject(button, kSPKDirectActionBottomConstraintAssocKey);
    NSLayoutConstraint *trailingConstraint = objc_getAssociatedObject(button, kSPKDirectActionTrailingConstraintAssocKey);
    NSLayoutConstraint *widthConstraint = objc_getAssociatedObject(button, kSPKDirectActionWidthConstraintAssocKey);
    NSLayoutConstraint *heightConstraint = objc_getAssociatedObject(button, kSPKDirectActionHeightConstraintAssocKey);

    return SPKDirectConstraintMatches(trailingConstraint, -10.0) &&
           SPKDirectConstraintMatches(bottomConstraint, -bottomOffset) &&
           SPKDirectConstraintMatches(widthConstraint, 44.0) &&
           SPKDirectConstraintMatches(heightConstraint, 44.0);
}

static void SPKInstallDirectActionButton(UIViewController *controller) {
    UIView *overlay = SPKDirectOverlayView(controller);
    if (!overlay)
        return;

    UIButton *button = (UIButton *)[overlay viewWithTag:kSPKDirectActionButtonTag];
    if (![SPKUtils getBoolPref:@"msgs_action_btn"]) {
        [button removeFromSuperview];
        return;
    }

    CGFloat bottomOffset = SPKDirectBottomOffset(controller);

    // Layer 1 fix: detect media change to force reconfiguration even when layout is unchanged
    id currentMedia = SPKDirectResolvedMediaFromController(controller);
    id lastMedia = button ? objc_getAssociatedObject(button, kSPKDirectActionButtonMediaKey) : nil;
    BOOL mediaChanged = (lastMedia != currentMedia);

    if (SPKDirectActionButtonLayoutIsCurrent(button, bottomOffset) && !mediaChanged)
        return;

    button = SPKActionButtonWithTag(overlay, kSPKDirectActionButtonTag);
    SPKConfigureActionButton(button, SPKMessagesActionContext(controller));

    // Store the resolved media pointer for change detection on next call
    objc_setAssociatedObject(button, kSPKDirectActionButtonMediaKey, currentMedia, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    if (button.hidden)
        return;

    CGFloat size = 44.0;
    button.translatesAutoresizingMaskIntoConstraints = NO;

    NSLayoutConstraint *bottomConstraint = objc_getAssociatedObject(button, kSPKDirectActionBottomConstraintAssocKey);
    NSLayoutConstraint *trailingConstraint = objc_getAssociatedObject(button, kSPKDirectActionTrailingConstraintAssocKey);
    NSLayoutConstraint *widthConstraint = objc_getAssociatedObject(button, kSPKDirectActionWidthConstraintAssocKey);
    NSLayoutConstraint *heightConstraint = objc_getAssociatedObject(button, kSPKDirectActionHeightConstraintAssocKey);

    if (!bottomConstraint || !trailingConstraint || !widthConstraint || !heightConstraint) {
        trailingConstraint = [button.trailingAnchor constraintEqualToAnchor:overlay.trailingAnchor constant:-10.0];
        bottomConstraint = [button.bottomAnchor constraintEqualToAnchor:overlay.bottomAnchor constant:-bottomOffset];
        widthConstraint = [button.widthAnchor constraintEqualToConstant:size];
        heightConstraint = [button.heightAnchor constraintEqualToConstant:size];
        [NSLayoutConstraint activateConstraints:@[ trailingConstraint, bottomConstraint, widthConstraint, heightConstraint ]];

        objc_setAssociatedObject(button, kSPKDirectActionBottomConstraintAssocKey, bottomConstraint, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(button, kSPKDirectActionTrailingConstraintAssocKey, trailingConstraint, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(button, kSPKDirectActionWidthConstraintAssocKey, widthConstraint, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(button, kSPKDirectActionHeightConstraintAssocKey, heightConstraint, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    trailingConstraint.constant = -10.0;
    bottomConstraint.constant = -bottomOffset;
    widthConstraint.constant = size;
    heightConstraint.constant = size;

    SPKApplyButtonStyle(button, SPKActionButtonSourceDirect);
    [overlay bringSubviewToFront:button];
}

// Reinstall now and once more on the next runloop, so the action button picks up
// the new item after `_currentVisualMessageIndex` has settled.
static void SPKDirectReinstallActionButtonSoon(UIViewController *controller) {
    if (!controller)
        return;
    SPKInstallDirectActionButton(controller);
    __weak UIViewController *weakController = controller;
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *strongController = weakController;
        if (strongController)
            SPKInstallDirectActionButton(strongController);
    });
}

%group SPKMessagesActionButtonHooks

%hook IGDirectVisualMessageViewerController
- (void)viewDidLayoutSubviews {
    %orig;
    SPK_PERF_SCOPE(@"MessagesActionButton.viewDidLayoutSubviews");
    SPKDirectReinstallActionButtonSoon((UIViewController *)self);
}

// Swiping between visual messages doesn't relayout the controller's view, so the
// layout hook above won't fire. The controller is the story-player media delegate,
// so these callbacks fire on every item change — reconfigure for the new item.
- (void)storyPlayerMediaViewDidLoad:(id)load loadSource:(id)source networkRequestSummary:(id)summary {
    %orig;
    SPKDirectReinstallActionButtonSoon((UIViewController *)self);
}

- (void)storyPlayerMediaViewDidBeginPlayback:(id)playback {
    %orig;
    SPKDirectReinstallActionButtonSoon((UIViewController *)self);
}
%end

%end

extern "C" void SPKInstallMessagesActionButtonHooksIfEnabled(void) {
    if (![SPKUtils getBoolPref:@"msgs_action_btn"])
        return;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        %init(SPKMessagesActionButtonHooks);
    });
}
