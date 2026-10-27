#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import "../../InstagramHeaders.h"
#import "../../Utils.h"
#import "../../AssetUtils.h"
#import "../../Shared/Gallery/SPKGalleryPickerViewController.h"
#import "../../Shared/Gallery/SPKGalleryFile.h"
#import "../../Shared/UI/SPKChrome.h"

FOUNDATION_EXPORT void SPKInstallStoryVideoStickerHooksIfEnabled(void);

static NSString *const kSPKCategory = @"StoryVideoSticker";
static const NSInteger kSPKStickerGalleryButtonTag = 921341;


@interface IGStickerGalleryViewController (Sparkle)
- (void)spk_setupSparkleGalleryButton;
- (void)spk_didTapSparkleGallery;
@end

@interface IGStoryStickerTrayViewController (Sparkle)
- (void)spk_setupStickerTrayGalleryButton;
- (void)spk_didTapStickerTrayGallery;
@end

#pragma mark - Helpers

static IGStoryMediaCompositionEditingViewController *SPKFindStoryEditingViewController(UIViewController *startVC) {
    if (!startVC) startVC = topMostController();

    UIViewController *curr = startVC;
    while (curr) {
        if ([curr isKindOfClass:%c(IGStoryMediaCompositionEditingViewController)]) {
            return (IGStoryMediaCompositionEditingViewController *)curr;
        }
        if (curr.parentViewController && [curr.parentViewController isKindOfClass:%c(IGStoryMediaCompositionEditingViewController)]) {
            return (IGStoryMediaCompositionEditingViewController *)curr.parentViewController;
        }
        curr = curr.presentingViewController;
    }

    UIViewController *root = [UIApplication sharedApplication].keyWindow.rootViewController;
    NSMutableArray *queue = [NSMutableArray arrayWithObject:root];
    while (queue.count > 0) {
        UIViewController *vc = queue.firstObject;
        [queue removeObjectAtIndex:0];
        if (!vc) continue;
        if ([vc isKindOfClass:%c(IGStoryMediaCompositionEditingViewController)]) {
            return (IGStoryMediaCompositionEditingViewController *)vc;
        }
        // -presentedViewController also answers for ancestors, so enqueueing it
        // from every node would queue the same modal subtree once per node.
        UIViewController *presented = vc.presentedViewController;
        if (presented.presentingViewController == vc) {
            [queue addObject:presented];
        }
        for (UIViewController *child in vc.childViewControllers) {
            [queue addObject:child];
        }
    }

    return nil;
}

/// Creates a 24px icon-only navigation button wrapped inside SPKChromeCanvas so it
/// automatically redacts from screenshots and screen recordings when "Hide UI on Capture" is ON.
static UIView *SPKMakeGalleryIconButtonCanvas(NSInteger tag, id target, SEL action) {
    SPKChromeCanvas *canvas = [SPKChromeCanvas new];
    canvas.tag = tag;
    canvas.translatesAutoresizingMaskIntoConstraints = NO;

    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.translatesAutoresizingMaskIntoConstraints = NO;
    btn.tintColor = [UIColor whiteColor];
    [btn addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];

    UIImage *iconImg = [SPKAssetUtils instagramIconNamed:@"sparkle_gallery" pointSize:24.0 renderingMode:UIImageRenderingModeAlwaysTemplate];
    UIImageView *iconView = [[UIImageView alloc] initWithImage:iconImg];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.tintColor = [UIColor whiteColor];
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    iconView.userInteractionEnabled = NO;

    [btn addSubview:iconView];
    [NSLayoutConstraint activateConstraints:@[
        [btn.widthAnchor constraintEqualToConstant:28.0],
        [btn.heightAnchor constraintEqualToConstant:28.0],
        [iconView.centerXAnchor constraintEqualToAnchor:btn.centerXAnchor],
        [iconView.centerYAnchor constraintEqualToAnchor:btn.centerYAnchor],
        [iconView.widthAnchor constraintEqualToConstant:24.0],
        [iconView.heightAnchor constraintEqualToConstant:24.0],
    ]];

    [canvas.contentContainer addSubview:btn];
    [NSLayoutConstraint activateConstraints:@[
        [btn.leadingAnchor constraintEqualToAnchor:canvas.contentContainer.leadingAnchor],
        [btn.trailingAnchor constraintEqualToAnchor:canvas.contentContainer.trailingAnchor],
        [btn.topAnchor constraintEqualToAnchor:canvas.contentContainer.topAnchor],
        [btn.bottomAnchor constraintEqualToAnchor:canvas.contentContainer.bottomAnchor],
    ]];

    return canvas;
}

