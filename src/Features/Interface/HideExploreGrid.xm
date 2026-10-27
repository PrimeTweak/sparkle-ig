#import <objc/runtime.h>

#import "../../InstagramHeaders.h"
#import "../../Utils.h"
#import "../../Shared/Account/SPKAccountManager.h"

static const void *kSPKExploreGridHiddenBySparkleKey = &kSPKExploreGridHiddenBySparkleKey;

%group SPKHideExploreGridHooks

%hook IGExploreGridViewController

- (void)viewDidLoad {
    %orig;
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(spk_updateExploreGridVisibility)
                                                 name:SPKHideExploreGridPreferenceDidChangeNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(spk_updateExploreGridVisibility)
                                                 name:SPKAccountDidChangeNotification
                                               object:nil];
    [self spk_updateExploreGridVisibility];
}

- (void)viewWillAppear:(BOOL)animated {
    %orig;
    [self spk_updateExploreGridVisibility];
}

%new
- (void)spk_updateExploreGridVisibility {
    BOOL hidden = [SPKUtils getBoolPref:@"interface_hide_explore_grid"];
    UIView *view = self.view;
    // Only a hide applied here is undone, so Instagram's own visibility is never overridden.
    if (hidden) {
        view.hidden = YES;
        objc_setAssociatedObject(view, kSPKExploreGridHiddenBySparkleKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    } else if (objc_getAssociatedObject(view, kSPKExploreGridHiddenBySparkleKey)) {
        view.hidden = NO;
        objc_setAssociatedObject(view, kSPKExploreGridHiddenBySparkleKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    SPKLog(@"General", @"[Sparkle] Explore grid visibility updated: %@", hidden ? @"hidden" : @"visible");
}

%end

%hook IGExploreViewController

- (void)viewDidLoad {
    %orig;
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(spk_updateExploreShimmerVisibility)
                                                 name:SPKHideExploreGridPreferenceDidChangeNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(spk_updateExploreShimmerVisibility)
                                                 name:SPKAccountDidChangeNotification
                                               object:nil];
    [self spk_updateExploreShimmerVisibility];
}

- (void)viewWillAppear:(BOOL)animated {
    %orig;
    [self spk_updateExploreShimmerVisibility];
}

%new
- (void)spk_updateExploreShimmerVisibility {
    // Instagram shows the loading shimmer again whenever a load starts, so it is only hidden here.
    if (![SPKUtils getBoolPref:@"interface_hide_explore_grid"])
        return;
    IGShimmeringGridView *shimmeringGridView = [SPKUtils getIvarForObj:self name:"_shimmeringGridView"];
    if ([shimmeringGridView isKindOfClass:[UIView class]])
        shimmeringGridView.hidden = YES;
}

%end

%end

extern "C" void SPKInstallHideExploreGridHooksIfEnabled(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        %init(SPKHideExploreGridHooks);
    });
}
