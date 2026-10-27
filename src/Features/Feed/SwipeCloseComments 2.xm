#import "../../Utils.h"

#import <objc/message.h>
#import <objc/runtime.h>

static char kSPKSwipeCloseCommentsInstalledKey;
static char kSPKSwipeCloseCommentsTargetKey;

static NSString *const kSPKSwipeCloseCommentsDirectionKey = @"general_comments_swipe_close_direction";
static NSString *const kSPKSwipeCloseCommentsDirectionLeft = @"left";
static NSString *const kSPKSwipeCloseCommentsDirectionRight = @"right";
static NSString *const kSPKSwipeCloseCommentsDirectionBoth = @"both";

typedef NS_OPTIONS(NSUInteger, SPKSwipeCloseCommentsDirection) {
    SPKSwipeCloseCommentsDirectionLeft = 1 << 0,
    SPKSwipeCloseCommentsDirectionRight = 1 << 1,
};

static CGFloat const kSPKCommentsSwipeMinimumHorizontalDistance = 8.0;
static CGFloat const kSPKCommentsSwipeCommitProgress = 0.3;
static CGFloat const kSPKCommentsSwipeVelocityCommitMinimumDistance = 70.0;
static CGFloat const kSPKCommentsSwipeCommitVelocity = 800.0;

static SPKSwipeCloseCommentsDirection SPKSwipeCloseCommentsDirectionFromPref(void) {
    NSString *value = [SPKUtils getStringPref:kSPKSwipeCloseCommentsDirectionKey];
    if ([value isEqualToString:kSPKSwipeCloseCommentsDirectionLeft]) {
        return SPKSwipeCloseCommentsDirectionLeft;
    }
    if ([value isEqualToString:kSPKSwipeCloseCommentsDirectionRight]) {
        return SPKSwipeCloseCommentsDirectionRight;
    }
    if ([value isEqualToString:kSPKSwipeCloseCommentsDirectionBoth]) {
        return SPKSwipeCloseCommentsDirectionLeft | SPKSwipeCloseCommentsDirectionRight;
    }
    return SPKSwipeCloseCommentsDirectionLeft | SPKSwipeCloseCommentsDirectionRight;
}

static NSString *SPKCommentsSwipeDescribe(id object) {
    if (!object)
        return @"nil";
    return [NSString stringWithFormat:@"%@<%p>", NSStringFromClass([object class]), object];
}

static NSString *SPKCommentsSwipeStateName(UIGestureRecognizerState state) {
    switch (state) {
    case UIGestureRecognizerStatePossible:
        return @"possible";
    case UIGestureRecognizerStateBegan:
        return @"began";
    case UIGestureRecognizerStateChanged:
        return @"changed";
    case UIGestureRecognizerStateEnded:
        return @"ended";
    case UIGestureRecognizerStateCancelled:
        return @"cancelled";
    case UIGestureRecognizerStateFailed:
        return @"failed";
    default:
        return [NSString stringWithFormat:@"unknown(%ld)", (long)state];
    }
}

static CGFloat SPKCommentsSwipeSignedHorizontalProgress(CGFloat translationX, SPKSwipeCloseCommentsDirection direction) {
    if ((direction & SPKSwipeCloseCommentsDirectionLeft) && translationX < 0.0) {
        return -translationX;
    }
    if ((direction & SPKSwipeCloseCommentsDirectionRight) && translationX > 0.0) {
        return translationX;
    }
    return 0.0;
}

static CGFloat SPKCommentsSwipeSignedHorizontalVelocity(CGFloat velocityX, SPKSwipeCloseCommentsDirection direction) {
    if ((direction & SPKSwipeCloseCommentsDirectionLeft) && velocityX < 0.0) {
        return -velocityX;
    }
    if ((direction & SPKSwipeCloseCommentsDirectionRight) && velocityX > 0.0) {
        return velocityX;
    }
    return 0.0;
}

