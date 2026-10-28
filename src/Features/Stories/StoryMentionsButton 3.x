#import <objc/message.h>
#import <objc/runtime.h>
#import <substrate.h>

#import "../../AssetUtils.h"
#import "../../InstagramHeaders.h"
#import "../../Shared/Stories/SPKStoryDynamicRange.h"
#import "../../Shared/Stories/SPKStoryMentions.h"
#import "../../Shared/UI/SPKChrome.h"
#import "../../Tweak.h"
#import "../../Utils.h"

#ifdef __cplusplus
extern "C" {
#endif
void SPKApplyButtonStyle(UIButton *button, NSInteger source);
#ifdef __cplusplus
}
#endif

static NSString *const kSPKStoryMentionsBarIconResource = @"mention";
static NSInteger const kSPKActionButtonSourceDirect = 4;
static NSInteger const kSPKStoryMentionsButtonTag = 926002;

extern void SPKPresentStoryMentionsSheet(UIView *overlayView);

static inline BOOL SPKStoryMentionsButtonEnabled(void) {
    return [SPKUtils getBoolPref:@"stories_mentions_btn"];
}
static void SPKPlayButtonTappedHaptic(void) {
    UISelectionFeedbackGenerator *feedback = [UISelectionFeedbackGenerator new];
    [feedback selectionChanged];
}
static UIButton *SPKStorySeenButtonWithTag(UIView *container, NSInteger tag) {
    UIView *existing = [container viewWithTag:tag];
    if ([existing isKindOfClass:SPKChromeButton.class]) {
        return (UIButton *)existing;
    }
    [existing removeFromSuperview];

    SPKChromeButton *button = [[SPKChromeButton alloc] initWithSymbol:@"" pointSize:24.0 diameter:44.0];
    button.tag = tag;
    button.adjustsImageWhenHighlighted = YES;
    button.showsMenuAsPrimaryAction = NO;
    button.clipsToBounds = NO;
    [container addSubview:button];
    return button;
}

static void SPKSetSeenButtonImage(UIButton *button, UIImage *image, NSString *logMessage) {
    UIImage *templatedImage = [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    if ([button isKindOfClass:SPKChromeButton.class]) {
        SPKChromeButton *chromeButton = (SPKChromeButton *)button;
        chromeButton.iconView.image = templatedImage;
        chromeButton.iconTint = UIColor.whiteColor;
        [button setImage:nil forState:UIControlStateNormal];
    } else {
        [button setImage:templatedImage forState:UIControlStateNormal];
    }

    SPKLog(@"Capture", @"%@ tag=%ld button=%@<%p> subviews=%@ imageView=%@<%p> imageSuperview=%@<%p>",
           logMessage,
           (long)button.tag,
           NSStringFromClass(button.class),
           button,
           button.subviews,
           NSStringFromClass(button.imageView.class),
           button.imageView,
           NSStringFromClass(button.imageView.superview.class),
           button.imageView.superview);
}

static void SPKApplyStoryMentionsButtonStyle(UIButton *button) {
    if (!button)
        return;
    SPKApplyButtonStyle(button, kSPKActionButtonSourceDirect);
    SPKStoryApplyDynamicRangeToButton(button);
}

void SPKRemoveStoryMentionsButton(UIView *overlayView) {
    UIButton *mentionsButton = (UIButton *)[overlayView viewWithTag:kSPKStoryMentionsButtonTag];
    [mentionsButton removeFromSuperview];
}

void SPKUpdateStoryMentionsButton(UIView *overlayView, CGFloat x, CGFloat y, CGFloat size) {
    // Same deduped, per-media cached source as the mentions sheet, so the button only
    // shows when the sheet has someone to list.
    BOOL showMentionsButton = SPKStoryMentionsButtonEnabled() && SPKStoryMentionCountForOverlay(overlayView) > 0;
    UIButton *mentionsButton = (UIButton *)[overlayView viewWithTag:kSPKStoryMentionsButtonTag];

    if (showMentionsButton && !mentionsButton) {
        mentionsButton = SPKStorySeenButtonWithTag(overlayView, kSPKStoryMentionsButtonTag);
        [mentionsButton addTarget:overlayView action:@selector(spk_storyMentionsButtonTapped:) forControlEvents:UIControlEventTouchUpInside];

        UIImage *mentionsImage = [SPKAssetUtils instagramIconNamed:kSPKStoryMentionsBarIconResource pointSize:24.0];
        SPKSetSeenButtonImage(mentionsButton, mentionsImage, @"Story mentions custom icon assigned");
    } else if (!showMentionsButton && mentionsButton) {
        [mentionsButton removeFromSuperview];
        mentionsButton = nil;
    }

    if (!showMentionsButton || !mentionsButton)
        return;
    SPKApplyStoryMentionsButtonStyle(mentionsButton);
    mentionsButton.frame = CGRectMake(x, y, size, size);
    [overlayView bringSubviewToFront:mentionsButton];
}

%group SPKStoryMentionsButtonHooks

%hook IGStoryFullscreenOverlayView
%new - (void)spk_storyMentionsButtonTapped:(UIButton *)sender {
(void)sender;
SPKPlayButtonTappedHaptic();
SPKPresentStoryMentionsSheet((UIView *)self);
}
%end

%end

void SPKInstallStoryMentionsButtonHooksIfNeeded(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        %init(SPKStoryMentionsButtonHooks);
    });
}
