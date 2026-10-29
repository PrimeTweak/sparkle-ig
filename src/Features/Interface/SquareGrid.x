#import "../../AssetUtils.h"
#import "../../InstagramHeaders.h"
#import "../../Utils.h"
#import <objc/runtime.h>
#import <substrate.h>

// Squares the 3:4 tiles of profile and Explore grids, each with its own toggle.
// Explore closes a row at its tallest tile, so photo and Reels tiles are squared
// together; a double-height tile becomes two squares plus the row spacing.

static NSString *const kSPKSquareProfileGridPrefKey = @"profile_square_grid";
static NSString *const kSPKSquareExploreGridPrefKey = @"interface_explore_square_grid";

static BOOL SPKSquareProfileGridEnabled(void) {
    return [SPKUtils getBoolPref:kSPKSquareProfileGridPrefKey];
}

static BOOL SPKSquareExploreGridEnabled(void) {
    return [SPKUtils getBoolPref:kSPKSquareExploreGridPrefKey];
}

static BOOL SPKIsTallGridSize(CGSize size) {
    if (size.width <= 0.0 || size.height <= 0.0)
        return NO;
    CGFloat ratio = size.height / size.width;
    return ratio > 1.2 && ratio < 1.4;
}

// Configurations store width over height (0.75 for 3:4); the inverse form is
// recognized too in case a surface stores it.
static BOOL SPKIsPortraitGridAspectRatio(CGFloat ratio) {
    return (ratio > 1.2 && ratio < 1.4) || (ratio > 1.0 / 1.4 && ratio < 1.0 / 1.2);
}

// Double-height Explore tiles are two 3:4 rows plus the row spacing, recovered
// from the original height so the span stays aligned with the next column.
static CGSize SPKSquaredExploreTileSize(CGSize size) {
    if (SPKIsTallGridSize(size)) {
        size.height = size.width;
        return size;
    }
    if (size.width <= 0.0)
        return size;
    CGFloat spacing = size.height - 2.0 * size.width * 4.0 / 3.0;
    if (spacing >= 0.0 && spacing < 12.0)
        size.height = 2.0 * size.width + spacing;
    return size;
}

// Logs each distinct shape once, to show which grids the rewrite reaches.
static void SPKSquareGridLogOnce(NSString *key, NSString *message) {
    static NSMutableSet<NSString *> *seen;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        seen = [NSMutableSet set];
    });
    @synchronized(seen) {
        if ([seen containsObject:key] || seen.count > 64)
            return;
        [seen addObject:key];
    }
    SPKLog(@"SquareGrid", @"%@", message);
}

static NSString *SPKSquareGridHostName(id sectionController) {
    UIViewController *host = nil;
    if ([sectionController respondsToSelector:@selector(viewController)])
        host = ((UIViewController * (*)(id, SEL))objc_msgSend)(sectionController, @selector(viewController));
    return host ? NSStringFromClass(host.class) : @"nil";
}

static char kSPKShimmerHostKey;

typedef NS_ENUM(NSInteger, SPKShimmerHost) {
    SPKShimmerHostProfile = 1,
    SPKShimmerHostExplore,
    // The Adjust Preview crop editor mocks the real 3:4 grid, so it keeps its shape.
    SPKShimmerHostCropEditor,
};

static BOOL SPKViewIsInsideCropEditor(UIView *view) {
    Class cropEditor = NSClassFromString(@"IGProfileCropEditorView");
    if (!cropEditor)
        return NO;
    for (UIView *ancestor = view.superview; ancestor; ancestor = ancestor.superview) {
        if ([ancestor isKindOfClass:cropEditor])
            return YES;
    }
    return NO;
}

