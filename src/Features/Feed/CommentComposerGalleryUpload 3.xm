#import <objc/message.h>
#import <objc/runtime.h>

#import "../../InstagramHeaders.h"
#import "../../Shared/Gallery/SPKGalleryFile.h"
#import "../../Shared/Gallery/SPKGalleryPickerViewController.h"
#import "../../Shared/UI/SPKNotificationCenter.h"
#import "../../Utils.h"
#import "../../App/SPKPerfMeter.h"

// Long-press the comment composer's photo entry button to attach an image from the
// in-app Sparkle Gallery. A normal tap still opens Instagram's own photo
// gallery; the long-press routes through our gallery picker sheet instead and feeds
// the chosen image into the composer via the same entry point IG uses internally
// (-setupImageBeforeCommentComposingBeginWithSelectedPhoto:, which takes a UIImage).

static NSString *const kSPKCommentGalleryUploadPref = @"general_comments_gallery_upload";
static const void *kSPKCommentGalleryGestureKey = &kSPKCommentGalleryGestureKey;

static inline BOOL SPKCommentGalleryUploadEnabled(void) {
    return [SPKUtils getBoolPref:kSPKCommentGalleryUploadPref];
}

// _lazyPhotoEntryButton / _lazyPhotoCommentButton are IGLazyView wrappers (NOT UIViews).
// The real button view is created lazily and retrieved via -viewIfLoaded.
static UIView *SPKCommentComposerLoadedView(id lazyView) {
    if (![lazyView respondsToSelector:@selector(viewIfLoaded)])
        return nil;
    id view = ((id (*)(id, SEL))objc_msgSend)(lazyView, @selector(viewIfLoaded));
    return [view isKindOfClass:[UIView class]] ? (UIView *)view : nil;
}

static UIView *SPKCommentComposerPhotoEntryButton(UIView *composerView) {
    for (NSString *ivar in @[ @"_lazyPhotoEntryButton", @"_lazyPhotoCommentButton" ]) {
        id lazyView = [SPKUtils getIvarForObj:composerView name:ivar.UTF8String];
        if (!lazyView)
            continue;
        UIView *button = SPKCommentComposerLoadedView(lazyView);
        if (button && button.window) {
            return button;
        }
    }
    return nil;
}

// The composer view's delegate is the IGCommentComposerController, which exposes the
// public attach entry point used here. Walk up from the button to find the composer.
static UIView *SPKCommentComposerViewForView(UIView *view) {
    UIView *candidate = view;
    while (candidate && ![candidate isKindOfClass:NSClassFromString(@"IGCommentComposerView")]) {
        candidate = candidate.superview;
    }
    return candidate;
}

static void SPKCommentComposerAttachImage(UIView *composerView, UIImage *image) {
    if (!composerView || !image)
        return;
    id controller = nil;
    if ([composerView respondsToSelector:@selector(delegate)]) {
        controller = ((id (*)(id, SEL))objc_msgSend)(composerView, @selector(delegate));
    }
    SEL setup = @selector(setupImageBeforeCommentComposingBeginWithSelectedPhoto:);
    if (![controller respondsToSelector:setup]) {
        SPKNotify(kSPKNotificationDownloadGallery, @"Couldn't attach photo", nil, @"error", SPKNotificationToneError);
        return;
    }
    @try {
        ((void (*)(id, SEL, id))objc_msgSend)(controller, setup, image);
    } @catch (NSException *exception) {
        SPKLog(@"Comments", @"[Sparkle] attach photo threw: %@", exception);
    }
}

static void SPKCommentComposerPresentGalleryPicker(UIView *composerView) {
    if (!composerView)
        return;

    NSSet<NSNumber *> *imageTypes = [NSSet setWithObject:@(SPKGalleryMediaTypeImage)];
    if (![SPKGalleryPickerViewController hasSelectableFilesForAllowedMediaTypes:imageTypes]) {
        SPKNotify(kSPKNotificationDownloadGallery, @"No photos in Gallery", nil, @"sparkle_gallery", SPKNotificationToneError);
        return;
    }

    UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [feedback impactOccurred];

    __weak UIView *weakComposer = composerView;
    [SPKGalleryPickerViewController presentFromViewController:topMostController()
                                                        title:@"Choose Photo"
                                            allowedMediaTypes:imageTypes
                                      allowsMultipleSelection:NO
                                                   completion:^(NSArray<SPKGalleryFile *> *selectedFiles) {
                                                       SPKGalleryFile *file = selectedFiles.firstObject;
                                                       UIImage *image = file ? [UIImage imageWithContentsOfFile:file.filePath] : nil;
                                                       if (image)
                                                           SPKCommentComposerAttachImage(weakComposer, image);
                                                   }];
}

@interface SPKCommentGalleryUploadTarget : NSObject
+ (instancetype)shared;
- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture;
@end

@implementation SPKCommentGalleryUploadTarget
+ (instancetype)shared {
    static SPKCommentGalleryUploadTarget *target;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        target = [[SPKCommentGalleryUploadTarget alloc] init];
    });
    return target;
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan)
        return;
    if (!SPKCommentGalleryUploadEnabled())
        return;
    SPKCommentComposerPresentGalleryPicker(SPKCommentComposerViewForView(gesture.view));
}
@end

static void SPKCommentComposerInstallLongPress(UIView *composerView) {
    if (!SPKCommentGalleryUploadEnabled())
        return;

    UIView *photoButton = SPKCommentComposerPhotoEntryButton(composerView);
    if (!photoButton)
        return;
    if (objc_getAssociatedObject(photoButton, kSPKCommentGalleryGestureKey))
        return;

    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc]
        initWithTarget:[SPKCommentGalleryUploadTarget shared]
                action:@selector(handleLongPress:)];
    [photoButton addGestureRecognizer:longPress];
    objc_setAssociatedObject(photoButton, kSPKCommentGalleryGestureKey, longPress, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

%group SPKCommentComposerGalleryUploadHooks

%hook IGCommentComposerView

- (void)layoutSubviews {
    %orig;
    SPK_PERF_SCOPE(@"CommentComposerGalleryUpload.layoutSubviews");
    SPKCommentComposerInstallLongPress((UIView *)self);
}

%end

%end

extern "C" void SPKInstallCommentComposerGalleryUploadHooksIfEnabled(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        %init(SPKCommentComposerGalleryUploadHooks);
    });
}
