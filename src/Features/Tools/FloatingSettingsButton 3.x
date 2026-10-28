#import "../../Utils.h"
#import "../../Shared/UI/SPKChrome.h"
#import <objc/message.h>
#import <objc/runtime.h>

// A floating way back to Instagram's settings once the profile tab is hidden.
//
// That screen is reached from your own profile, and the sparkle button that
// opens Sparkle lives inside it — so hiding the profile tab closes both doors
// at once. From that toggle on, this button rides every tab and reopens them.
//
// Nothing to switch on and nothing to find: it appears exactly when the other
// route disappears, and goes away again when the tab comes back.
//
// The drag behaviour mirrors the seen bubble in Messages — move it out of the
// way, it stays where you put it, and it returns to its corner on its own.

static const void *kSPKFloatingButtonAssocKey = &kSPKFloatingButtonAssocKey;
// Set while the reader has the button somewhere of their own choosing, so
// layout leaves it alone until it returns home by itself.
static const void *kSPKFloatingButtonMovedAssocKey = &kSPKFloatingButtonMovedAssocKey;

static const CGFloat kSPKFloatingButtonDiameter = 44.0;
static const CGFloat kSPKFloatingButtonMargin = 16.0;
// Long enough to use the screen underneath, short enough that the button is
// back in its corner before you look for it again.
static const NSTimeInterval kSPKFloatingButtonReturnDelay = 4.0;

#pragma mark - Condition

static UIWindow *SPKFloatingButtonHostWindow(void) {
    UIWindow *best = nil;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]])
            continue;
        for (UIWindow *window in ((UIWindowScene *)scene).windows) {
            if (window.isHidden || window.alpha <= 0.01)
                continue;
            if (window.isKeyWindow)
                return window;
            if (!best)
                best = window;
        }
    }
    return best;
}

// True while a settings screen — Instagram's or Sparkle's — is on top.
//
// Matched the way NativeSettingsEntry matches it: the Swift class name is a
// generic specialisation, so it varies, and the title is the steadier signal.
static BOOL SPKFloatingButtonSettingsAreOpen(void) {
    UIWindow *window = SPKFloatingButtonHostWindow();
    UIViewController *top = window.rootViewController;
    while (top.presentedViewController)
        top = top.presentedViewController;

    for (UIViewController *controller in @[ top, top.childViewControllers.firstObject ?: top ]) {
        const char *name = class_getName([controller class]);
        if (name && (strstr(name, "IGSettingsHostingController") || strstr(name, "SPKSettings")))
            return YES;
        if ([controller.title isEqualToString:@"Settings and activity"])
            return YES;
        UIViewController *visible = [controller isKindOfClass:[UINavigationController class]]
            ? ((UINavigationController *)controller).topViewController
            : nil;
        if ([visible.title isEqualToString:@"Settings and activity"])
            return YES;
        const char *visibleName = visible ? class_getName([visible class]) : NULL;
        if (visibleName && (strstr(visibleName, "IGSettingsHostingController") || strstr(visibleName, "SPKSettings")))
            return YES;
    }
    return NO;
}

// One preference decides whether the button belongs on screen at all: with the
// profile tab hidden there is no route left to Settings and activity. It then
// steps aside while those settings are actually open, and comes back when they
// close — the layout pass that follows the dismissal puts it back.
static BOOL SPKFloatingButtonShouldShow(void) {
    if (![SPKUtils getBoolPref:@"interface_hide_profile_tab"])
        return NO;
    return !SPKFloatingButtonSettingsAreOpen();
}

#pragma mark - Placement