/// Traverses root subviews to find the header container holding IGGalleryTitleView
static UIView *SPKFindStickerGalleryNavContainer(UIView *root) {
    if (!root) return nil;
    for (UIView *sub in root.subviews) {
        for (UIView *child in sub.subviews) {
            NSString *cls = NSStringFromClass([child class]);
            if ([cls containsString:@"GalleryTitleView"]) {
                return sub;
            }
        }
        UIView *found = SPKFindStickerGalleryNavContainer(sub);
        if (found) return found;
    }
    return nil;
}

@interface UIView (SparkleVideoStickerCompat)
- (id)initWithModel:(id)model launcherSetProvider:(id)provider;
@end

static void SPKAddStickerFromGalleryFile(SPKGalleryFile *file, IGStoryMediaCompositionEditingViewController *editingVC) {
    if (!file || !file.filePath) {
        SPKWarnLog(kSPKCategory, @"Gallery file or path is nil");
        return;
    }

    if (!editingVC) {
        editingVC = SPKFindStoryEditingViewController(nil);
    }
    if (!editingVC) {
        SPKWarnLog(kSPKCategory, @"Could not find IGStoryMediaCompositionEditingViewController");
        return;
    }

    UIView *stickerView = nil;

    if (file.mediaType == SPKGalleryMediaTypeImage) {
        UIImage *image = [UIImage imageWithContentsOfFile:file.filePath];
        if (image) {
            Class stickerClass = %c(IGGalleryImageStickerView);
            if (stickerClass && [stickerClass instancesRespondToSelector:@selector(initWithImage:showStyleEducation:isCroppingEnabled:)]) {
                stickerView = [[stickerClass alloc] initWithImage:image showStyleEducation:NO isCroppingEnabled:YES];
            }
        }
    } else if (file.mediaType == SPKGalleryMediaTypeVideo) {
        NSURL *videoURL = [NSURL fileURLWithPath:file.filePath];
        AVURLAsset *avAsset = [AVURLAsset URLAssetWithURL:videoURL options:nil];
        Class clipClass = %c(IGVideoClip);
        Class modelClass = %c(IGGalleryVideoStickerModel);
        Class viewClass = %c(IGGalleryVideoStickerView);

        if (clipClass && modelClass && viewClass) {
            AVAssetTrack *videoTrack = [avAsset tracksWithMediaType:AVMediaTypeVideo].firstObject;
            CGSize naturalSize = CGSizeZero;
            if (videoTrack) {
                naturalSize = CGSizeApplyAffineTransform(videoTrack.naturalSize, videoTrack.preferredTransform);
                naturalSize = CGSizeMake(fabs(naturalSize.width), fabs(naturalSize.height));
            }

            IGVideoClip *clip;
            if ([clipClass instancesRespondToSelector:@selector(initWithAsset:position:sourceType:shouldBeSquare:)]) {
                clip = [[clipClass alloc] initWithAsset:avAsset position:0 sourceType:0 shouldBeSquare:NO];
            } else {
                clip = [[clipClass alloc] initWithAsset:avAsset position:0 sourceType:0];
            }

            CMTime duration = avAsset.duration;
            if (CMTIME_IS_VALID(duration) && duration.value > 0) {
                clip.endTime = duration;
                clip.compositionTimeRange = CMTimeRangeMake(kCMTimeZero, duration);
            }

            id model = [[modelClass alloc] initWithVideoClip:clip];
            if ([viewClass instancesRespondToSelector:@selector(initWithModel:)]) {
                stickerView = [[viewClass alloc] initWithModel:model];
            } else if ([viewClass instancesRespondToSelector:@selector(initWithModel:launcherSetProvider:)]) {
                stickerView = [[viewClass alloc] initWithModel:model launcherSetProvider:nil];
            }
            if (stickerView) {
                CGFloat targetWidth = 260.0;
                CGSize fitSize = CGSizeZero;
                if ([stickerView respondsToSelector:@selector(sizeThatFits:)]) {
                    fitSize = [stickerView sizeThatFits:CGSizeMake(targetWidth, CGFLOAT_MAX)];
                }
                if (fitSize.width <= 0 || fitSize.height <= 0) {
                    if (naturalSize.width > 0 && naturalSize.height > 0) {
                        CGFloat aspect = naturalSize.width / naturalSize.height;
                        fitSize = CGSizeMake(targetWidth, targetWidth / aspect);
                    } else {
                        fitSize = CGSizeMake(250.0, 350.0);
                    }
                }
                stickerView.bounds = CGRectMake(0, 0, fitSize.width, fitSize.height);
            }
        }
    }

    if (!stickerView) {
        SPKWarnLog(kSPKCategory, @"Failed to create sticker (type=%ld)", (long)file.mediaType);
        return;
    }

    // Method 1: direct didAddSticker:
    if ([editingVC respondsToSelector:@selector(didAddSticker:)]) {
        [editingVC didAddSticker:stickerView];
    }

    // Method 2: via stickerController delegates
    if ([editingVC respondsToSelector:@selector(stickerController)]) {
        id stickerCtrl = [editingVC stickerController];
        if (stickerCtrl) {
            SEL selSingle = @selector(stickerTrayViewController:didSelectSticker:);
            if ([stickerCtrl respondsToSelector:selSingle]) {
                NSMethodSignature *sig = [stickerCtrl methodSignatureForSelector:selSingle];
                if (sig) {
                    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
                    [inv setTarget:stickerCtrl];
                    [inv setSelector:selSingle];
                    id dummyTray = nil;
                    [inv setArgument:&dummyTray atIndex:2];
                    [inv setArgument:&stickerView atIndex:3];
                    [inv invoke];
                }
            }

            SEL selGroup = @selector(stickerTrayViewController:didSelectGalleryStickers:);
            if ([stickerCtrl respondsToSelector:selGroup]) {
                NSMethodSignature *sig = [stickerCtrl methodSignatureForSelector:selGroup];
                if (sig) {
                    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
                    [inv setTarget:stickerCtrl];
                    [inv setSelector:selGroup];
                    id dummyTray = nil;
                    NSArray *stickersArr = @[ stickerView ];
                    [inv setArgument:&dummyTray atIndex:2];
                    [inv setArgument:&stickersArr atIndex:3];
                    [inv invoke];
                }
            }
        }
    }

    // Method 3: direct video sticker selector
    if (file.mediaType == SPKGalleryMediaTypeVideo) {
        SEL selVideo = @selector(stickerViewController:didSelectGalleryVideoSticker:);
        if ([editingVC respondsToSelector:selVideo]) {
            NSMethodSignature *sig = [editingVC methodSignatureForSelector:selVideo];
            if (sig) {
                NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
                [inv setTarget:editingVC];
                [inv setSelector:selVideo];
                id dummyTray = nil;
                [inv setArgument:&dummyTray atIndex:2];
                [inv setArgument:&stickerView atIndex:3];
                [inv invoke];
            }
        }
    }

    SPKLog(kSPKCategory, @"Inserted %@ sticker successfully", file.mediaType == SPKGalleryMediaTypeVideo ? @"video" : @"image");

    // Ensure editing controls (toolbars, Next button) reappear immediately
    if ([editingVC respondsToSelector:@selector(setEditingControlsOverlayViewHidden:animated:)]) {
        [editingVC setEditingControlsOverlayViewHidden:NO animated:YES];
    }
}

