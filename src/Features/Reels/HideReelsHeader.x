#import "HideReelsHeader.h"
#import "../../Utils.h"
#import "../../App/SPKPerfMeter.h"

NSNotificationName const SPKHideReelsHeaderDidChangeNotification = @"SPKHideReelsHeaderDidChangeNotification";

// Marks a bar Sparkle hid, so turning the preference off only restores those bars and never
// overrides Instagram hiding its own chrome.
static char kSPKReelsHeaderHiddenKey;

// Bars live for the whole session; weak membership lets a dismissed viewer's bar go.
static NSHashTable<UIView *> *SPKLiveReelsHeaders(void) {
    static NSHashTable *headers;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        headers = [NSHashTable weakObjectsHashTable];
    });
    return headers;
}

// Visibility is toggled rather than the bar removed: removal drops the constraints that position
// it, with no faithful way back.
static void SPKApplyReelsHeaderVisibility(UIView *bar) {
    BOOL hide = [SPKUtils getBoolPref:@"reels_hide_header"];
    BOOL hiddenBySparkle = [objc_getAssociatedObject(bar, &kSPKReelsHeaderHiddenKey) boolValue];

    if (hide && !hiddenBySparkle) {
        SPKLog(@"General", @"[Sparkle] Hiding reels header %@", NSStringFromClass([bar class]));
        bar.hidden = YES;
        objc_setAssociatedObject(bar, &kSPKReelsHeaderHiddenKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    } else if (!hide && hiddenBySparkle) {
        SPKLog(@"General", @"[Sparkle] Restoring reels header %@", NSStringFromClass([bar class]));
        bar.hidden = NO;
        objc_setAssociatedObject(bar, &kSPKReelsHeaderHiddenKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

static void SPKTrackReelsHeader(UIView *bar) {
    SPK_PERF_SCOPE(@"HideReelsHeader.didMoveToWindow");

    [SPKLiveReelsHeaders() addObject:bar];
    SPKApplyReelsHeaderVisibility(bar);
}

// Two navigation bars ship side by side and the server decides which one the reels viewer builds,
// so both are hooked; the Swift bar is the one in use on current builds.
%group SPKHideReelsHeaderHooks

// IGSundialViewerNavigationBarSwift.IGSundialViewerNavigationBar
%hook _TtC33IGSundialViewerNavigationBarSwift28IGSundialViewerNavigationBar
- (void)didMoveToWindow {
    %orig;
    SPKTrackReelsHeader(self);
}

// Instagram restoring its own chrome would otherwise undo the hide for the rest of the session.
- (void)setHidden:(BOOL)hidden {
    if (!hidden && [SPKUtils getBoolPref:@"reels_hide_header"]) {
        return %orig(YES);
    }
    %orig;
}
%end

%hook IGSundialViewerNavigationBarOld
- (void)didMoveToWindow {
    %orig;
    SPKTrackReelsHeader(self);
}

- (void)setHidden:(BOOL)hidden {
    if (!hidden && [SPKUtils getBoolPref:@"reels_hide_header"]) {
        return %orig(YES);
    }
    %orig;
}
%end

%end

void SPKInstallHideReelsHeaderHooksIfEnabled(void) {
    if (![SPKUtils getBoolPref:@"reels_hide_header"])
        return;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        %init(SPKHideReelsHeaderHooks);

        // Reconciles bars already built when the preference changes from settings.
        [[NSNotificationCenter defaultCenter] addObserverForName:SPKHideReelsHeaderDidChangeNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(__unused NSNotification *note) {
            for (UIView *bar in [SPKLiveReelsHeaders() allObjects]) {
                SPKApplyReelsHeaderVisibility(bar);
            }
        }];
    });
}