// Where the bottom chrome starts, in screen coordinates.
//
// Only the profile tab is hidden here, so the tab bar is still on screen and
// the safe area alone drops the button straight onto it — measured at 33 pt of
// overlap on a real screen.
//
// The bar is found by shape rather than by name: a wide, shallow view sitting
// against the bottom of the screen. Names change between Instagram versions and
// a name-based search already missed it once; a floating tab bar always has
// these proportions. Every window is searched, since the bar need not live in
// the same one as the button.
static CGFloat SPKFloatingButtonBottomChromeTop(UIView *view, CGFloat screenWidth, CGFloat screenBottom, NSInteger depth) {
    // Instagram's hierarchy is deep; a shallow walk stopped short of the bar and
    // reported nothing, which is how the button ended up sitting on it.
    if (!view || depth > 16)
        return CGFLOAT_MAX;

    CGFloat top = CGFLOAT_MAX;
    for (UIView *child in view.subviews) {
        if (child.isHidden || child.alpha <= 0.05)
            continue;

        CGRect frame = [child convertRect:child.bounds toView:nil];
        BOOL wide = CGRectGetWidth(frame) >= screenWidth * 0.4;
        BOOL shallow = CGRectGetHeight(frame) >= 28.0 && CGRectGetHeight(frame) <= 140.0;
        BOOL seated = CGRectGetMaxY(frame) >= screenBottom - 90.0 && CGRectGetMaxY(frame) <= screenBottom + 4.0;
        if (wide && shallow && seated)
            top = MIN(top, CGRectGetMinY(frame));

        top = MIN(top, SPKFloatingButtonBottomChromeTop(child, screenWidth, screenBottom, depth + 1));
    }
    return top;
}

// The same search, run against every window: the floating bar of iOS 26 need
// not live in the same window as the button.
static CGFloat SPKFloatingButtonBottomChromeTopInAllWindows(CGFloat screenWidth, CGFloat screenBottom) {
    CGFloat top = CGFLOAT_MAX;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]])
            continue;
        for (UIWindow *window in ((UIWindowScene *)scene).windows) {
            if (window.isHidden || window.alpha <= 0.01)
                continue;
            top = MIN(top, SPKFloatingButtonBottomChromeTop(window, screenWidth, screenBottom, 0));
        }
    }
    return top;
}

// What the visible screen reserves at the bottom.
//
// A tab bar controller adds its bar's height to the safe area of the controller
// it is showing, so the child's inset carries the bar even when the search above
// finds nothing. Two independent readings, and the higher floor of the two wins:
// missing the bar has been the recurring failure here, never clearing too much.
static CGFloat SPKFloatingButtonReservedBottomInset(UIWindow *window) {
    UIViewController *controller = window.rootViewController;
    CGFloat inset = 0.0;

    while (controller) {
        inset = MAX(inset, controller.view.safeAreaInsets.bottom);

        UIViewController *next = controller.presentedViewController;
        if (!next && [controller isKindOfClass:[UITabBarController class]])
            next = ((UITabBarController *)controller).selectedViewController;
        if (!next && [controller isKindOfClass:[UINavigationController class]])
            next = ((UINavigationController *)controller).topViewController;
        if (!next)
            next = controller.childViewControllers.lastObject;
        if (next == controller)
            break;
        controller = next;
    }
    return inset;
}

// Bottom trailing corner, clear of whatever chrome is down there.
//
// The reel action rail runs down the trailing side, so this corner is not free
// on every surface — but it is the one a thumb reaches, and the button can be
// dragged out of the way when it gets in one.
static CGPoint SPKFloatingButtonHomeCenter(UIView *host) {
    UIEdgeInsets safe = host.safeAreaInsets;
    CGFloat half = kSPKFloatingButtonDiameter / 2.0;

    CGRect screen = [host convertRect:host.bounds toView:nil];
    CGFloat floor = CGRectGetHeight(host.bounds) - safe.bottom;

    CGFloat chromeTop = SPKFloatingButtonBottomChromeTopInAllWindows(CGRectGetWidth(screen),
                                                                    CGRectGetMaxY(screen));
    if (chromeTop < CGFLOAT_MAX)
        floor = MIN(floor, chromeTop - CGRectGetMinY(screen));

    CGFloat reserved = SPKFloatingButtonReservedBottomInset((UIWindow *)host);
    if (reserved > safe.bottom)
        floor = MIN(floor, CGRectGetHeight(host.bounds) - reserved);

    return CGPointMake(CGRectGetWidth(host.bounds) - safe.right - kSPKFloatingButtonMargin - half,
                       floor - kSPKFloatingButtonMargin - half);
}