// The shared shimmer view follows the toggle of the screen hosting it, resolved
// once the view is on screen.
static BOOL SPKShimmerViewSquareEnabled(UIView *view) {
    NSNumber *cached = objc_getAssociatedObject(view, &kSPKShimmerHostKey);
    SPKShimmerHost host = cached.integerValue;
    if (!cached) {
        if (SPKViewIsInsideCropEditor(view)) {
            host = SPKShimmerHostCropEditor;
        } else if (view.window) {
            UIViewController *controller = [SPKUtils viewControllerForAncestralView:view];
            NSString *name = controller ? NSStringFromClass(controller.class) : @"";
            host = ([name containsString:@"Explore"] || [name containsString:@"Discovery"]) ? SPKShimmerHostExplore : SPKShimmerHostProfile;
        }
        if (host)
            objc_setAssociatedObject(view, &kSPKShimmerHostKey, @(host), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    switch (host) {
    case SPKShimmerHostCropEditor:
        return NO;
    case SPKShimmerHostExplore:
        return SPKSquareExploreGridEnabled();
    case SPKShimmerHostProfile:
        return SPKSquareProfileGridEnabled();
    default:
        return SPKSquareProfileGridEnabled() || SPKSquareExploreGridEnabled();
    }
}

%group SPKSquareGridHooks

%hook IGMediaThumbnailSectionController

- (CGSize)sizeForItemAtIndex:(NSInteger)index {
    CGSize size = %orig;
    if (!SPKSquareProfileGridEnabled() || !SPKIsTallGridSize(size))
        return size;
    size.height = size.width;
    return size;
}

%end

%hook IGDiscoveryMediaSectionController

- (CGSize)sizeForItemAtIndex:(NSInteger)index {
    CGSize size = %orig;
    if (!SPKSquareExploreGridEnabled())
        return size;
    SPKSquareGridLogOnce([NSString stringWithFormat:@"explore-media|%.2f", size.height / MAX(size.width, 1.0)],
                         [NSString stringWithFormat:@"explore media host=%@ size=%@", SPKSquareGridHostName(self), NSStringFromCGSize(size)]);
    return SPKSquaredExploreTileSize(size);
}

%end

%hook IGDiscoveryTopReelsSectionController

- (CGSize)sizeForItemAtIndex:(NSInteger)index {
    CGSize size = %orig;
    if (!SPKSquareExploreGridEnabled())
        return size;
    SPKSquareGridLogOnce([NSString stringWithFormat:@"explore-reels|%.2f", size.height / MAX(size.width, 1.0)],
                         [NSString stringWithFormat:@"explore reels host=%@ size=%@", SPKSquareGridHostName(self), NSStringFromCGSize(size)]);
    return SPKSquaredExploreTileSize(size);
}

%end

%hook IGDSShimmeringGridModel

- (instancetype)initWithLayoutConfiguration:(SPKGridLayoutConfiguration)configuration pattern:(id)pattern contentInset:(UIEdgeInsets)inset shimmering:(BOOL)shimmering {
    // Created before it joins a screen, so either toggle squares it; the view
    // hook below still follows the hosting screen.
    if ((SPKSquareProfileGridEnabled() || SPKSquareExploreGridEnabled()) && SPKIsPortraitGridAspectRatio(configuration.aspectRatio))
        configuration.aspectRatio = 1.0;
    return %orig(configuration, pattern, inset, shimmering);
}

%end

%hook IGDSShimmeringGridView

- (CGSize)layoutDataSourceCollectionView:(id)view layout:(id)layout sizeForItemAtIndexPath:(NSIndexPath *)path {
    CGSize size = %orig;
    if (SPKIsTallGridSize(size) && SPKShimmerViewSquareEnabled(self))
        size.height = size.width;
    return size;
}

%end

%end

static BOOL (*orig_profileGridUseVariableAspectRatio)(id, SEL, id);
static BOOL hooked_profileGridUseVariableAspectRatio(id self, SEL _cmd, id launcherSet) {
    if (SPKSquareProfileGridEnabled())
        return NO;
    return orig_profileGridUseVariableAspectRatio(self, _cmd, launcherSet);
}

// Newer builds drop the gating service's Objective-C entry point, so the flag
// on the section controller is held off as well.
static BOOL (*orig_thumbnailUsesVariableAspectRatio)(id, SEL);
static BOOL hooked_thumbnailUsesVariableAspectRatio(id self, SEL _cmd) {
    if (SPKSquareProfileGridEnabled())
        return NO;
    return orig_thumbnailUsesVariableAspectRatio(self, _cmd);
}

static void (*orig_thumbnailSetUsesVariableAspectRatio)(id, SEL, BOOL);
static void hooked_thumbnailSetUsesVariableAspectRatio(id self, SEL _cmd, BOOL uses) {
    orig_thumbnailSetUsesVariableAspectRatio(self, _cmd, SPKSquareProfileGridEnabled() ? NO : uses);
}

// Square glyph for the tall grid tab icon, or nil for another tab's icon. The
// asset name tagged on the image is the signal, so per-tab and shared segment
// classes are covered alike.
static UIImage *SPKSquareGridTabIcon(UIImage *icon) {
    NSString *name = [SPKUtils igImageNameForImage:icon];
    if (![name containsString:@"photo_grid_tall"])
        return nil;
    NSString *squareName = [name stringByReplacingOccurrencesOfString:@"_tall" withString:@""];
    return [SPKAssetUtils instagramIconNamed:squareName pointSize:icon.size.width > 0.0 ? icon.size.width : 24.0 renderingMode:icon.renderingMode];
}

// The newer grid segment class only returns the grid glyph, so an image with no
// asset name gets the known square asset directly.
static UIImage *SPKSquareGridSegmentIcon(UIImage *icon, BOOL filled) {
    UIImage *square = SPKSquareGridTabIcon(icon);
    if (square || [SPKUtils igImageNameForImage:icon])
        return square;
    return [SPKAssetUtils instagramIconNamed:(filled ? @"ig_icon_photo_grid_filled_24" : @"ig_icon_photo_grid_outline_24")
                                   pointSize:icon.size.width > 0.0 ? icon.size.width : 24.0
                               renderingMode:icon ? icon.renderingMode : UIImageRenderingModeAlwaysTemplate];
}

static id (*orig_segmentFallbackIcon)(id, SEL);
static id hooked_segmentFallbackIcon(id self, SEL _cmd) {
    id icon = orig_segmentFallbackIcon(self, _cmd);
    if (!SPKSquareProfileGridEnabled())
        return icon;
    return SPKSquareGridSegmentIcon(icon, NO) ?: icon;
}

static id (*orig_segmentFallbackPrismActiveIcon)(id, SEL);
static id hooked_segmentFallbackPrismActiveIcon(id self, SEL _cmd) {
    id icon = orig_segmentFallbackPrismActiveIcon(self, _cmd);
    if (!SPKSquareProfileGridEnabled())
        return icon;
    return SPKSquareGridSegmentIcon(icon, YES) ?: icon;
}

static id (*orig_legacySegmentFallbackIcon)(id, SEL);
static id hooked_legacySegmentFallbackIcon(id self, SEL _cmd) {
    id icon = orig_legacySegmentFallbackIcon(self, _cmd);
    if (!SPKSquareProfileGridEnabled())
        return icon;
    return SPKSquareGridTabIcon(icon) ?: icon;
}

static id (*orig_legacySegmentFallbackPrismActiveIcon)(id, SEL);
static id hooked_legacySegmentFallbackPrismActiveIcon(id self, SEL _cmd) {
    id icon = orig_legacySegmentFallbackPrismActiveIcon(self, _cmd);
    if (!SPKSquareProfileGridEnabled())
        return icon;
    return SPKSquareGridTabIcon(icon) ?: icon;
}

static void SPKHookInstanceMethod(const char *className, SEL selector, IMP replacement, IMP *original) {
    Class cls = objc_getClass(className);
    if (cls && class_getInstanceMethod(cls, selector))
        MSHookMessageEx(cls, selector, replacement, original);
}

static void SPKHookClassMethod(const char *className, SEL selector, IMP replacement, IMP *original) {
    Class cls = objc_getClass(className);
    if (cls && class_getClassMethod(cls, selector))
        MSHookMessageEx(object_getClass(cls), selector, replacement, original);
}

extern void SPKInstallSquareGridHooksIfEnabled(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        %init(SPKSquareGridHooks);
        SPKHookClassMethod("_TtC22IGProfileGatingService22IGProfileGatingService",
                           @selector(profileGridUseVariableAspectRatioWithLauncherSet:),
                           (IMP)hooked_profileGridUseVariableAspectRatio,
                           (IMP *)&orig_profileGridUseVariableAspectRatio);
        SPKHookInstanceMethod("IGMediaThumbnailSectionController",
                              @selector(usesVariableAspectRatio),
                              (IMP)hooked_thumbnailUsesVariableAspectRatio,
                              (IMP *)&orig_thumbnailUsesVariableAspectRatio);
        SPKHookInstanceMethod("IGMediaThumbnailSectionController",
                              @selector(setUsesVariableAspectRatio:),
                              (IMP)hooked_thumbnailSetUsesVariableAspectRatio,
                              (IMP *)&orig_thumbnailSetUsesVariableAspectRatio);
        // Posts tab segment: a Swift class on newer builds, the shared segment
        // class on 441.
        SPKHookInstanceMethod("_TtC15IGProfilePluginP33_8E4C0B5300E00051E8F92B34A684A10523IGProfileGridTabSegment",
                              @selector(fallbackIcon), (IMP)hooked_segmentFallbackIcon, (IMP *)&orig_segmentFallbackIcon);
        SPKHookInstanceMethod("_TtC15IGProfilePluginP33_8E4C0B5300E00051E8F92B34A684A10523IGProfileGridTabSegment",
                              @selector(fallbackPrismActiveIcon), (IMP)hooked_segmentFallbackPrismActiveIcon, (IMP *)&orig_segmentFallbackPrismActiveIcon);
        SPKHookInstanceMethod("IGProfileTabControlSegment",
                              @selector(fallbackIcon), (IMP)hooked_legacySegmentFallbackIcon, (IMP *)&orig_legacySegmentFallbackIcon);
        SPKHookInstanceMethod("IGProfileTabControlSegment",
                              @selector(fallbackPrismActiveIcon), (IMP)hooked_legacySegmentFallbackPrismActiveIcon, (IMP *)&orig_legacySegmentFallbackPrismActiveIcon);
    });
}
