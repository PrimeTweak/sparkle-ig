#import <objc/runtime.h>

#import "../../InstagramHeaders.h"
#import "../../Shared/ActionButton/ActionButtonCore.h"
#import "../../Shared/ActionButton/ActionButtonLookupUtils.h"
#import "../../Shared/ActionButton/SPKActionButtonConfiguration.h"
#import "../../Features/Instants/InstantsResolver.h"
#import "../../Utils.h"
#import "../../App/SPKPerfMeter.h"

// The aggregated media viewer (IGDirectAggregatedMediaViewerViewController) is the
// full-screen viewer opened when tapping a permanent photo/video in a DM thread
// (camera-roll media, chat-menu media, etc). IG only surfaces its own Save button in
// the title bar when the media is savable, which excludes camera-roll media. This
// feature forces the native Save slot on (via the title-view-model `canSave` flag),
// then drops Sparkle's action button into that exact slot — hiding IG's Save — so
// every photo/video gets the full download / gallery / share menu, in the native
// top-bar position.

static NSInteger const kSPKAggregatedActionButtonTag = 921345;
static const void *kSPKAggActionButtonMediaKey = &kSPKAggActionButtonMediaKey;

static NSString *const kSPKAggregatedTitleViewClass =
    @"_TtC44IGDirectAggregatedMediaViewerComponentsSwift52IGDirectAggregatedMediaViewerViewControllerTitleView";

// Stand-in interface for the Swift title view class, which is hooked by its mangled
// runtime name (bound to this symbol in %init below).
@interface SPKAggregatedTitleView : UIView
@end

static BOOL SPKAggregatedActionButtonEnabled(void) {
    return [SPKUtils getBoolPref:@"msgs_action_btn"] && [SPKUtils getBoolPref:@"msgs_action_btn_chat_media"];
}

// Snap variant that also points the DASH pipeline at the underlying IGVideo, so the
// download quality picker (SPKMediaQualityManager → SPKDashParser dashManifestForMedia:)
// can offer the video's quality ladder. The base snap only carries a single progressive
// URL; the IGVideo carries the DASH MPD manifest with every tier.
@interface SPKAggregatedResolvedSnap : SPKInstantsResolvedSnap
@property (nonatomic, strong) id spkDashVideo;
- (id)sparkleDashMedia;
@end

@implementation SPKAggregatedResolvedSnap
- (id)sparkleDashMedia {
    return self.spkDashVideo;
}
@end

static const void *kSPKAggConfigObserverAssocKey = &kSPKAggConfigObserverAssocKey;

#pragma mark - Media resolution