static void SPKFloatingButtonSendHome(UIView *button, BOOL animated) {
    UIView *host = button.superview;
    if (!host)
        return;

    CGPoint home = SPKFloatingButtonHomeCenter(host);
    if (!animated) {
        button.center = home;
        return;
    }
    [UIView animateWithDuration:0.32
                          delay:0.0
         usingSpringWithDamping:0.86
          initialSpringVelocity:0.0
                        options:UIViewAnimationOptionBeginFromCurrentState
                     animations:^{ button.center = home; }
                     completion:nil];
}

#pragma mark - Target

@interface SPKFloatingSettingsButtonTarget : NSObject
+ (instancetype)sharedTarget;
- (void)tapped:(id)sender;
- (void)pressedDown:(UIView *)button;
- (void)pressedUp:(UIView *)button;
- (void)panned:(UIPanGestureRecognizer *)pan;
@end

@implementation SPKFloatingSettingsButtonTarget

+ (instancetype)sharedTarget {
    static SPKFloatingSettingsButtonTarget *target;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ target = [SPKFloatingSettingsButtonTarget new]; });
    return target;
}

// Instagram's own "Settings and activity" screen, which is what the hidden
// profile tab took away. Its controller cannot be built from here — the tweak
// only ever recognises it by class name at runtime — so the app is asked to
// route to it the way it routes any internal link, which is the same engine
// SPKUtils already uses to open a profile.
//
// instagram://settings is a link the app itself carries; it is read out of the
// binary, not invented. If the route is refused, Sparkle's own settings open
// instead, so the button always leads somewhere.
static BOOL SPKFloatingButtonOpenInstagramSettings(void) {
    Class urlHandlerClass = objc_getClass("IGURLHandler");
    NSURL *settingsURL = [NSURL URLWithString:@"instagram://settings"];
    if (!urlHandlerClass || !settingsURL)
        return NO;

    id session = [SPKUtils activeUserSession];
    if (!session)
        return NO;

    UIViewController *presenter = SPKFloatingButtonHostWindow().rootViewController;
    while (presenter.presentedViewController)
        presenter = presenter.presentedViewController;

    SEL internalRoute = @selector(openInternalURL:presentationConfig:controller:animated:userSession:annotation:);
    if ([urlHandlerClass respondsToSelector:internalRoute]) {
        typedef BOOL (*OpenInternalFunc)(Class, SEL, id, id, id, BOOL, id, id);
        OpenInternalFunc route = (OpenInternalFunc)objc_msgSend;
        if (route(urlHandlerClass, internalRoute, settingsURL, nil, presenter, YES, session, nil))
            return YES;
    }

    SEL plainRoute = @selector(openURL:userSession:completionHandler:);
    if ([urlHandlerClass respondsToSelector:plainRoute]) {
        typedef void (*OpenURLFunc)(Class, SEL, id, id, id);
        OpenURLFunc route = (OpenURLFunc)objc_msgSend;
        route(urlHandlerClass, plainRoute, settingsURL, session, nil);
        return YES;
    }
    return NO;
}

- (void)pressedDown:(UIView *)button {
    [UIView animateWithDuration:0.12
                          delay:0.0
                        options:UIViewAnimationOptionBeginFromCurrentState
                     animations:^{ button.transform = CGAffineTransformMakeScale(0.90, 0.90); }
                     completion:nil];
}