/// Shared completion handler for both gallery-button entry points.
static void SPKHandleGalleryPickerSelection(NSArray<SPKGalleryFile *> *selectedFiles, UIViewController *presenter) {
    SPKGalleryFile *file = selectedFiles.firstObject;
    if (!file) return;

    IGStoryMediaCompositionEditingViewController *editingVC = SPKFindStoryEditingViewController(presenter);
    UIViewController *dismissTarget = editingVC ?: presenter;
    [dismissTarget dismissViewControllerAnimated:YES completion:^{
        SPKAddStickerFromGalleryFile(file, editingVC);
    }];
}

static void SPKPresentGalleryPickerFromHost(UIViewController *host) {
    BOOL allowVideo = [SPKUtils getBoolPref:@"stories_allow_video_sticker"];
    NSSet<NSNumber *> *allowedTypes = allowVideo ? [NSSet setWithObjects:@(SPKGalleryMediaTypeImage), @(SPKGalleryMediaTypeVideo), nil] : [NSSet setWithObject:@(SPKGalleryMediaTypeImage)];
    [SPKGalleryPickerViewController presentFromViewController:host
                                                       title:@"Sparkle Gallery"
                                           allowedMediaTypes:allowedTypes
                                     allowsMultipleSelection:NO
                                                  completion:^(NSArray<SPKGalleryFile *> *selectedFiles) {
        SPKHandleGalleryPickerSelection(selectedFiles, host);
    }];
}