// Build a lightweight resolved snap the action button pipeline understands via the
// sparkle*URL hint path (see SPKEntryFromMediaObject). The current media lives in
// `_mediaDisplayedInUI` (IGDirectAggregatedMedia); its `content`
// (IGDirectAggregatedMediaContent) holds the underlying IGPhoto / IGVideo by ivar.
// In-chat photo/video messages are single-asset (one photo OR one video, no
// carousel) — reshared posts carry a full IGMedia, which the standard pipeline
// resolves directly (including carousels).
static id SPKAggregatedResolvedMediaFromController(UIViewController *controller) {
    if (!controller)
        return nil;

    id media = [SPKUtils getIvarForObj:controller name:"_mediaDisplayedInUI"];
    if (!media)
        media = SPKObjectForSelector(controller, @"mediaDisplayedInUI");
    if (!media)
        return nil;

    id content = SPKObjectForSelector(media, @"content");
    if (!content)
        content = [SPKUtils getIvarForObj:media name:"_content"];
    if (!content) {
        SPKLog(@"AggregatedMedia", @"resolve: no content on media class=%@", SPKClassName(media));
        return nil;
    }

    id photo = [SPKUtils getIvarForObj:content name:"_photo_photo"];
    id video = [SPKUtils getIvarForObj:content name:"_video_video"];
    id reshareMedia = [SPKUtils getIvarForObj:content name:"_reshareMedia_media"];

    NSString *mediaPK = SPKStringFromValue(SPKObjectForSelector(media, @"mediaId"));
    NSDate *timestamp = SPKObjectForSelector(media, @"timestamp");

    if (video) {
        NSURL *videoURL = [SPKUtils getVideoUrl:video];
        if (videoURL) {
            id overlayPhoto = [SPKUtils getIvarForObj:content name:"_video_overlayPhoto"];
            SPKAggregatedResolvedSnap *snap = [[SPKAggregatedResolvedSnap alloc] init];
            snap.sparkleIsVideo = YES;
            snap.sparkleVideoURL = videoURL;
            snap.sparklePhotoURL = overlayPhoto ? [SPKUtils getPhotoUrl:overlayPhoto] : nil;
            snap.sparkleMediaURL = videoURL;
            snap.sourceMediaPK = mediaPK;
            snap.importPostedDate = [timestamp isKindOfClass:[NSDate class]] ? timestamp : nil;
            snap.backingMedia = media;
            snap.spkDashVideo = video; // exposes the DASH manifest to the quality picker
            snap.resolverPath = @"aggregatedMediaViewer.video";
            return snap;
        }
    }

    if (photo) {
        NSURL *photoURL = [SPKUtils getPhotoUrl:photo];
        if (photoURL) {
            SPKInstantsResolvedSnap *snap = [[SPKInstantsResolvedSnap alloc] init];
            snap.sparkleIsVideo = NO;
            snap.sparklePhotoURL = photoURL;
            snap.sparkleMediaURL = photoURL;
            snap.sourceMediaPK = mediaPK;
            snap.importPostedDate = [timestamp isKindOfClass:[NSDate class]] ? timestamp : nil;
            snap.backingMedia = media;
            snap.resolverPath = @"aggregatedMediaViewer.photo";
            return snap;
        }
    }

    // Reshared posts carry a full IGMedia the standard pipeline can resolve directly.
    if (reshareMedia)
        return reshareMedia;

    SPKLog(@"AggregatedMedia", @"resolve: nothing downloadable (mediaId=%@)", mediaPK ?: @"(nil)");
    return nil;
}

static SPKActionButtonContext *SPKAggregatedActionContext(UIViewController *controller) {
    SPKActionButtonContext *context = [[SPKActionButtonContext alloc] init];
    context.source = SPKActionButtonSourceDirect;
    context.controller = controller;
    context.settingsTitle = SPKActionButtonTopicTitleForSource(SPKActionButtonSourceDirect);
    context.supportedActions = SPKActionButtonSupportedActionsForSource(SPKActionButtonSourceDirect);
    context.mediaResolver = ^id(SPKActionButtonContext *resolved) {
        return SPKAggregatedResolvedMediaFromController(resolved.controller);
    };
    context.bulkMediaResolver = ^id(SPKActionButtonContext *resolved) {
        return SPKAggregatedResolvedMediaFromController(resolved.controller);
    };
    context.currentIndexResolver = ^NSInteger(__unused SPKActionButtonContext *resolved) {
        return 0;
    };
    return context;
}

#pragma mark - Placement

// The native Save slot is only ~24pt, which is a small, easy-to-miss tap target next
// to the author name. Expand the button's hit area to the standard 44pt, centered on
// the native slot so the glyph stays visually in place.
static CGFloat const kSPKAggregatedButtonHitSize = 44.0;

static CGRect SPKAggregatedButtonFrame(UIView *nativeSave) {
    CGRect base = nativeSave.frame;
    CGFloat w = MAX(kSPKAggregatedButtonHitSize, base.size.width);
    CGFloat h = MAX(kSPKAggregatedButtonHitSize, base.size.height);
    return CGRectMake(CGRectGetMidX(base) - w / 2.0, CGRectGetMidY(base) - h / 2.0, w, h);
}