- (void)pressedUp:(UIView *)button {
    [UIView animateWithDuration:0.26
                          delay:0.0
         usingSpringWithDamping:0.7
          initialSpringVelocity:0.0
                        options:UIViewAnimationOptionBeginFromCurrentState
                     animations:^{ button.transform = CGAffineTransformIdentity; }
                     completion:nil];
}

- (void)tapped:(id)sender {
    if (SPKFloatingButtonOpenInstagramSettings())
        return;

    UIView *button = [sender isKindOfClass:[UIView class]] ? (UIView *)sender : nil;
    UIWindow *window = (UIWindow *)button.window ?: SPKFloatingButtonHostWindow();
    if (window)
        [SPKUtils showSettingsVC:window];
}

- (void)panned:(UIPanGestureRecognizer *)pan {
    UIView *button = pan.view;
    UIView *host = button.superview;
    if (!host)
        return;

    switch (pan.state) {
    case UIGestureRecognizerStateBegan:
    case UIGestureRecognizerStateChanged: {
        CGPoint translation = [pan translationInView:host];
        CGPoint center = button.center;
        center.x += translation.x;
        center.y += translation.y;

        // Never off-screen and never under a notch or a home indicator.
        UIEdgeInsets safe = host.safeAreaInsets;
        CGFloat half = CGRectGetWidth(button.bounds) / 2.0;
        center.x = MAX(safe.left + half, MIN(CGRectGetWidth(host.bounds) - safe.right - half, center.x));
        center.y = MAX(safe.top + half, MIN(CGRectGetHeight(host.bounds) - safe.bottom - half, center.y));

        button.center = center;
        objc_setAssociatedObject(button, kSPKFloatingButtonMovedAssocKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [pan setTranslation:CGPointZero inView:host];
        [host bringSubviewToFront:button];
        break;
    }
    case UIGestureRecognizerStateEnded:
    case UIGestureRecognizerStateCancelled:
    case UIGestureRecognizerStateFailed: {
        // Returns on its own, so a button dragged aside is never lost.
        __weak UIView *weakButton = button;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kSPKFloatingButtonReturnDelay * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            UIView *strongButton = weakButton;
            if (strongButton && strongButton.superview) {
                objc_setAssociatedObject(strongButton, kSPKFloatingButtonMovedAssocKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                SPKFloatingButtonSendHome(strongButton, YES);
            }
        });
        break;
    }
    default:
        break;
    }
}

@end

#pragma mark - Install

