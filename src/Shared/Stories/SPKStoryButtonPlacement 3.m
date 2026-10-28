#import "SPKStoryButtonPlacement.h"

#import "../../Utils.h"
#import "../ActionButton/ActionButtonLookupUtils.h"

static CGFloat SPKStoryTrailingButtonX(UIView *overlayView, CGFloat size) {
    CGFloat width = CGRectGetWidth(overlayView.bounds);
    UIEdgeInsets safeInsets = overlayView.safeAreaInsets;

    CGFloat trailingInset = MAX(6.0, safeInsets.right + 6.0);
    return MAX(0.0, width - size - trailingInset);
}

CGRect SPKStoryFloatingButtonFrame(UIView *overlayView, CGFloat size) {
    if (!overlayView)
        return CGRectZero;

    if (size <= 0.0)
        size = 44.0;

    CGFloat y = 0.0;
    UIView *mediaView = [SPKUtils getIvarForObj:overlayView name:"_mediaView"];
    UIView *footerContainer = [SPKUtils getIvarForObj:overlayView name:"_footerContainerView"];
    if (![mediaView isKindOfClass:[UIView class]])
        mediaView = nil;
    if (![footerContainer isKindOfClass:[UIView class]])
        footerContainer = nil;

    if (mediaView) {
        CGRect mediaFrame = mediaView.frame;
        y = CGRectGetMaxY(mediaFrame) - size - 7.0;
        if (footerContainer && CGRectGetMinY(footerContainer.frame) < CGRectGetMaxY(mediaFrame)) {
            y -= 50.0;
        }
    } else if (footerContainer) {
        y = CGRectGetMinY(footerContainer.frame) - size - 12.0;
    } else {
        y = CGRectGetHeight(overlayView.bounds) - size - 12.0;
    }

    NSNumber *showCommentsPreview = [SPKUtils numericValueForObj:overlayView selectorName:@"showCommentsPreview"];
    if (!showCommentsPreview) {
        showCommentsPreview = [SPKUtils numericValueForObj:overlayView selectorName:@"isShowingCommentsPreview"];
    }
    if (!showCommentsPreview) {
        id kvcShowComments = SPKKVCObject(overlayView, @"showCommentsPreview");
        if ([kvcShowComments respondsToSelector:@selector(boolValue)]) {
            showCommentsPreview = @([kvcShowComments boolValue]);
        }
    }
    if (showCommentsPreview.boolValue) {
        UIView *hypeFaceswarmView = [SPKUtils getIvarForObj:overlayView name:"_hypeFaceswarmView"];
        if ([hypeFaceswarmView isKindOfClass:[UIView class]] && (y + size) > CGRectGetMinY(hypeFaceswarmView.frame)) {
            y = CGRectGetMinY(hypeFaceswarmView.frame) - size - 2.0;
        } else {
            y -= 35.0;
        }
    }

    return CGRectMake(SPKStoryTrailingButtonX(overlayView, size), y, size, size);
}