// Frame match used only for deciding whether to reposition. Deliberately ignores
// hidden/alpha: during the iOS 26 menu morph UIKit hides the real button and animates
// a snapshot, and we must not treat that transient state as "needs replacing".
static BOOL SPKAggregatedFrameMatches(UIButton *button, CGRect frame) {
    if (![button isKindOfClass:[UIButton class]] || !button.superview)
        return NO;
    return ABS(CGRectGetMinX(button.frame) - CGRectGetMinX(frame)) < 0.5 &&
           ABS(CGRectGetMinY(button.frame) - CGRectGetMinY(frame)) < 0.5 &&
           ABS(CGRectGetWidth(button.frame) - CGRectGetWidth(frame)) < 0.5 &&
           ABS(CGRectGetHeight(button.frame) - CGRectGetHeight(frame)) < 0.5;
}

// Title-bar styling: no shadow (the bar isn't over-media chrome), glyph tint follows
// the device light/dark appearance via the dynamic label color.
static void SPKStyleAggregatedButton(UIButton *button) {
    if (![button isKindOfClass:[SPKChromeButton class]])
        return;
    SPKChromeButton *chrome = (SPKChromeButton *)button;
    chrome.bubbleColor = UIColor.clearColor;
    chrome.iconTint = UIColor.labelColor;
    chrome.iconView.layer.shadowColor = UIColor.clearColor.CGColor;
    chrome.iconView.layer.shadowOpacity = 0.0;
    chrome.iconView.layer.shadowRadius = 0.0;
    chrome.iconView.layer.shadowOffset = CGSizeZero;
    chrome.iconView.layer.masksToBounds = NO;
}