static void SPKFloatingButtonRemove(UIWindow *window) {
    UIView *existing = objc_getAssociatedObject(window, kSPKFloatingButtonAssocKey);
    [existing removeFromSuperview];
    objc_setAssociatedObject(window, kSPKFloatingButtonAssocKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void SPKFloatingButtonInstallInWindow(UIWindow *window) {
    if (!window)
        return;

    if (!SPKFloatingButtonShouldShow()) {
        SPKFloatingButtonRemove(window);
        return;
    }

    SPKChromeButton *button = objc_getAssociatedObject(window, kSPKFloatingButtonAssocKey);
    if (button.superview == window) {
        // The corner has to be recomputed, not just re-fronted. The first layout
        // pass often runs before Instagram's tab bar exists, so the button lands
        // on the safe area and — until this was here — stayed there for good,
        // sitting on the bar once it appeared.
        [window bringSubviewToFront:button];
        if (!objc_getAssociatedObject(button, kSPKFloatingButtonMovedAssocKey)) {
            CGPoint home = SPKFloatingButtonHomeCenter(window);
            if (!CGPointEqualToPoint(button.center, home))
                button.center = home;
        }
        return;
    }

    button = [[SPKChromeButton alloc] initWithSymbol:@""
                                           pointSize:24.0
                                            diameter:kSPKFloatingButtonDiameter];
    // The same glyph the profile tab carries top right — the one that opens
    // Settings and activity, and the one hiding that tab took away. Sparkle's
    // own star stays on the entry inside that screen, where it belongs.
    //
    // Sized against the tab bar's glyphs, measured at 22 pt: 24 pt puts this one
    // a shade above them rather than under.
    [button setIconResource:@"settings_menu" pointSize:24.0];
    button.iconTint = UIColor.labelColor;
    // The same material the tab bar underneath is made of, so the button reads
    // as part of the chrome rather than pasted over it. Glass on iOS 26, system
    // material before — the fallback SPKActionMenu already uses.
    button.bubbleColor = UIColor.clearColor;
    Class glassEffectClass = NSClassFromString(@"UIGlassEffect");
    UIVisualEffect *material = glassEffectClass
        ? [[glassEffectClass alloc] init]
        : [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterial];
    // Interactive glass deforms under a finger instead of sitting flat. Set by
    // key so it is a no-op, not a crash, where the property does not exist.
    if ([material respondsToSelector:NSSelectorFromString(@"setInteractive:")])
        [material setValue:@YES forKey:@"interactive"];
    button.bubbleEffect = material;
    button.layer.shadowColor = UIColor.blackColor.CGColor;
    button.layer.shadowOpacity = 0.16;
    button.layer.shadowRadius = 8.0;
    button.layer.shadowOffset = CGSizeMake(0.0, 2.0);
    button.clipsToBounds = NO;
    button.translatesAutoresizingMaskIntoConstraints = YES;
    button.accessibilityLabel = @"Sparkle settings";
    [button addTarget:[SPKFloatingSettingsButtonTarget sharedTarget]
               action:@selector(tapped:)
     forControlEvents:UIControlEventTouchUpInside];
    // Nothing acknowledged a press before: the glass sat flat and the settings
    // took a moment to arrive, so a tap felt ignored. Same press scale the
    // action menu uses on its own container.
    [button addTarget:[SPKFloatingSettingsButtonTarget sharedTarget]
               action:@selector(pressedDown:)
     forControlEvents:UIControlEventTouchDown];
    [button addTarget:[SPKFloatingSettingsButtonTarget sharedTarget]
               action:@selector(pressedUp:)
     forControlEvents:(UIControlEventTouchUpInside | UIControlEventTouchUpOutside |
                       UIControlEventTouchCancel | UIControlEventTouchDragExit)];

    // A quick tap still opens the settings: the pan only takes over once the
    // finger actually travels.
    UIPanGestureRecognizer *pan =
        [[UIPanGestureRecognizer alloc] initWithTarget:[SPKFloatingSettingsButtonTarget sharedTarget]
                                                action:@selector(panned:)];
    [button addGestureRecognizer:pan];

    button.bounds = CGRectMake(0, 0, kSPKFloatingButtonDiameter, kSPKFloatingButtonDiameter);
    [window addSubview:button];
    SPKFloatingButtonSendHome(button, NO);

    objc_setAssociatedObject(window, kSPKFloatingButtonAssocKey, button, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void SPKRefreshFloatingSettingsButton(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        SPKFloatingButtonInstallInWindow(SPKFloatingButtonHostWindow());
    });
}

%group SPKFloatingSettingsButtonHooks

%hook UIWindow

- (void)becomeKeyWindow {
    %orig;
    SPKFloatingButtonInstallInWindow(self);
}

- (void)layoutSubviews {
    %orig;

    // This is the path that actually seats the button. becomeKeyWindow fires
    // only when a window BECOMES key — a window that already was key when the
    // tweak loaded never calls it again, and at install time there may be no
    // window at all. Layout, on the other hand, always comes back.
    if (self.isHidden || self.alpha <= 0.01)
        return;
    if (![self isKindOfClass:[UIWindow class]] || self.windowLevel > UIWindowLevelNormal)
        return;

    SPKFloatingButtonInstallInWindow(self);
}

%end

%end

void SPKInstallFloatingSettingsButtonHooksIfNeeded(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        %init(SPKFloatingSettingsButtonHooks);
    });

    // The window may already be key by the time this runs.
    SPKRefreshFloatingSettingsButton();
}