/// Quiets the story canvas for as long as the picker is up.
///
/// IG presents the sticker tray *overFullScreen*, which keeps the story editor
/// mounted in the window behind it -- so the editor keeps playing its composition
/// underneath whatever we put on top. We cannot downgrade that presentation to
/// fullScreen without also killing the tray's own translucency (the tray and the
/// sticker gallery share one navigation controller), so pause the composition
/// instead and resume it once the picker is gone.
static void SPKQuietStoryCanvasWhilePickerIsUp(UIViewController *presenter) {
    IGStoryMediaCompositionEditingViewController *editingVC = SPKFindStoryEditingViewController(presenter);
    if (![editingVC respondsToSelector:@selector(pause)]) {
        return;
    }

    [editingVC pause];
    SPKLog(kSPKCategory, @"Paused story canvas for gallery picker");

    __block id token =
        [[NSNotificationCenter defaultCenter] addObserverForName:SPKGalleryPickerDidDismissNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(__unused NSNotification *note) {
                                                          if ([editingVC respondsToSelector:@selector(play)]) {
                                                              [editingVC play];
                                                              SPKLog(kSPKCategory, @"Resumed story canvas");
                                                          }
                                                          [[NSNotificationCenter defaultCenter] removeObserver:token];
                                                      }];
}

static void SPKPresentGalleryPicker(UIViewController *presenter) {
    SPKQuietStoryCanvasWhilePickerIsUp(presenter);
    SPKPresentGalleryPickerFromHost(presenter);
}

#pragma mark - IGStickerGalleryViewController (Photo Sticker Picker)

%hook IGStickerGalleryViewController

- (id)initWithUserSession:(id)session interfaceConfiguration:(id)configuration preferredMediaTypes:(NSArray *)types rangeStartDate:(id)startDate rangeEndDate:(id)endDate cameraDestination:(long long)destination {
    if ([SPKUtils getBoolPref:@"stories_allow_video_sticker"]) {
        if (types.count == 1 && [types.firstObject integerValue] == 1) {
            types = @[@1, @2];
        }
    }
    return %orig(session, configuration, types, startDate, endDate, destination);
}

- (void)viewDidLoad {
    %orig;
    if ([SPKUtils getBoolPref:@"stories_gallery_upload_sticker"]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self spk_setupSparkleGalleryButton];
        });
    }
}

%new
- (void)spk_setupSparkleGalleryButton {
    if ([self.view viewWithTag:kSPKStickerGalleryButtonTag]) return;

    UIView *iconButtonView = SPKMakeGalleryIconButtonCanvas(kSPKStickerGalleryButtonTag, self, @selector(spk_didTapSparkleGallery));
    [self.view addSubview:iconButtonView];
    [self.view bringSubviewToFront:iconButtonView];

    [NSLayoutConstraint activateConstraints:@[
        [iconButtonView.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:14.0],
        [iconButtonView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16.0],
    ]];
}

%new
- (void)spk_didTapSparkleGallery {
    SPKPresentGalleryPicker(self);
}

%end



#pragma mark - Media Type Overrides

%hook IGGalleryDataSource

- (void)setPreferredMediaTypes:(NSArray *)types {
    if ([SPKUtils getBoolPref:@"stories_allow_video_sticker"]) {
        if (types.count == 1 && [types.firstObject integerValue] == 1) {
            types = @[@1, @2];
        }
    }
    %orig(types);
}

%end

%hook IGGalleryAssetProvider

- (void)setPreferredMediaTypes:(NSArray *)types {
    if ([SPKUtils getBoolPref:@"stories_allow_video_sticker"]) {
        if (types.count == 1 && [types.firstObject integerValue] == 1) {
            types = @[@1, @2];
        }
    }
    %orig(types);
}

%end

#pragma mark - Installer

void SPKInstallStoryVideoStickerHooksIfEnabled(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        SPKLog(kSPKCategory, @"Initialized");
    });
}
