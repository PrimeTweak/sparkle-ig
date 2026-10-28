#import "../../Utils.h"
#import <objc/runtime.h>
#import "../../App/SPKPerfMeter.h"

static const void *kSPKProfileHeaderSavedHiddenKey = &kSPKProfileHeaderSavedHiddenKey;
static const void *kSPKProfileHeaderSavedAlphaKey = &kSPKProfileHeaderSavedAlphaKey;

// Tracks whether we've ever hidden anything, so the disabled/default case can
// skip the subtree walk entirely (and only pays it once to restore after a
// toggle-off).
static BOOL sSPKProfileControlsEverApplied = NO;

static BOOL SPKProfileViewIsThreadsButton(UIView *view) {
    NSString *identifier = view.accessibilityIdentifier ?: @"";
    if ([identifier isEqualToString:@"profile-app-switch-button"])
        return YES;
    NSString *label = view.accessibilityLabel ?: @"";
    if ([label rangeOfString:@"switch to threads" options:NSCaseInsensitiveSearch].location != NSNotFound)
        return YES;
    return NO;
}

static BOOL SPKProfileViewIsNotesBubble(UIView *view) {
    NSString *className = NSStringFromClass(view.class);
    return [className containsString:@"IGDirectNotesThoughtBubbleView"];
}

static void SPKApplyProfileHeaderVisibility(UIView *view, BOOL hideThreads, BOOL hideNotes) {
    if (!view)
        return;
    BOOL shouldHide = (hideThreads && SPKProfileViewIsThreadsButton(view)) ||
                      (hideNotes && SPKProfileViewIsNotesBubble(view));
    NSNumber *savedHidden = objc_getAssociatedObject(view, kSPKProfileHeaderSavedHiddenKey);
    NSNumber *savedAlpha = objc_getAssociatedObject(view, kSPKProfileHeaderSavedAlphaKey);

    if (shouldHide) {
        if (!savedHidden) {
            objc_setAssociatedObject(view, kSPKProfileHeaderSavedHiddenKey, @(view.hidden), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            objc_setAssociatedObject(view, kSPKProfileHeaderSavedAlphaKey, @(view.alpha), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        view.hidden = YES;
        view.alpha = 0.0;
        return;
    }

    if (savedHidden || savedAlpha) {
        if (savedHidden)
            view.hidden = savedHidden.boolValue;
        if (savedAlpha)
            view.alpha = savedAlpha.doubleValue;
        objc_setAssociatedObject(view, kSPKProfileHeaderSavedHiddenKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(view, kSPKProfileHeaderSavedAlphaKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

static void SPKApplyProfileHeaderControlsInTree(UIView *view, BOOL hideThreads, BOOL hideNotes, NSUInteger depth) {
    if (!view || depth > 40)
        return;
    SPKApplyProfileHeaderVisibility(view, hideThreads, hideNotes);
    for (UIView *sub in view.subviews) {
        SPKApplyProfileHeaderControlsInTree(sub, hideThreads, hideNotes, depth + 1);
    }
}

// Applied only when a profile is on screen — never on the per-view, app-wide layout path
static void SPKApplyProfileHeaderControls(UIViewController *vc) {
    BOOL hideThreads = [SPKUtils getBoolPref:@"profile_hide_threads_btn"];
    BOOL hideNotes = [SPKUtils getBoolPref:@"profile_hide_notes_bubble"];
    if (!hideThreads && !hideNotes && !sSPKProfileControlsEverApplied)
        return;
    if (hideThreads || hideNotes)
        sSPKProfileControlsEverApplied = YES;

    SPKApplyProfileHeaderControlsInTree(vc.view, hideThreads, hideNotes, 0);
    UIView *navBar = vc.navigationController.navigationBar;
    if (navBar)
        SPKApplyProfileHeaderControlsInTree(navBar, hideThreads, hideNotes, 0);
}

%group SPKProfileHeaderControlsHooks

%hook IGProfileViewController
- (void)viewDidLayoutSubviews {
    %orig;
    SPK_PERF_SCOPE(@"ProfileHeaderControls.viewDidLayoutSubviews");
    SPKApplyProfileHeaderControls((UIViewController *)self);
}

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    SPKApplyProfileHeaderControls((UIViewController *)self);
}
%end

%end

extern "C" void SPKInstallProfileHeaderControlsHooksIfNeeded(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        %init(SPKProfileHeaderControlsHooks);
    });
}