static NSNumber *SPKCommentsSwipeNumberFromSelector(id object, SEL selector) {
    if (!object || ![object respondsToSelector:selector])
        return nil;
    @try {
        double (*sendDouble)(id, SEL) = (double (*)(id, SEL))objc_msgSend;
        return @(sendDouble(object, selector));
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

static NSNumber *SPKCommentsSwipeUnsignedNumberFromSelector(id object, SEL selector) {
    if (!object || ![object respondsToSelector:selector])
        return nil;
    @try {
        unsigned long long (*sendUnsigned)(id, SEL) = (unsigned long long (*)(id, SEL))objc_msgSend;
        return @(sendUnsigned(object, selector));
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

static NSNumber *SPKCommentsSwipeBoolNumberFromSelector(id object, SEL selector) {
    if (!object || ![object respondsToSelector:selector])
        return nil;
    @try {
        BOOL (*sendBool)(id, SEL) = (BOOL (*)(id, SEL))objc_msgSend;
        return @(sendBool(object, selector));
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

static BOOL SPKCommentsSwipeStringLooksCommentRelated(NSString *value) {
    return [value rangeOfString:@"comment" options:NSCaseInsensitiveSearch].location != NSNotFound;
}

static BOOL SPKCommentsSwipeStringLooksShareRelated(NSString *value) {
    if (value.length == 0)
        return NO;
    NSArray<NSString *> *patterns = @[
        @"share",
        @"IGExternalShare",
        @"ShareSheet",
        @"Copy link",
        @"WhatsApp",
        @"Add to story"
    ];
    for (NSString *pattern in patterns) {
        if ([value rangeOfString:pattern options:NSCaseInsensitiveSearch].location != NSNotFound) {
            return YES;
        }
    }
    return NO;
}

static BOOL SPKCommentsSwipeViewTreeLooksShareRelated(UIView *view, NSUInteger depth, NSUInteger *visitedCount, NSString **reason) {
    if (!view || depth > 8 || *visitedCount > 180) {
        return NO;
    }
    *visitedCount += 1;

    NSString *className = NSStringFromClass([view class]);
    if (SPKCommentsSwipeStringLooksShareRelated(className)) {
        if (reason)
            *reason = [NSString stringWithFormat:@"view class %@", className];
        return YES;
    }

    NSString *identifier = view.accessibilityIdentifier;
    if (SPKCommentsSwipeStringLooksShareRelated(identifier)) {
        if (reason)
            *reason = [NSString stringWithFormat:@"view accessibilityIdentifier %@", identifier];
        return YES;
    }

    NSString *label = view.accessibilityLabel;
    if (SPKCommentsSwipeStringLooksShareRelated(label)) {
        if (reason)
            *reason = [NSString stringWithFormat:@"view accessibilityLabel %@", label];
        return YES;
    }

    UIResponder *responder = view.nextResponder;
    if (responder && SPKCommentsSwipeStringLooksShareRelated(NSStringFromClass([responder class]))) {
        if (reason)
            *reason = [NSString stringWithFormat:@"nextResponder %@", NSStringFromClass([responder class])];
        return YES;
    }

    for (UIView *subview in view.subviews) {
        if (SPKCommentsSwipeViewTreeLooksShareRelated(subview, depth + 1, visitedCount, reason)) {
            return YES;
        }
    }

    return NO;
}

static BOOL SPKCommentsSwipeControllerTreeLooksShareRelated(UIViewController *controller, NSUInteger depth, NSString **reason) {
    if (!controller || depth > 5) {
        return NO;
    }

    NSString *className = NSStringFromClass([controller class]);
    if (SPKCommentsSwipeStringLooksShareRelated(className)) {
        if (reason)
            *reason = [NSString stringWithFormat:@"controller class %@", className];
        return YES;
    }

    NSString *title = controller.title;
    if (SPKCommentsSwipeStringLooksShareRelated(title)) {
        if (reason)
            *reason = [NSString stringWithFormat:@"controller title %@", title];
        return YES;
    }

    for (UIViewController *child in controller.childViewControllers) {
        if (SPKCommentsSwipeControllerTreeLooksShareRelated(child, depth + 1, reason)) {
            return YES;
        }
    }

    UIViewController *presented = controller.presentedViewController;
    if (presented && presented != controller) {
        if (SPKCommentsSwipeControllerTreeLooksShareRelated(presented, depth + 1, reason)) {
            return YES;
        }
    }

    return NO;
}

static BOOL SPKCommentsSwipeViewTreeLooksCommentRelated(UIView *view, NSUInteger depth, NSUInteger *visitedCount, NSString **reason) {
    if (!view || depth > 8 || *visitedCount > 180) {
        return NO;
    }
    *visitedCount += 1;

    NSString *className = NSStringFromClass([view class]);
    if (SPKCommentsSwipeStringLooksCommentRelated(className)) {
        if (reason)
            *reason = [NSString stringWithFormat:@"view class %@", className];
        return YES;
    }

    NSString *identifier = view.accessibilityIdentifier;
    if (SPKCommentsSwipeStringLooksCommentRelated(identifier)) {
        if (reason)
            *reason = [NSString stringWithFormat:@"view accessibilityIdentifier %@", identifier];
        return YES;
    }

    NSString *label = view.accessibilityLabel;
    if (SPKCommentsSwipeStringLooksCommentRelated(label)) {
        if (reason)
            *reason = [NSString stringWithFormat:@"view accessibilityLabel %@", label];
        return YES;
    }

    UIResponder *responder = view.nextResponder;
    if (responder && SPKCommentsSwipeStringLooksCommentRelated(NSStringFromClass([responder class]))) {
        if (reason)
            *reason = [NSString stringWithFormat:@"nextResponder %@", NSStringFromClass([responder class])];
        return YES;
    }

    for (UIView *subview in view.subviews) {
        if (SPKCommentsSwipeViewTreeLooksCommentRelated(subview, depth + 1, visitedCount, reason)) {
            return YES;
        }
    }

    return NO;
}

static BOOL SPKCommentsSwipeControllerTreeLooksCommentRelated(UIViewController *controller, NSUInteger depth, NSString **reason) {
    if (!controller || depth > 5) {
        return NO;
    }

    NSString *className = NSStringFromClass([controller class]);
    if (SPKCommentsSwipeStringLooksCommentRelated(className)) {
        if (reason)
            *reason = [NSString stringWithFormat:@"controller class %@", className];
        return YES;
    }

    NSString *title = controller.title;
    if (SPKCommentsSwipeStringLooksCommentRelated(title)) {
        if (reason)
            *reason = [NSString stringWithFormat:@"controller title %@", title];
        return YES;
    }

    for (UIViewController *child in controller.childViewControllers) {
        if (SPKCommentsSwipeControllerTreeLooksCommentRelated(child, depth + 1, reason)) {
            return YES;
        }
    }

    UIViewController *presented = controller.presentedViewController;
    if (presented && presented != controller) {
        if (SPKCommentsSwipeControllerTreeLooksCommentRelated(presented, depth + 1, reason)) {
            return YES;
        }
    }

    return NO;
}

static UIView *SPKCommentsSwipeContentView(UIViewController *controller) {
    UIView *root = controller.view;
    if ([root.accessibilityIdentifier isEqualToString:@"ig-partial-modal-sheet-view-controller-content"]) {
        return root;
    }

    NSMutableArray<UIView *> *queue = [NSMutableArray arrayWithObject:root ?: [UIView new]];
    NSUInteger index = 0;
    while (index < queue.count && index < 160) {
        UIView *view = queue[index++];
        if ([view.accessibilityIdentifier isEqualToString:@"ig-partial-modal-sheet-view-controller-content"]) {
            return view;
        }
        [queue addObjectsFromArray:view.subviews];
    }
    return root;
}

static UIView *SPKCommentsSwipeSheetContainerView(UIViewController *controller, UIView *contentView) {
    if (!controller)
        return contentView;

    UIView *root = controller.view;
    CGRect rootWindowFrame = root ? [root convertRect:root.bounds toView:nil] : CGRectZero;
    CGFloat screenHeight = CGRectGetHeight([UIScreen mainScreen].bounds);
    if (screenHeight < 1.0)
        screenHeight = CGRectGetHeight(rootWindowFrame);

    UIView *bestView = nil;
    UIView *view = contentView;
    while (view && view != root) {
        CGRect windowFrame = [view convertRect:view.bounds toView:nil];
        BOOL hasUsefulSize = CGRectGetHeight(windowFrame) > 80.0 && CGRectGetWidth(windowFrame) > 80.0;
        BOOL notFullScreenWrapper = CGRectGetMinY(windowFrame) > 8.0 || CGRectGetHeight(windowFrame) < screenHeight * 0.94;
        if (hasUsefulSize && notFullScreenWrapper) {
            bestView = view;
            break;
        }
        view = view.superview;
    }

    if (bestView) {
        return bestView;
    }

    view = contentView;
    while (view.superview && view.superview != root) {
        view = view.superview;
    }
    return contentView ?: view ?
                               : root;
}

static CGFloat SPKCommentsSwipeDismissDistanceForView(UIViewController *controller, UIView *sheetView) {
    CGRect rootFrame = [controller.view convertRect:controller.view.bounds toView:nil];
    CGRect sheetFrame = [sheetView convertRect:sheetView.bounds toView:nil];
    CGFloat screenHeight = CGRectGetHeight(rootFrame);
    if (screenHeight < 1.0) {
        screenHeight = CGRectGetHeight([UIScreen mainScreen].bounds);
    }

    CGFloat distanceToMoveTopBelowScreen = screenHeight - CGRectGetMinY(sheetFrame) + 36.0;
    return MAX(distanceToMoveTopBelowScreen, 180.0);
}

@interface SPKSwipeCloseCommentsTarget : NSObject <UIGestureRecognizerDelegate>
@property (nonatomic, weak) UIViewController *controller;
@property (nonatomic) SPKSwipeCloseCommentsDirection direction;
@property (nonatomic) BOOL hasLoggedSheetState;
@property (nonatomic, weak) UIView *activeSheetView;
@property (nonatomic) CGAffineTransform originalTransform;
@property (nonatomic) CGFloat activeDismissDistance;
@end

@implementation SPKSwipeCloseCommentsTarget

- (void)logSheetStateIfNeededForController:(UIViewController *)controller contentView:(UIView *)contentView {
    if (self.hasLoggedSheetState) {
        return;
    }
    self.hasLoggedSheetState = YES;

    SPKLog(@"General", @"[Sparkle CommentsSwipe] Sheet state controller=%@ content=%@ target=%@ sheetOffset=%@ disablePanToClose=%@ disableVerticalPan=%@ shouldSuppressDismiss=%@",
           SPKCommentsSwipeDescribe(controller),
           SPKCommentsSwipeDescribe(contentView),
           SPKCommentsSwipeUnsignedNumberFromSelector(controller, @selector(targetSheetState)) ?: @"n/a",
           SPKCommentsSwipeNumberFromSelector(controller, @selector(sheetOffset)) ?: @"n/a",
           SPKCommentsSwipeBoolNumberFromSelector(controller, @selector(disablePanToClose)) ?: @"n/a",
           SPKCommentsSwipeBoolNumberFromSelector(controller, @selector(disableVerticalPan)) ?: @"n/a",
           SPKCommentsSwipeBoolNumberFromSelector(controller, @selector(shouldSuppressDismiss)) ?: @"n/a");
}

- (void)handlePan:(UIPanGestureRecognizer *)gesture {
    UIView *contentView = gesture.view;
    UIViewController *controller = self.controller ?: [SPKUtils viewControllerForView:contentView];
    CGPoint translation = [gesture translationInView:contentView];
    CGPoint velocity = [gesture velocityInView:contentView];

    CGFloat verticalTranslation = SPKCommentsSwipeSignedHorizontalProgress(translation.x, self.direction);
    CGFloat verticalVelocity = SPKCommentsSwipeSignedHorizontalVelocity(velocity.x, self.direction);

    if (gesture.state == UIGestureRecognizerStateBegan) {
        self.hasLoggedSheetState = NO;
        [self logSheetStateIfNeededForController:controller contentView:contentView];
        self.activeSheetView = SPKCommentsSwipeSheetContainerView(controller, contentView);
        self.originalTransform = self.activeSheetView.transform;
        self.activeDismissDistance = SPKCommentsSwipeDismissDistanceForView(controller, self.activeSheetView);
        CGRect sheetWindowFrame = [self.activeSheetView convertRect:self.activeSheetView.bounds toView:nil];
        CGRect contentWindowFrame = [contentView convertRect:contentView.bounds toView:nil];
        CGRect rootWindowFrame = [controller.view convertRect:controller.view.bounds toView:nil];
        SPKLog(@"General", @"[Sparkle CommentsSwipe] Interactive begin sheet=%@ sheetFrame=%@ contentFrame=%@ rootFrame=%@ dismissDistance=%.1f originalTransform=%@",
               SPKCommentsSwipeDescribe(self.activeSheetView),
               NSStringFromCGRect(sheetWindowFrame),
               NSStringFromCGRect(contentWindowFrame),
               NSStringFromCGRect(rootWindowFrame),
               self.activeDismissDistance,
               NSStringFromCGAffineTransform(self.originalTransform));
    }

    UIView *sheetView = self.activeSheetView ?: SPKCommentsSwipeSheetContainerView(controller, contentView);
    CGFloat clampedTranslation = MAX(0.0, MIN(verticalTranslation, self.activeDismissDistance));
    CGFloat progress = self.activeDismissDistance > 1.0 ? clampedTranslation / self.activeDismissDistance : 0.0;

    BOOL shouldLog = gesture.state == UIGestureRecognizerStateBegan ||
                     gesture.state == UIGestureRecognizerStateEnded ||
                     gesture.state == UIGestureRecognizerStateCancelled ||
                     gesture.state == UIGestureRecognizerStateFailed;
    if (shouldLog) {
        SPKLog(@"General", @"[Sparkle CommentsSwipe] Interactive pan state=%@ rawX=%.1f rawVX=%.1f mappedY=%.1f mappedVY=%.1f progress=%.2f controller=%@ sheet=%@",
               SPKCommentsSwipeStateName(gesture.state),
               translation.x,
               velocity.x,
               clampedTranslation,
               verticalVelocity,
               progress,
               SPKCommentsSwipeDescribe(controller),
               SPKCommentsSwipeDescribe(sheetView));
    }

    BOOL finished = gesture.state == UIGestureRecognizerStateEnded ||
                    gesture.state == UIGestureRecognizerStateCancelled ||
                    gesture.state == UIGestureRecognizerStateFailed;
    if (!finished) {
        sheetView.transform = CGAffineTransformTranslate(self.originalTransform, 0.0, clampedTranslation);
        return;
    }

    BOOL distanceCommitted = progress >= kSPKCommentsSwipeCommitProgress;
    BOOL velocityCommitted = clampedTranslation >= kSPKCommentsSwipeVelocityCommitMinimumDistance && verticalVelocity >= kSPKCommentsSwipeCommitVelocity;
    BOOL committed = gesture.state == UIGestureRecognizerStateEnded && (distanceCommitted || velocityCommitted);
    if (!committed) {
        [UIView animateWithDuration:0.24
                              delay:0.0
                            options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
                         animations:^{
                             sheetView.transform = self.originalTransform;
                         }
                         completion:nil];
        SPKLog(@"General", @"[Sparkle CommentsSwipe] Interactive cancel progress=%.2f translationY=%.1f velocityY=%.1f distanceCommitted=%d velocityCommitted=%d",
               progress,
               clampedTranslation,
               verticalVelocity,
               distanceCommitted,
               velocityCommitted);
        return;
    }

    SPKLog(@"General", @"[Sparkle CommentsSwipe] Interactive commit progress=%.2f translationY=%.1f velocityY=%.1f distanceCommitted=%d velocityCommitted=%d usingNativeDismiss=1",
           progress,
           clampedTranslation,
           verticalVelocity,
           distanceCommitted,
           velocityCommitted);

    sheetView.userInteractionEnabled = NO;
    [controller dismissViewControllerAnimated:YES
                                   completion:^{
                                       sheetView.userInteractionEnabled = YES;
                                       sheetView.transform = self.originalTransform;
                                   }];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    (void)gestureRecognizer;
    UIView *view = touch.view;
    while (view) {
        if ([view isKindOfClass:[UIControl class]]) {
            return NO;
        }
        view = view.superview;
    }
    return YES;
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    if (![gestureRecognizer isKindOfClass:[UIPanGestureRecognizer class]]) {
        return YES;
    }

    UIPanGestureRecognizer *pan = (UIPanGestureRecognizer *)gestureRecognizer;
    CGPoint translation = [pan translationInView:pan.view];
    CGPoint velocity = [pan velocityInView:pan.view];
    CGFloat allowedProgress = SPKCommentsSwipeSignedHorizontalProgress(translation.x, self.direction);
    CGFloat allowedVelocity = SPKCommentsSwipeSignedHorizontalVelocity(velocity.x, self.direction);
    BOOL horizontalEnough = fabs(velocity.x) > fabs(velocity.y) * 1.15 || fabs(translation.x) > fabs(translation.y) * 1.15;
    BOOL shouldBegin = horizontalEnough && (allowedProgress >= kSPKCommentsSwipeMinimumHorizontalDistance || allowedVelocity > 160.0);

    SPKLog(@"General", @"[Sparkle CommentsSwipe] Pan shouldBegin=%d translation=(%.1f, %.1f) velocity=(%.1f, %.1f) allowedProgress=%.1f allowedVelocity=%.1f direction=%lu",
           shouldBegin,
           translation.x,
           translation.y,
           velocity.x,
           velocity.y,
           allowedProgress,
           allowedVelocity,
           (unsigned long)self.direction);
    return shouldBegin;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    (void)gestureRecognizer;
    (void)otherGestureRecognizer;
    return YES;
}

@end

static void SPKInstallSwipeCloseCommentsGesture(UIViewController *controller) {
    if (![SPKUtils getBoolPref:@"general_comments_swipe_close"]) {
        return;
    }

    UIView *contentView = SPKCommentsSwipeContentView(controller);
    if (!contentView) {
        SPKWarnLog(@"General", @"[Sparkle CommentsSwipe] Skipping %@: content view not found", SPKCommentsSwipeDescribe(controller));
        return;
    }

    if ([objc_getAssociatedObject(contentView, &kSPKSwipeCloseCommentsInstalledKey) boolValue]) {
        return;
    }

    NSString *excludedReason = nil;
    NSUInteger excludedVisitedCount = 0;
    if (SPKCommentsSwipeControllerTreeLooksShareRelated(controller, 0, &excludedReason) ||
        SPKCommentsSwipeViewTreeLooksShareRelated(contentView, 0, &excludedVisitedCount, &excludedReason)) {
        SPKLog(@"General", @"[Sparkle CommentsSwipe] Skipping %@ content=%@: share-sheet surface detected reason=%@ visited=%lu",
               SPKCommentsSwipeDescribe(controller),
               SPKCommentsSwipeDescribe(contentView),
               excludedReason ?: @"unknown",
               (unsigned long)excludedVisitedCount);
        return;
    }

    NSString *reason = nil;
    if (!SPKCommentsSwipeControllerTreeLooksCommentRelated(controller, 0, &reason)) {
        NSUInteger visitedCount = 0;
        if (!SPKCommentsSwipeViewTreeLooksCommentRelated(contentView, 0, &visitedCount, &reason)) {
            SPKLog(@"General", @"[Sparkle CommentsSwipe] Skipping %@ content=%@: no comment-related controller/view found, visited=%lu",
                   SPKCommentsSwipeDescribe(controller),
                   SPKCommentsSwipeDescribe(contentView),
                   (unsigned long)visitedCount);
            return;
        }
    }

    SPKSwipeCloseCommentsTarget *target = [[SPKSwipeCloseCommentsTarget alloc] init];
    target.controller = controller;
    target.direction = SPKSwipeCloseCommentsDirectionFromPref();

    if (target.direction == 0) {
        SPKWarnLog(@"General", @"[Sparkle CommentsSwipe] Skipping %@: no swipe directions enabled", SPKCommentsSwipeDescribe(controller));
        return;
    }

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:target action:@selector(handlePan:)];
    pan.delegate = target;
    pan.cancelsTouchesInView = NO;
    [contentView addGestureRecognizer:pan];

    objc_setAssociatedObject(contentView, &kSPKSwipeCloseCommentsTargetKey, target, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(contentView, &kSPKSwipeCloseCommentsInstalledKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    SPKLog(@"General", @"[Sparkle CommentsSwipe] Installed horizontal pan recognizer on content=%@ controller=%@ directionPref=%@ directionMask=%lu reason=%@ existingGestures=%lu",
           SPKCommentsSwipeDescribe(contentView),
           SPKCommentsSwipeDescribe(controller),
           [SPKUtils getStringPref:kSPKSwipeCloseCommentsDirectionKey] ?: @"both",
           (unsigned long)target.direction,
           reason ?: @"unknown",
           (unsigned long)contentView.gestureRecognizers.count);
}

%group SPKSwipeCloseCommentsHooks

%hook IGDSDefaultPartialModalSheetViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    SPKInstallSwipeCloseCommentsGesture((UIViewController *)self);

    __weak UIViewController *weakController = (UIViewController *)self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIViewController *controller = weakController;
        if (controller) {
            SPKInstallSwipeCloseCommentsGesture(controller);
        }
    });
}

%end

%end

extern "C" void SPKInstallSwipeCloseCommentsHooksIfEnabled(void) {
    if (![SPKUtils getBoolPref:@"general_comments_swipe_close"])
        return;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        SPKLog(@"General", @"[Sparkle CommentsSwipe] Installing hooks");
        %init(SPKSwipeCloseCommentsHooks);
    });
}
