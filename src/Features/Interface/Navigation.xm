#import "../../Utils.h"
#import "../../App/SPKStabilityGuard.h"
#import "../../AssetUtils.h"
#import "../../Shared/Account/SPKAccountManager.h"
#import "../../Shared/Navigation/SPKTabConfiguration.h"
#import <objc/message.h>
#import <objc/runtime.h>
#import "../../App/SPKPerfMeter.h"

static const void *kSPKSavedTabIntentPendingKey = &kSPKSavedTabIntentPendingKey;
static const void *kSPKSavedTabFallbackHostKey = &kSPKSavedTabFallbackHostKey;
static const void *kSPKSavedTabButtonKey = &kSPKSavedTabButtonKey;
static const void *kSPKSavedTabButtonIdentityKey = &kSPKSavedTabButtonIdentityKey;
static const void *kSPKSavedTabOriginalImagesKey = &kSPKSavedTabOriginalImagesKey;
static const void *kSPKSavedTabOriginalLabelKey = &kSPKSavedTabOriginalLabelKey;
static const void *kSPKSavedTabSuppressedOverlaysKey = &kSPKSavedTabSuppressedOverlaysKey;

static NSUInteger spk_savedTabRoutingBypassGeneration = 0;
static NSTimeInterval spk_savedTabRoutingBypassDeadline = 0;

static BOOL SPKSavedTabRoutingBypassActive(void) {
    return spk_savedTabRoutingBypassDeadline > NSDate.timeIntervalSinceReferenceDate;
}

extern "C" void SPKBeginSavedTabRoutingBypass(void) {
    NSUInteger generation = ++spk_savedTabRoutingBypassGeneration;
    spk_savedTabRoutingBypassDeadline = NSDate.timeIntervalSinceReferenceDate + 2.5;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (spk_savedTabRoutingBypassGeneration == generation) {
            spk_savedTabRoutingBypassDeadline = 0;
        }
    });
}

extern "C" void SPKEndSavedTabRoutingBypass(void) {
    ++spk_savedTabRoutingBypassGeneration;
    spk_savedTabRoutingBypassDeadline = 0;
}

static NSString *SPKSavedCarrierIdentifier(void) {
    if (SPKStabilityGuardIsSafeStartupMode())
        return SPKTabSavedCarrierNone;
    return SPKEffectiveSavedCarrier();
}

// Classic draws Messages in the feed header and offers no toggle for it, so a
// hide flag left by another layout must not remove that link or the swipe.
static BOOL SPKMessagesTabHidden(void) {
    if (SPKStabilityGuardIsSafeStartupMode())
        return NO;
    NSString *layout = SPKNormalizedTabLayout([SPKUtils getStringPref:SPKPrefTabLayout]);
    if (!SPKTabOccupiesBarSlot(SPKTabIdentifierDirect, layout))
        return NO;
    return [SPKUtils getBoolPref:SPKTabHidePreferenceKey(SPKTabIdentifierDirect)];
}

// The Create launcher carries no tab string, so it is identified by its surface
// subtype. Instagram reuses 3 for the camera entry on every supported build.
static BOOL SPKIsCreateSurface(IGMainAppSurfaceIntent *surface) {
    if (!surface)
        return NO;
    @try {
        return [(NSNumber *)[surface valueForKey:@"_subtype"] unsignedIntegerValue] == 3;
    } @catch (__unused NSException *exception) {
        return NO;
    }
}

static BOOL SPKHasSavedTabDestination(void) {
    return ![SPKSavedCarrierIdentifier() isEqualToString:SPKTabSavedCarrierNone];
}

static BOOL SPKSavedTabPreferenceMayEnable(void) {
    NSString *baseKey = SPKPrefSavedTabCarrier;
    NSDictionary<NSString *, id> *preferences = NSUserDefaults.standardUserDefaults.dictionaryRepresentation;
    for (NSString *key in preferences) {
        if (([key isEqualToString:baseKey] || [key hasSuffix:[@"_" stringByAppendingString:baseKey]]) &&
            ![SPKNormalizedSavedCarrier(preferences[key]) isEqualToString:SPKTabSavedCarrierNone]) {
            return YES;
        }
    }
    return NO;
}

static NSString *SPKTabIdentifierForSurface(IGMainAppSurfaceIntent *surface) {
    if (![surface isKindOfClass:%c(IGMainAppSurfaceIntent)]) return nil;
    NSString *tab = [surface tabStringFromSurfaceIntent];
    if ([tab isEqualToString:@"FEED"]) return SPKTabIdentifierFeed;
    if ([tab isEqualToString:@"CLIPS"]) return SPKTabIdentifierClips;
    if ([tab isEqualToString:@"DIRECT"]) return SPKTabIdentifierDirect;
    if ([tab isEqualToString:@"SEARCH"]) return SPKTabIdentifierSearch;
    if ([tab isEqualToString:@"PROFILE"]) return SPKTabIdentifierProfile;
    return nil;
}

static BOOL SPKIsSavedCarrierSurface(IGMainAppSurfaceIntent *surface) {
    NSString *carrier = SPKSavedCarrierIdentifier();
    if ([carrier isEqualToString:SPKTabSavedCarrierNone])
        return NO;
    NSString *identifier = SPKTabIdentifierForSurface(surface);
    return identifier && [identifier isEqualToString:carrier];
}

static BOOL SPKIsSavedViewController(UIViewController *controller) {
    NSString *className = NSStringFromClass(controller.class);
    return [className containsString:@"SavedMediaCollectionsViewController"] ||
           [className containsString:@"IGSavedMediaViewController"];
}

static UINavigationController *SPKNativeSavedNavigationController(IGTabBarController *controller) {
    id manager = [SPKUtils getIvarForObj:controller name:"_viewControllerManager"];
    SEL selector = NSSelectorFromString(@"savedCollectionsNavigationController");
    if (!manager || ![manager respondsToSelector:selector])
        return nil;

    id candidate = ((id (*)(id, SEL))objc_msgSend)(manager, selector);
    return [candidate isKindOfClass:[UINavigationController class]] ? candidate : nil;
}