// Changing the default tap action posts SPKActionButtonConfigurationDidChangeNotification;
// the shared pipeline observer reacts by reconfiguring the button, which resets the glyph
// tint to the fixed source color (white). Re-assert our dark-mode tint afterward. The
// double main-queue hop guarantees we run after the pipeline's own async reconfigure
// regardless of notification-observer ordering.
static void SPKAggregatedRegisterRestyleObserver(UIButton *button) {
    if (objc_getAssociatedObject(button, kSPKAggConfigObserverAssocKey))
        return;
    __weak UIButton *weakButton = button;
    id token = [[NSNotificationCenter defaultCenter] addObserverForName:SPKActionButtonConfigurationDidChangeNotification
                                                                object:nil
                                                                 queue:nil
                                                            usingBlock:^(__unused NSNotification *note) {
        dispatch_async(dispatch_get_main_queue(), ^{
            dispatch_async(dispatch_get_main_queue(), ^{
                UIButton *strong = weakButton;
                if (strong)
                    SPKStyleAggregatedButton(strong);
            });
        });
    }];
    objc_setAssociatedObject(button, kSPKAggConfigObserverAssocKey, token, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

// Drops the Sparkle action button into the title view, occupying the native Save
// button's frame, and hides the native one. Called from the title view's
// -layoutSubviews so it tracks the native slot.
static void SPKInstallAggregatedActionButton(UIView *titleView) {
    if (![titleView isKindOfClass:[UIView class]])
        return;

    id saveButtonObj = [SPKUtils getIvarForObj:titleView name:"saveButton"];
    UIView *nativeSave = [saveButtonObj isKindOfClass:[UIView class]] ? (UIView *)saveButtonObj : nil;
    UIButton *existing = (UIButton *)[titleView viewWithTag:kSPKAggregatedActionButtonTag];

    id delegate = SPKObjectForSelector(titleView, @"delegate");
    UIViewController *controller = [delegate isKindOfClass:[UIViewController class]] ? (UIViewController *)delegate : nil;

    if (!SPKAggregatedActionButtonEnabled() || !controller || !nativeSave) {
        [existing removeFromSuperview];
        nativeSave.hidden = NO;
        return;
    }

    // Defer until the first media is displayed. Configuring the menu with no media
    // builds it from media-independent actions only (that's the "only Deleted Messages
    // Log shows up" bug: the button is created during the viewer's early layout passes,
    // before `_mediaDisplayedInUI` is set).
    id currentMedia = [SPKUtils getIvarForObj:controller name:"_mediaDisplayedInUI"];
    if (!currentMedia && existing == nil)
        return;

    id lastMedia = existing ? objc_getAssociatedObject(existing, kSPKAggActionButtonMediaKey) : nil;

    // CRITICAL (iOS 26 menu morph): if our menu button is fully placed AND the media is
    // unchanged, return immediately and touch NOTHING. During the menu open/close
    // animation UIKit temporarily hides the real button and animates a snapshot; any
    // frame/hidden/alpha write here fights that animation and makes the button vanish.
    // Never gate on button.hidden/alpha — those belong to the animation, not us. The
    // media pointer never changes mid-morph, so reconfiguring on media change is safe.
    if (existing && existing.menu != nil && existing.superview == titleView &&
        SPKAggregatedFrameMatches(existing, SPKAggregatedButtonFrame(nativeSave)) && lastMedia == currentMedia) {
        return;
    }

    UIButton *button = existing;
    if (button == nil) {
        button = SPKActionButtonWithTag(titleView, kSPKAggregatedActionButtonTag);
        button.translatesAutoresizingMaskIntoConstraints = YES;
        SPKAggregatedRegisterRestyleObserver(button);
    }

    // Rebuild the menu whenever the displayed media changes (including the first time
    // real media arrives after an empty early build). Style AFTER configuring:
    // SPKConfigureActionButton resets the glyph tint to the fixed source color, so our
    // dark-mode-aware tint has to win by going last.
    if (lastMedia != currentMedia) {
        SPKConfigureActionButton(button, SPKAggregatedActionContext(controller));
        SPKStyleAggregatedButton(button);
        objc_setAssociatedObject(button, kSPKAggActionButtonMediaKey, currentMedia, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    nativeSave.hidden = YES;
    button.frame = SPKAggregatedButtonFrame(nativeSave);
    [titleView bringSubviewToFront:button];
}

// Force the media savable so IG lays out the native Save slot even for camera-roll
// media (which it would otherwise mark canSave = NO). The title-view model derives
// `canSave` from this flag; the ivar persists across per-item model rebuilds, so
// setting it once before -viewDidLoad is enough. We then hide the native button and
// occupy its frame with Sparkle's button.
static void SPKAggregatedForceSavable(UIViewController *controller) {
    if (!controller)
        return;
    @try {
        [controller setValue:@YES forKey:@"allowSavingMedia"];
    } @catch (__unused NSException *exception) {
    }
}

%group SPKAggregatedMediaActionButtonHooks

%hook IGDirectAggregatedMediaViewerViewController

- (void)viewDidLoad {
    if (SPKAggregatedActionButtonEnabled())
        SPKAggregatedForceSavable((UIViewController *)self);
    %orig;
}

- (void)viewWillAppear:(BOOL)animated {
    if (SPKAggregatedActionButtonEnabled())
        SPKAggregatedForceSavable((UIViewController *)self);
    %orig;
}

// Swiping between items settles on decelerate; nudge the title view to relayout so
// the button reconfigures/repositions for the newly displayed media.
- (void)scrollViewDidEndDecelerating:(id)scrollView {
    %orig;
    if (!SPKAggregatedActionButtonEnabled())
        return;
    id titleView = [SPKUtils getIvarForObj:self name:"_titleView"];
    if ([titleView isKindOfClass:[UIView class]])
        [(UIView *)titleView setNeedsLayout];
}

%end

%hook SPKAggregatedTitleView
- (void)layoutSubviews {
    %orig;
    SPK_PERF_SCOPE(@"AggregatedMediaActionButton.layoutSubviews");
    if (SPKAggregatedActionButtonEnabled()) {
        SPKInstallAggregatedActionButton((UIView *)self);
    } else {
        [[(UIView *)self viewWithTag:kSPKAggregatedActionButtonTag] removeFromSuperview];
    }
}
%end

%end

extern "C" void SPKInstallAggregatedMediaActionButtonHooksIfEnabled(void) {
    if (![SPKUtils getBoolPref:@"msgs_action_btn_chat_media"])
        return;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        %init(SPKAggregatedMediaActionButtonHooks,
              SPKAggregatedTitleView = objc_getClass(kSPKAggregatedTitleViewClass.UTF8String));
    });
}