// Runs on every tab button layout pass, so the match is cached per button. A
// button without an identifier yet is left uncached until Instagram sets one.
static NSString *SPKTabIdentifierForButton(IGTabBarButton *button) {
    id cachedIdentity = objc_getAssociatedObject(button, kSPKSavedTabButtonIdentityKey);
    if ([cachedIdentity isKindOfClass:[NSString class]])
        return cachedIdentity;
    if ([cachedIdentity isKindOfClass:[NSNull class]])
        return nil;

    NSString *identifier = button.accessibilityIdentifier;
    if (identifier.length == 0)
        return nil;

    NSString *normalized = identifier.lowercaseString;
    NSString *resolved = nil;
    if ([normalized containsString:@"reels"] || [normalized containsString:@"clips"])
        resolved = SPKTabIdentifierClips;
    else if ([normalized containsString:@"direct"] || [normalized containsString:@"inbox"])
        resolved = SPKTabIdentifierDirect;
    else if ([normalized containsString:@"explore"] || [normalized containsString:@"search"])
        resolved = SPKTabIdentifierSearch;
    else if ([normalized containsString:@"profile"])
        resolved = SPKTabIdentifierProfile;
    else if ([normalized containsString:@"feed"] || [normalized containsString:@"timeline"] ||
             [normalized containsString:@"home"])
        resolved = SPKTabIdentifierFeed;
    else if ([normalized containsString:@"camera"] || [normalized containsString:@"create"])
        resolved = SPKTabIdentifierCreate;

    // A resolved "none" is cached too: without it every layout pass of the
    // camera/activity buttons re-lowercases their identifier forever.
    objc_setAssociatedObject(button, kSPKSavedTabButtonIdentityKey, resolved ?: (id)[NSNull null],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return resolved;
}

static UIImage *SPKSavedTabImage(BOOL filledImage) {
    static UIImage *outline;
    static UIImage *filled;
    if (filledImage) {
        if (!filled) {
            filled = [[SPKAssetUtils instagramIconNamed:@"save_filled" pointSize:24.0]
                imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        }
        return filled;
    }

    if (!outline) {
        outline = [[SPKAssetUtils instagramIconNamed:@"save" pointSize:24.0]
            imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    }
    return outline;
}

static void SPKRememberOriginalTabImage(UIButton *button, UIControlState state, UIImage *image) {
    if (!image || image == SPKSavedTabImage(NO) || image == SPKSavedTabImage(YES))
        return;

    NSMutableDictionary<NSNumber *, UIImage *> *originalImages = objc_getAssociatedObject(button, kSPKSavedTabOriginalImagesKey);
    if (!originalImages) {
        originalImages = [NSMutableDictionary dictionary];
        objc_setAssociatedObject(button, kSPKSavedTabOriginalImagesKey, originalImages, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    originalImages[@(state)] = image;
}

static NSString *const kSPKSavedTabAccessibilityLabel = @"Saved";

static void SPKConfigureSavedTabButtonInstance(UIButton *button) {
    if (![button isKindOfClass:[UIButton class]])
        return;

    NSString *identifier = SPKTabIdentifierForButton((IGTabBarButton *)button);
    BOOL shouldDisplaySaved = identifier && [identifier isEqualToString:SPKSavedCarrierIdentifier()];

    UIControlState states[] = {
        UIControlStateNormal,
        UIControlStateHighlighted,
        UIControlStateSelected,
        UIControlStateSelected | UIControlStateHighlighted,
    };

    // Views drawn over the button's own image (the profile avatar among them) hide
    // the Saved glyph, and Instagram rebuilds them on layout, so every pass sweeps
    // them. The button's own image view, which draws Saved, stays.
    NSHashTable<UIView *> *suppressed = objc_getAssociatedObject(button, kSPKSavedTabSuppressedOverlaysKey);
    if (shouldDisplaySaved) {
        if (!suppressed) {
            suppressed = [NSHashTable weakObjectsHashTable];
            objc_setAssociatedObject(button, kSPKSavedTabSuppressedOverlaysKey, suppressed, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        NSMutableArray<UIView *> *candidates = [NSMutableArray array];
        for (NSString *ivar in @[ @"_customView", @"_customOverlayView" ]) {
            UIView *overlay = [SPKUtils getIvarForObj:button name:ivar.UTF8String];
            if ([overlay isKindOfClass:[UIView class]])
                [candidates addObject:overlay];
        }
        // The profile slot draws its avatar in a view that is not an image view, so
        // only the button's own image may remain there. Elsewhere only image views
        // go, and dots and badges stay.
        BOOL drawsAvatar = [identifier isEqualToString:SPKTabIdentifierProfile];
        for (UIView *subview in button.subviews) {
            if (subview == button.imageView || subview == button.titleLabel)
                continue;
            if (drawsAvatar || [subview isKindOfClass:[UIImageView class]])
                [candidates addObject:subview];
        }
        // Only views this hid are remembered, so a view Instagram had already
        // hidden for its own reasons is never revealed later.
        for (UIView *view in candidates) {
            if (view.hidden)
                continue;
            view.hidden = YES;
            [suppressed addObject:view];
        }
        // A slot that drew everything through a custom view may have had no use
        // for its own image view; it is what carries the Saved glyph now.
        if (button.imageView.hidden)
            button.imageView.hidden = NO;
    } else if (suppressed) {
        for (UIView *view in suppressed.allObjects)
            view.hidden = NO;
        objc_setAssociatedObject(button, kSPKSavedTabSuppressedOverlaysKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    if (!shouldDisplaySaved) {
        NSDictionary<NSNumber *, UIImage *> *originalImages = objc_getAssociatedObject(button, kSPKSavedTabOriginalImagesKey);
        for (NSUInteger index = 0; index < sizeof(states) / sizeof(states[0]); index++) {
            UIControlState state = states[index];
            UIImage *originalImage = originalImages[@(state)];
            if (originalImage && [button imageForState:state] != originalImage) {
                [button setImage:originalImage forState:state];
            }
        }
        NSString *originalLabel = objc_getAssociatedObject(button, kSPKSavedTabOriginalLabelKey);
        if (originalLabel && [button.accessibilityLabel isEqualToString:kSPKSavedTabAccessibilityLabel]) {
            button.accessibilityLabel = originalLabel;
        }
        return;
    }

    objc_setAssociatedObject(button, kSPKSavedTabButtonKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(button, kSPKSavedTabButtonIdentityKey, identifier, OBJC_ASSOCIATION_COPY_NONATOMIC);

    if (!objc_getAssociatedObject(button, kSPKSavedTabOriginalLabelKey) &&
        button.accessibilityLabel.length > 0 &&
        ![button.accessibilityLabel isEqualToString:kSPKSavedTabAccessibilityLabel]) {
        objc_setAssociatedObject(button, kSPKSavedTabOriginalLabelKey, button.accessibilityLabel, OBJC_ASSOCIATION_COPY_NONATOMIC);
    }

    for (NSUInteger index = 0; index < sizeof(states) / sizeof(states[0]); index++) {
        UIControlState state = states[index];
        SPKRememberOriginalTabImage(button, state, [button imageForState:state]);
    }

    UIImage *outline = SPKSavedTabImage(NO);
    UIImage *filled = SPKSavedTabImage(YES);

    if (outline && [button imageForState:UIControlStateNormal] != outline) {
        [button setImage:outline forState:UIControlStateNormal];
    }
    if (outline && [button imageForState:UIControlStateHighlighted] != outline) {
        [button setImage:outline forState:UIControlStateHighlighted];
    }
    if (filled && [button imageForState:UIControlStateSelected] != filled) {
        [button setImage:filled forState:UIControlStateSelected];
    }
    if (filled && [button imageForState:UIControlStateSelected | UIControlStateHighlighted] != filled) {
        [button setImage:filled forState:UIControlStateSelected | UIControlStateHighlighted];
    }
    // Writing this unconditionally would loop: the settings-shortcut hook calls
    // -setNeedsLayout from -setAccessibilityLabel:, so every write schedules the
    // pass that writes again.
    if (![button.accessibilityLabel isEqualToString:kSPKSavedTabAccessibilityLabel]) {
        button.accessibilityLabel = kSPKSavedTabAccessibilityLabel;
    }
}

// The button the bar shows for an identifier, through -_buttonForTabBarSurface:
// rather than the ivars, which do not always hold it (the camera slot does not).
static UIButton *SPKBarButtonForIdentifier(IGTabBarController *controller, NSString *identifier) {
    if (!identifier || [identifier isEqualToString:SPKTabSavedCarrierNone] ||
        ![controller respondsToSelector:@selector(_buttonForTabBarSurface:)])
        return nil;
    NSArray *surfaces = [SPKUtils getIvarForObj:controller name:"_tabBarSurfaces"];
    if (![surfaces isKindOfClass:[NSArray class]])
        return nil;
    for (IGMainAppSurfaceIntent *surface in surfaces) {
        if (![identifier isEqualToString:SPKTabIdentifierForSurface(surface)])
            continue;
        id button = [controller _buttonForTabBarSurface:surface];
        return [button isKindOfClass:[UIButton class]] ? button : nil;
    }
    return nil;
}

// Stamps every tab bar button the controller owns with its Sparkle identifier.
// The ivars are authoritative: accessibility identifiers are only a fallback for
// buttons reached through -layoutSubviews before the controller is available.
static void SPKStampTabButtonIdentities(IGTabBarController *controller) {
    NSDictionary<NSString *, NSString *> *identifiersByIvar = @{
        @"_timelineButton" : SPKTabIdentifierFeed,
        @"_discoverVideoButton" : SPKTabIdentifierClips,
        @"_directInboxButton" : SPKTabIdentifierDirect,
        @"_exploreButton" : SPKTabIdentifierSearch,
        @"_profileButton" : SPKTabIdentifierProfile,
        @"_cameraButton" : SPKTabIdentifierCreate,
    };
    for (NSString *ivar in identifiersByIvar) {
        UIButton *button = [SPKUtils getIvarForObj:controller name:ivar.UTF8String];
        if (button)
            objc_setAssociatedObject(button, kSPKSavedTabButtonIdentityKey, identifiersByIvar[ivar], OBJC_ASSOCIATION_COPY_NONATOMIC);
    }
}

// Any bar button can be the carrier, so all of them are reconciled: the carrier
// picks up the Saved glyph and every other button gets its original artwork put
// back if it used to be the carrier.
static void SPKConfigureSavedTabButton(IGTabBarController *controller) {
    SPKStampTabButtonIdentities(controller);
    for (NSString *ivar in @[ @"_timelineButton", @"_discoverVideoButton", @"_directInboxButton",
                              @"_exploreButton", @"_profileButton", @"_cameraButton" ])
        SPKConfigureSavedTabButtonInstance([SPKUtils getIvarForObj:controller name:ivar.UTF8String]);

    // The ivars do not always hold the button that is actually on the bar, so
    // the surface map is the authority: it is the same lookup the bar itself
    // uses to place buttons.
    NSString *carrier = SPKSavedCarrierIdentifier();
    UIButton *carrierButton = SPKBarButtonForIdentifier(controller, carrier);
    if (carrierButton) {
        objc_setAssociatedObject(carrierButton, kSPKSavedTabButtonIdentityKey, carrier, OBJC_ASSOCIATION_COPY_NONATOMIC);
        SPKConfigureSavedTabButtonInstance(carrierButton);
    }
}

// Containment only: following presented controllers re-walks the same subtree from
// every child, and the tab bar controller is never inside a presentation.
static IGTabBarController *SPKFindTabBarController(UIViewController *controller) {
    if (!controller)
        return nil;
    if ([controller isKindOfClass:%c(IGTabBarController)])
        return (IGTabBarController *)controller;

    for (UIViewController *child in controller.childViewControllers) {
        IGTabBarController *childMatch = SPKFindTabBarController(child);
        if (childMatch)
            return childMatch;
    }
    return nil;
}

static void SPKConfigureExistingSavedTabButton(void) {
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]])
            continue;
        for (UIWindow *window in ((UIWindowScene *)scene).windows) {
            IGTabBarController *controller = SPKFindTabBarController(window.rootViewController);
            if (controller) {
                SPKConfigureSavedTabButton(controller);
                return;
            }
        }
    }

    IGTabBarController *controller = SPKFindTabBarController(UIApplication.sharedApplication.keyWindow.rootViewController);
    SPKConfigureSavedTabButton(controller);
}

static void SPKScheduleSavedTabButtonReconciliation(void) {
    SPKConfigureExistingSavedTabButton();
    for (NSNumber *delay in @[ @0.25, @1.0 ]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay.doubleValue * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            SPKConfigureExistingSavedTabButton();
        });
    }
}

static void SPKFinishSavedTabIntent(UINavigationController *navigationController, NSUInteger attempt) {
    UIViewController *top = navigationController.topViewController;
    if (SPKIsSavedViewController(top)) {
        if (objc_getAssociatedObject(navigationController, kSPKSavedTabFallbackHostKey) &&
            navigationController.viewControllers.count != 1) {
            [navigationController setViewControllers:@[ top ] animated:NO];
        }
        objc_setAssociatedObject(navigationController, kSPKSavedTabIntentPendingKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return;
    }

    if (attempt >= 12) {
        SPKLog(@"TabBar", @"[Sparkle] Timed out waiting for Instagram's Saved controller");
        objc_setAssociatedObject(navigationController, kSPKSavedTabIntentPendingKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return;
    }

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        SPKFinishSavedTabIntent(navigationController, attempt + 1);
    });
}

// Instagram's own "open the Saved home" intent. The two-argument initializer is
// the current one; older builds only take the entry module.
static id SPKMakeSavedIntentTarget(void) {
    id target = [NSClassFromString(@"IGSaveHomeIntentTarget") alloc];
    SEL currentInitializer = NSSelectorFromString(@"initWithEntryModule:selectedTab:");
    if ([target respondsToSelector:currentInitializer])
        return ((id (*)(id, SEL, id, id))objc_msgSend)(target, currentInitializer, @"tab_bar", nil);
    SEL legacyInitializer = NSSelectorFromString(@"initWithEntryModule:");
    if ([target respondsToSelector:legacyInitializer])
        return ((id (*)(id, SEL, id))objc_msgSend)(target, legacyInitializer, @"tab_bar");
    return nil;
}

static void SPKOpenSavedInFallbackNavigationController(IGTabBarController *tabBarController,
                                                        UINavigationController *navigationController) {
    if (!navigationController || SPKIsSavedViewController(navigationController.topViewController))
        return;
    if (objc_getAssociatedObject(navigationController, kSPKSavedTabIntentPendingKey))
        return;

    // -fb_intentHandler is nil unless a handler was installed on that very
    // controller. Builds that set none (410) go through the URL route below, which
    // is expected rather than a failure worth logging on every tap.
    id<FBIntentHandler> handler = [navigationController respondsToSelector:@selector(fb_intentHandler)]
                                      ? [navigationController fb_intentHandler]
                                      : nil;
    if (![handler respondsToSelector:@selector(handleIntent:)]) {
        static dispatch_once_t noticeToken;
        dispatch_once(&noticeToken, ^{
            SPKLog(@"TabBar", @"[Sparkle] Saved intent handler unavailable; using instagram://saved for this session");
        });
        id userSession = [SPKUtils getIvarForObj:tabBarController name:"_userSession"];
        Class urlHandlerClass = NSClassFromString(@"IGURLHandler");
        SEL openSelector = NSSelectorFromString(@"openInternalURL:presentationConfig:controller:animated:userSession:annotation:");
        if ([urlHandlerClass respondsToSelector:openSelector]) {
            BOOL opened = ((BOOL (*)(id, SEL, id, id, id, BOOL, id, id))objc_msgSend)(urlHandlerClass,
                                                                                       openSelector,
                                                                                       [NSURL URLWithString:@"instagram://saved"],
                                                                                       nil,
                                                                                       navigationController,
                                                                                       NO,
                                                                                       userSession,
                                                                                       nil);
            if (opened) {
                objc_setAssociatedObject(navigationController, kSPKSavedTabIntentPendingKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                objc_setAssociatedObject(navigationController, kSPKSavedTabFallbackHostKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                SPKFinishSavedTabIntent(navigationController, 0);
            }
        }
        return;
    }

    id target = SPKMakeSavedIntentTarget();
    if (!target) {
        SPKLog(@"TabBar", @"[Sparkle] Unable to construct Instagram's Saved intent target");
        return;
    }

    objc_setAssociatedObject(navigationController, kSPKSavedTabIntentPendingKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(navigationController, kSPKSavedTabFallbackHostKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    ((void (*)(id, SEL, id))objc_msgSend)(handler, @selector(handleIntent:), target);
    SPKFinishSavedTabIntent(navigationController, 0);
}

static void SPKEnsureSavedTabDestination(IGTabBarController *controller) {
    if (!SPKHasSavedTabDestination())
        return;

    UINavigationController *nativeSavedNavigationController = SPKNativeSavedNavigationController(controller);
    if (nativeSavedNavigationController)
        return;

    UIViewController *selected = controller.selectedViewController;
    UINavigationController *navigationController = [selected isKindOfClass:[UINavigationController class]]
                                                       ? (UINavigationController *)selected
                                                       : nil;
    // Only Reels has a dedicated accessor worth falling back to; for any other
    // carrier the selected controller is the one being redirected.
    if (!navigationController && [SPKSavedCarrierIdentifier() isEqualToString:SPKTabIdentifierClips])
        navigationController = [controller discoverVideoNavigationController];
    SPKOpenSavedInFallbackNavigationController(controller, navigationController);
}

// Shared bookkeeping for the -_setSelectedTabBarSurface: overloads. The shorter
// one forwards to the longer on newer builds, so the work is keyed to the
// outermost call and runs exactly once per selection.
typedef struct {
    BOOL bypassesSaved;
    BOOL selectsSaved;
    BOOL isOutermost;
} SPKSavedTabSelection;

static NSUInteger spk_savedTabSelectionDepth = 0;

static SPKSavedTabSelection SPKBeginSavedTabSelection(IGMainAppSurfaceIntent *surface) {
    BOOL isSavedCarrier = SPKIsSavedCarrierSurface(surface);
    BOOL bypassesSaved = isSavedCarrier && SPKSavedTabRoutingBypassActive();
    SPKSavedTabSelection selection = {
        .bypassesSaved = bypassesSaved,
        .selectsSaved = isSavedCarrier && !bypassesSaved,
        .isOutermost = (spk_savedTabSelectionDepth == 0),
    };
    spk_savedTabSelectionDepth++;
    return selection;
}

static void SPKFinishSavedTabSelection(IGTabBarController *controller, SPKSavedTabSelection selection) {
    if (spk_savedTabSelectionDepth > 0) {
        spk_savedTabSelectionDepth--;
    }
    if (!selection.isOutermost)
        return;

    if (selection.bypassesSaved) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            SPKEndSavedTabRoutingBypass();
        });
    }
    if (selection.selectsSaved) {
        dispatch_async(dispatch_get_main_queue(), ^{
            SPKConfigureSavedTabButton(controller);
            SPKEnsureSavedTabDestination(controller);
        });
    }
}

static BOOL SPKHandleSavedCarrierButtonPress(IGTabBarController *controller, NSString *identifier) {
    if (!identifier || ![SPKSavedCarrierIdentifier() isEqualToString:identifier])
        return NO;
    NSArray *surfaces = [SPKUtils getIvarForObj:controller name:"_tabBarSurfaces"];
    for (IGMainAppSurfaceIntent *surface in surfaces) {
        NSString *surfaceIdentifier = SPKTabIdentifierForSurface(surface);
        if (surfaceIdentifier && [surfaceIdentifier isEqualToString:identifier]) {
            [controller setSelectedTabBarSurface:surface animated:YES];
            SPKConfigureSavedTabButton(controller);
            dispatch_async(dispatch_get_main_queue(), ^{ SPKEnsureSavedTabDestination(controller); });
            return YES;
        }
    }
    return NO;
}

static NSString *SPKSelectorForLaunchTabPreference(NSString *preference) {
    if ([preference isEqualToString:@"feed"])
        return @"_timelineButtonPressed";
    if ([preference isEqualToString:@"reels"])
        return @"_discoverVideoButtonPressed";
    if ([preference isEqualToString:@"inbox"])
        return @"_directInboxButtonPressed";
    if ([preference isEqualToString:@"explore"])
        return @"_exploreButtonPressed";
    if ([preference isEqualToString:@"profile"])
        return @"_profileButtonPressed";
    return nil;
}

static NSString *SPKSelectorForSurfaceIntent(IGMainAppSurfaceIntent *surface) {
    if (!surface || ![surface isKindOfClass:%c(IGMainAppSurfaceIntent)])
        return nil;
    NSString *tab = [surface tabStringFromSurfaceIntent];
    if ([tab isEqualToString:@"FEED"])
        return @"_timelineButtonPressed";
    if ([tab isEqualToString:@"CLIPS"])
        return @"_discoverVideoButtonPressed";
    if ([tab isEqualToString:@"DIRECT"])
        return @"_directInboxButtonPressed";
    if ([tab isEqualToString:@"SEARCH"])
        return @"_exploreButtonPressed";
    if ([tab isEqualToString:@"PROFILE"])
        return @"_profileButtonPressed";
    return nil;
}

BOOL isSurfaceShown(IGMainAppSurfaceIntent *surface) {
    if (SPKStabilityGuardIsSafeStartupMode()) {
        return YES;
    }
    NSString *identifier = SPKTabIdentifierForSurface(surface);
    NSString *carrier = SPKSavedCarrierIdentifier();
    // The Saved carrier is a hidden slot that Sparkle draws as Saved, so its hide
    // flag must not remove it: hiding it is exactly what freed the slot.
    if (identifier && [identifier isEqualToString:carrier])
        return YES;
    NSString *hideKey = identifier ? SPKTabHidePreferenceKey(identifier) : nil;
    if (hideKey.length > 0 && [SPKUtils getBoolPref:hideKey])
        return NO;
    if (SPKIsCreateSurface(surface) && [SPKUtils getBoolPref:@"interface_hide_create_tab"])
        return NO;
    return YES;
}

// The first known destination, prepended when filtering would leave the bar with
// none, so the app always has a tab to land on.
static id SPKFallbackDestinationSurface(NSDictionary<NSString *, id> *knownSurfaces) {
    id fallback = knownSurfaces[SPKTabIdentifierFeed];
    if (fallback)
        return fallback;
    for (NSString *identifier in SPKCanonicalTabIdentifiers()) {
        if (knownSurfaces[identifier])
            return knownSurfaces[identifier];
    }
    return nil;
}

NSArray *filterSurfacesArray(NSArray *surfaces) {
    if (![surfaces isKindOfClass:[NSArray class]] || SPKStabilityGuardIsSafeStartupMode())
        return surfaces ?: @[];

    NSMutableDictionary<NSString *, id> *knownSurfaces = [NSMutableDictionary dictionary];
    NSMutableArray *unknownSurfaces = [NSMutableArray array];
    for (id surface in surfaces) {
        NSString *identifier = SPKTabIdentifierForSurface(surface);
        if (identifier.length > 0 && !knownSurfaces[identifier])
            knownSurfaces[identifier] = surface;
        else if (!identifier)
            [unknownSurfaces addObject:surface];
    }

    NSMutableArray *filtered = [NSMutableArray array];
    NSString *layout = SPKNormalizedTabLayout([SPKUtils getStringPref:SPKPrefTabLayout]);
    if (![layout isEqualToString:SPKTabLayoutCustom]) {
        // Default and Classic keep Instagram's own order: the bar places its
        // buttons from a fixed list, so only hidden surfaces are dropped.
        for (id surface in surfaces) {
            if (isSurfaceShown(surface))
                [filtered addObject:surface];
        }
    } else {
        NSString *savedCarrier = SPKSavedCarrierIdentifier();
        for (NSString *identifier in SPKNormalizeTabOrder([NSUserDefaults.standardUserDefaults objectForKey:SPKPrefCustomTabOrder])) {
            // Saved is drawn by its carrier, so the carrier is skipped where its
            // own identifier appears.
            BOOL isSavedEntry = [identifier isEqualToString:SPKTabIdentifierSaved];
            if (isSavedEntry && !SPKHasSavedTabDestination())
                continue;
            if (!isSavedEntry && [identifier isEqualToString:savedCarrier])
                continue;
            id surface = knownSurfaces[isSavedEntry ? savedCarrier : identifier];
            if (surface && isSurfaceShown(surface))
                [filtered addObject:surface];
        }
        // Surfaces Sparkle does not know keep their native relative order, so an
        // app update never silently deletes one.
        for (id surface in unknownSurfaces) {
            if (isSurfaceShown(surface))
                [filtered addObject:surface];
        }
    }

    for (id surface in filtered) {
        if (SPKTabIdentifierForSurface(surface))
            return filtered;
    }
    id fallback = SPKFallbackDestinationSurface(knownSurfaces);
    if (fallback)
        [filtered insertObject:fallback atIndex:0];
    return filtered;
}

// The bar places buttons from its own fixed list, so a reordered surface array
// moves no glyph. The buttons are handed to the bar again in the surfaces' order,
// which also keeps the selection indicator on the right button.
static void SPKApplyCustomTabButtonOrder(IGTabBarController *controller) {
    if (SPKStabilityGuardIsSafeStartupMode())
        return;
    if (![SPKNormalizedTabLayout([SPKUtils getStringPref:SPKPrefTabLayout]) isEqualToString:SPKTabLayoutCustom])
        return;

    id<SPKTabBarViewRepresentable> bar = (id<SPKTabBarViewRepresentable>)controller.tabBar;
    if (![bar respondsToSelector:@selector(addTabButton:)] ||
        ![bar respondsToSelector:@selector(clearTabButtons)] ||
        ![bar respondsToSelector:@selector(buttons)] ||
        ![controller respondsToSelector:@selector(_buttonForTabBarSurface:)])
        return;

    NSArray *surfaces = [SPKUtils getIvarForObj:controller name:"_tabBarSurfaces"];
    if (![surfaces isKindOfClass:[NSArray class]] || surfaces.count == 0)
        return;

    id selectedSurface = [controller respondsToSelector:@selector(selectedTabBarSurface)]
                             ? [controller selectedTabBarSurface]
                             : nil;
    NSMutableArray<UIView *> *desired = [NSMutableArray array];
    NSInteger selectedIndex = NSNotFound;
    for (id surface in surfaces) {
        id button = [controller _buttonForTabBarSurface:surface];
        if (![button isKindOfClass:[UIView class]])
            continue;
        if (selectedSurface && surface == selectedSurface)
            selectedIndex = (NSInteger)desired.count;
        [desired addObject:button];
    }
    if (desired.count == 0)
        return;

    NSArray *current = bar.buttons;
    if ([current isKindOfClass:[NSArray class]] && [current isEqualToArray:desired])
        return;

    [bar clearTabButtons];
    for (UIView *button in desired)
        [bar addTabButton:button];
    if (selectedIndex != NSNotFound && [bar respondsToSelector:@selector(setSelectedTabBarItemIndex:)])
        [bar setSelectedTabBarItemIndex:selectedIndex];
    [controller.tabBar setNeedsLayout];
}

// Only Messages may lose the bar: the button in its header keeps Sparkle reachable.
static BOOL SPKShouldHideTabBarForSingleTab(void) {
    return [SPKUtils getBoolPref:SPKPrefHideTabBarWhenSingle] && SPKTabConfigurationIsMessagesOnly();
}

///////////////////////////////////////////////

// Installed only when Saved is in use, since it runs on every tab button layout
// pass. IGTabBarButton implements -layoutSubviews but not the image setters, so
// the pass after Instagram restores its own image swaps it out again.
%group SPKSavedTabButtonHooks

%hook IGTabBarButton
- (void)layoutSubviews {
    %orig;
    SPKConfigureSavedTabButtonInstance(self);
}
%end

%end

%group SPKNavigationHooks

%hook IGTabBarControllerSwipeCoordinator
- (id)initWithSurfaces:(id)surfaces parentViewController:(id)controller enableHaptics:(_Bool)haptics launcherSet:(id)set {
    // Removes the surface from the main swipeable app collection view
    NSArray *filtered = filterSurfacesArray(surfaces);
    return %orig(filtered, controller, haptics, set);
}

// Instagram hands a rebuilt surface list here when it repopulates the tab bar;
// unfiltered, hidden tabs come back in the swipe.
- (void)updateSurfaces:(id)surfaces {
    %orig(filterSurfacesArray(surfaces));
}
%end

%hook IGTabBarController
- (void)viewDidLoad {
    %orig;
    NSArray *surfaces = [SPKUtils getIvarForObj:self name:"_tabBarSurfaces"];
    if (surfaces) {
        [SPKUtils setIvarForObj:self name:"_tabBarSurfaces" value:filterSurfacesArray(surfaces)];
    }
    SPKConfigureSavedTabButton(self);
}

- (void)_createAndConfigureReelsButtonIfNeeded {
    %orig;
    SPKConfigureSavedTabButton(self);
}

- (id)navigationViewControllerForAppSurfaceIntent:(IGMainAppSurfaceIntent *)surface {
    if (SPKHasSavedTabDestination() &&
        !SPKSavedTabRoutingBypassActive() &&
        SPKIsSavedCarrierSurface(surface)) {
        UINavigationController *savedNavigationController = SPKNativeSavedNavigationController(self);
        if (savedNavigationController)
            return savedNavigationController;
    }
    return %orig;
}

// Each of these runs %orig untouched unless that exact tab is the Saved carrier.
- (void)_timelineButtonPressed {
    if (!SPKHandleSavedCarrierButtonPress(self, SPKTabIdentifierFeed)) %orig;
}

- (void)_discoverVideoButtonPressed {
    if (!SPKHandleSavedCarrierButtonPress(self, SPKTabIdentifierClips)) %orig;
}

- (void)_directInboxButtonPressed {
    if (!SPKHandleSavedCarrierButtonPress(self, SPKTabIdentifierDirect)) %orig;
}

- (void)_exploreButtonPressed {
    if (!SPKHandleSavedCarrierButtonPress(self, SPKTabIdentifierSearch)) %orig;
}

- (void)_profileButtonPressed {
    if (!SPKHandleSavedCarrierButtonPress(self, SPKTabIdentifierProfile)) %orig;
}

- (void)_setSelectedTabBarSurface:(IGMainAppSurfaceIntent *)surface
                   isTabBarAction:(BOOL)isTabBarAction
                         animated:(BOOL)animated
                 navigationAction:(NSUInteger)navigationAction
                skipMainFeedFetch:(BOOL)skipMainFeedFetch {
    SPKSavedTabSelection selection = SPKBeginSavedTabSelection(surface);
    %orig;
    SPKFinishSavedTabSelection(self, selection);
}

// IG added a second overload carrying a trailing animateIndicator:, and call
// sites use whichever they were written against. Both have to do the same
// bookkeeping or the routing bypass is never torn down on the newer path.
- (void)_setSelectedTabBarSurface:(IGMainAppSurfaceIntent *)surface
                   isTabBarAction:(BOOL)isTabBarAction
                         animated:(BOOL)animated
                 navigationAction:(NSUInteger)navigationAction
                skipMainFeedFetch:(BOOL)skipMainFeedFetch
                  animateIndicator:(BOOL)animateIndicator {
    SPKSavedTabSelection selection = SPKBeginSavedTabSelection(surface);
    %orig;
    SPKFinishSavedTabSelection(self, selection);
}

- (void)viewDidLayoutSubviews {
    %orig;
    SPK_PERF_SCOPE(@"Navigation.viewDidLayoutSubviews");
    if (SPKStabilityGuardIsSafeStartupMode()) {
        return;
    }
    if (SPKShouldHideTabBarForSingleTab()) {
        self.tabBar.hidden = YES;
    }
}

- (void)viewWillAppear:(BOOL)animated {
    %orig;
    if (SPKStabilityGuardIsSafeStartupMode())
        return;

    static BOOL appliedLaunchTab = NO;
    if (appliedLaunchTab)
        return;
    appliedLaunchTab = YES;

    NSString *launchPref = [SPKUtils getStringPref:@"interface_launch_tab"];
    NSString *selectorName = SPKSelectorForLaunchTabPreference(launchPref);

    NSArray *rawSurfaces = [SPKUtils getIvarForObj:self name:"_tabBarSurfaces"];
    NSArray *enabledSurfaces = filterSurfacesArray(rawSurfaces);

    BOOL feedHidden = [SPKUtils getBoolPref:@"interface_hide_feed_tab"];

    BOOL usesCustomOrder = [SPKNormalizedTabLayout([SPKUtils getStringPref:SPKPrefTabLayout])
        isEqualToString:SPKTabLayoutCustom];

    if ([launchPref isEqualToString:@"default"]) {
        BOOL feedIsEnabled = NO;
        for (IGMainAppSurfaceIntent *s in enabledSurfaces) {
            if ([[s tabStringFromSurfaceIntent] isEqualToString:@"FEED"]) {
                feedIsEnabled = YES;
                break;
            }
        }
        if (usesCustomOrder && enabledSurfaces.count > 0) {
            // Instagram opens on Feed wherever it sits, so a custom layout would
            // show the feed under another selected tab. Default opens the first tab.
            selectorName = SPKSelectorForSurfaceIntent(enabledSurfaces.firstObject);
        } else if ((!feedIsEnabled || feedHidden) && enabledSurfaces.count > 0) {
            selectorName = SPKSelectorForSurfaceIntent(enabledSurfaces.firstObject);
        } else if (feedHidden) {
            // Fallback preference check if surface array is unavailable
            if (![SPKUtils getBoolPref:@"interface_hide_msgs_tab"]) {
                selectorName = @"_directInboxButtonPressed";
            } else if (![SPKUtils getBoolPref:@"interface_hide_reels_tab"]) {
                selectorName = @"_discoverVideoButtonPressed";
            } else if (![SPKUtils getBoolPref:@"interface_hide_explore_tab"]) {
                selectorName = @"_exploreButtonPressed";
            } else if (![SPKUtils getBoolPref:@"interface_hide_profile_tab"]) {
                selectorName = @"_profileButtonPressed";
            }
        }
    } else if (selectorName.length > 0) {
        BOOL chosenIsEnabled = NO;
        for (IGMainAppSurfaceIntent *s in enabledSurfaces) {
            NSString *sel = SPKSelectorForSurfaceIntent(s);
            if ([sel isEqualToString:selectorName]) {
                chosenIsEnabled = YES;
                break;
            }
        }
        if (!chosenIsEnabled && enabledSurfaces.count > 0) {
            selectorName = SPKSelectorForSurfaceIntent(enabledSurfaces.firstObject);
        }
    }

    SEL selector = selectorName.length > 0 ? NSSelectorFromString(selectorName) : nil;
    if (selector && [self respondsToSelector:selector]) {
        ((void (*)(id, SEL))objc_msgSend)(self, selector);
    }

    if (!SPKStabilityGuardIsSafeStartupMode()) {
        if ([self respondsToSelector:@selector(_updateTabBarVisibilityForController:)] && self.selectedViewController) {
            [self _updateTabBarVisibilityForController:self.selectedViewController];
        }
    }
}

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    SPKConfigureSavedTabButton(self);
    if (SPKStabilityGuardIsSafeStartupMode()) {
        return;
    }
    if (SPKShouldHideTabBarForSingleTab()) {
        if ([self respondsToSelector:@selector(_updateTabBarVisibilityForController:)] && self.selectedViewController) {
            [self _updateTabBarVisibilityForController:self.selectedViewController];
        }
    }
}

- (void)_layoutTabBar {
    // Prevents the wrong icon from being shown as selected because of mismatched surface array indexes
    NSArray *_tabBarSurfaces = [SPKUtils getIvarForObj:self name:"_tabBarSurfaces"];

    [SPKUtils setIvarForObj:self name:"_tabBarSurfaces" value:filterSurfacesArray(_tabBarSurfaces)];

    %orig;
    SPKConfigureSavedTabButton(self);
    SPKApplyCustomTabButtonOrder(self);
}

- (id)_buttonForTabBarSurface:(id)surface {
    // Prevents the button from being added to the tab bar
    id button = %orig(surface);

    if (!isSurfaceShown(surface)) {
        return nil;
    }

    return button;
}

- (BOOL)_shouldTabBarBeHiddenForController:(id)controller {
    if (SPKStabilityGuardIsSafeStartupMode()) {
        return %orig;
    }
    if (SPKShouldHideTabBarForSingleTab()) {
        return YES;
    }
    return %orig;
}
%end

// Demangled name: IGNavConfiguration.IGNavConfiguration
%hook _TtC18IGNavConfiguration18IGNavConfiguration
- (NSInteger)tabOrdering {
    if (SPKStabilityGuardIsSafeStartupMode())
        return %orig;
    NSString *layout = SPKNormalizedTabLayout([SPKUtils getStringPref:SPKPrefTabLayout]);
    if ([layout isEqualToString:SPKTabLayoutClassic])
        return 0;
    // Custom reorders the buttons of Instagram's standard bar; Default keeps
    // whatever ordering Instagram chose.
    if ([layout isEqualToString:SPKTabLayoutCustom])
        return 1;
    return %orig;
}
- (void)setTabOrdering:(NSInteger)arg1 {
    if (SPKStabilityGuardIsSafeStartupMode()) {
        %orig;
    }
}

- (BOOL)isTabSwipingEnabled {
    if (SPKStabilityGuardIsSafeStartupMode())
        return %orig;

    if ([[SPKUtils getStringPref:@"interface_swipe_tabs"] isEqualToString:@"enabled"])
        return YES;
    else if ([[SPKUtils getStringPref:@"interface_swipe_tabs"] isEqualToString:@"disabled"])
        return NO;

    return %orig;
}
- (void)setIsTabSwipingEnabled:(BOOL)arg1 {
    if (SPKStabilityGuardIsSafeStartupMode() ||
        [[SPKUtils getStringPref:@"interface_swipe_tabs"] isEqualToString:@"default"]) {
        %orig;
    }
}
%end

%hook IGHomeFeedHeaderView
- (void)didMoveToWindow {
    %orig;
    SPK_PERF_SCOPE(@"Navigation.didMoveToWindow");

    if (SPKStabilityGuardIsSafeStartupMode())
        return;

    if (SPKMessagesTabHidden()) {
        // IG 436+ is a Swift class: the DM button is the `directButton` @property
        // (KVC-safe). `rightButton` is a bare Swift ivar on 436 (KVC throws) but the
        // KVC key on older ObjC builds — resolve via selector first, guard the rest.
        UIView *msgsButton = nil;
        for (NSString *key in @[ @"directButton", @"rightButton" ]) {
            SEL getter = NSSelectorFromString(key);
            if (![self respondsToSelector:getter])
                continue;
            id candidate = ((id (*)(id, SEL))objc_msgSend)(self, getter);
            if ([candidate isKindOfClass:[UIView class]]) {
                msgsButton = candidate;
                break;
            }
        }
        if (msgsButton) {
            SPKLog(@"General", @"[Sparkle] Hiding messages tab (on feed)");

            [msgsButton removeFromSuperview];
        }
    }
}
%end

%hook IGMainAppScrollingContainerViewController
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gesture {
    if (SPKStabilityGuardIsSafeStartupMode())
        return %orig;
    if (![gesture isKindOfClass:[UIPanGestureRecognizer class]])
        return %orig;

    UIPanGestureRecognizer *pan = (UIPanGestureRecognizer *)gesture;
    CGPoint velocity = [pan velocityInView:pan.view];
    CGPoint translation = [pan translationInView:pan.view];
    UIViewController *activeVC = [SPKUtils getIvarForObj:self name:"_activeViewController"];

    // Dragging right reveals the camera that sits to the left of the tabs.
    if ([SPKUtils getBoolPref:@"interface_hide_feed_tab"] && (velocity.x > 0 || translation.x > 0)) {
        UIViewController *creationVC = [SPKUtils getIvarForObj:self name:"_creationViewController"];
        if (activeVC && creationVC && activeVC != creationVC)
            return NO;
    }

    // Dragging left reveals the inbox to the right of them, which a hidden
    // Messages tab must not leave reachable.
    if (SPKMessagesTabHidden() && (velocity.x < 0 || translation.x < 0)) {
        UIViewController *inboxVC = [SPKUtils getIvarForObj:self name:"_directInboxNavController"];
        if (activeVC && inboxVC && activeVC != inboxVC)
            return NO;
    }
    return %orig;
}
%end

%end

// Nothing to install while the tab bar is Instagram's own: Default layout, no
// hidden tab, no launch or swipe override and no Saved slot.
static BOOL SPKTabConfigurationIsCustomized(void) {
    if (SPKSavedTabPreferenceMayEnable())
        return YES;
    if (![SPKNormalizedTabLayout([SPKUtils getStringPref:SPKPrefTabLayout]) isEqualToString:SPKTabLayoutDefault])
        return YES;
    if (![[SPKUtils getStringPref:SPKPrefLaunchTab] isEqualToString:@"default"] ||
        ![[SPKUtils getStringPref:SPKPrefSwipeTabs] isEqualToString:@"default"])
        return YES;
    for (NSString *identifier in SPKTabEditableIdentifiers()) {
        if ([SPKUtils getBoolPref:SPKTabHidePreferenceKey(identifier)])
            return YES;
    }
    return [SPKUtils getBoolPref:SPKPrefHideTabBarWhenSingle];
}

extern "C" void SPKInstallNavigationHooksIfNeeded(void) {
    if (!SPKTabConfigurationIsCustomized())
        return;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        %init(SPKNavigationHooks,
                       IGHomeFeedHeaderView = SPKResolveIGClass(@"IGHomeFeedHeader.IGHomeFeedHeaderView", @"IGHomeFeedHeaderView"));
        if (SPKSavedTabPreferenceMayEnable()) {
            %init(SPKSavedTabButtonHooks);
            [[NSNotificationCenter defaultCenter] addObserverForName:SPKAccountDidChangeNotification
                                                              object:nil
                                                               queue:NSOperationQueue.mainQueue
                                                          usingBlock:^(__unused NSNotification *notification) {
                SPKScheduleSavedTabButtonReconciliation();
            }];
            dispatch_async(dispatch_get_main_queue(), ^{
                SPKScheduleSavedTabButtonReconciliation();
            });
        }
    });
}
