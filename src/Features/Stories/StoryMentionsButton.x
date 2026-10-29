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

// Outside the capture-hiding tag range: the badge sits in the button's own
// redaction canvas, so the tag-based interception must not claim it.
static NSInteger const kSPKStoryMentionsBadgeTag = 927001;
static NSUInteger const kSPKStoryMentionsBadgeMaximum = 99;
static CGFloat const kSPKStoryMentionsBadgeHeight = 16.0;
// Pulled in from the corner so the badge overlaps the bubble and the glyph.
static CGFloat const kSPKStoryMentionsBadgeInset = 3.0;

static const void *kSPKStoryMentionsBadgeCountKey = &kSPKStoryMentionsBadgeCountKey;

extern void SPKPresentStoryMentionsSheet(UIView *overlayView);

static inline BOOL SPKStoryMentionsButtonEnabled(void) {
    return [SPKUtils getBoolPref:@"stories_mentions_btn"];
}

static inline BOOL SPKStoryMentionsCountBadgeEnabled(void) {
    return [SPKUtils getBoolPref:@"stories_mentions_count_badge"];
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

static void SPKSetSeenButtonImage(UIButton *button, UIImage *image) {
    UIImage *templatedImage = [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    if ([button isKindOfClass:SPKChromeButton.class]) {
        SPKChromeButton *chromeButton = (SPKChromeButton *)button;
        chromeButton.iconView.image = templatedImage;
        chromeButton.iconTint = UIColor.whiteColor;
        [button setImage:nil forState:UIControlStateNormal];
    } else {
        [button setImage:templatedImage forState:UIControlStateNormal];
    }
}

static NSString *SPKStoryMentionsLocalizedNumber(NSUInteger value) {
    static NSNumberFormatter *formatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSNumberFormatter alloc] init];
        formatter.numberStyle = NSNumberFormatterDecimalStyle;
        formatter.usesGroupingSeparator = NO;
    });
    return [formatter stringFromNumber:@(value)] ?: [NSString stringWithFormat:@"%lu", (unsigned long)value];
}

static NSString *SPKStoryMentionsBadgeText(NSUInteger count) {
    NSString *number = SPKStoryMentionsLocalizedNumber(MIN(count, kSPKStoryMentionsBadgeMaximum));
    if (count <= kSPKStoryMentionsBadgeMaximum)
        return number;
    return [number stringByAppendingString:@"+"];
}

static void SPKApplyStoryMentionsBadgeDynamicRange(SPKChromeButton *button, UILabel *badge) {
    UIColor *accent = [SPKUtils SPKColor_InstagramBlue];
    UIColor *background = SPKStoryDynamicRangeAccentTint(button, accent);
    UIColor *text = button.iconTint ?: UIColor.whiteColor;
    if (![badge.backgroundColor isEqual:background])
        badge.backgroundColor = background;
    if (![badge.textColor isEqual:text])
        badge.textColor = text;
    // The accent comes back unchanged on SDR stories.
    if (background != accent) {
        SPKChromeEnableExtendedDynamicRangeContent(badge);
        SPKChromeEnableExtendedDynamicRangeContent(badge.superview);
    }
}

// Runs from the overlay's layout pass, so it exits early while the rendered
// count is unchanged; the colours follow the button's SDR/EDR state every pass.
static void SPKUpdateStoryMentionsBadge(UIButton *button, NSUInteger count) {
    if (![button isKindOfClass:SPKChromeButton.class])
        return;
    SPKChromeButton *chromeButton = (SPKChromeButton *)button;

    BOOL showBadge = SPKStoryMentionsCountBadgeEnabled() && count > 0;
    UILabel *badge = (UILabel *)[chromeButton viewWithTag:kSPKStoryMentionsBadgeTag];

    if (!showBadge) {
        if (badge) {
            [badge removeFromSuperview];
            objc_setAssociatedObject(chromeButton, kSPKStoryMentionsBadgeCountKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        return;
    }

    if (badge)
        SPKApplyStoryMentionsBadgeDynamicRange(chromeButton, badge);

    NSNumber *rendered = objc_getAssociatedObject(chromeButton, kSPKStoryMentionsBadgeCountKey);
    if (badge && rendered && rendered.unsignedIntegerValue == count)
        return;

    if (!badge) {
        badge = [UILabel new];
        badge.tag = kSPKStoryMentionsBadgeTag;
        badge.translatesAutoresizingMaskIntoConstraints = NO;
        badge.textAlignment = NSTextAlignmentCenter;
        badge.font = [UIFont systemFontOfSize:10.0 weight:UIFontWeightBold];
        badge.textColor = UIColor.whiteColor;
        badge.backgroundColor = [SPKUtils SPKColor_InstagramBlue];
        badge.layer.cornerRadius = kSPKStoryMentionsBadgeHeight / 2.0;
        badge.layer.masksToBounds = YES;
        badge.adjustsFontSizeToFitWidth = YES;
        badge.minimumScaleFactor = 0.7;
        badge.userInteractionEnabled = NO;
        badge.isAccessibilityElement = NO;

        [chromeButton addChromeSubview:badge];

        UIView *anchor = chromeButton.chromeAnchorView;
        [NSLayoutConstraint activateConstraints:@[
            [badge.topAnchor constraintEqualToAnchor:anchor.topAnchor constant:kSPKStoryMentionsBadgeInset],
            [badge.trailingAnchor constraintEqualToAnchor:anchor.trailingAnchor constant:-kSPKStoryMentionsBadgeInset],
            [badge.widthAnchor constraintGreaterThanOrEqualToConstant:kSPKStoryMentionsBadgeHeight],
            [badge.heightAnchor constraintEqualToConstant:kSPKStoryMentionsBadgeHeight]
        ]];
    }

    SPKApplyStoryMentionsBadgeDynamicRange(chromeButton, badge);
    badge.text = SPKStoryMentionsBadgeText(count);
    objc_setAssociatedObject(chromeButton, kSPKStoryMentionsBadgeCountKey, @(count), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
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
    NSUInteger mentionCount = SPKStoryMentionCountForOverlay(overlayView);
    BOOL showMentionsButton = SPKStoryMentionsButtonEnabled() && mentionCount > 0;
    UIButton *mentionsButton = (UIButton *)[overlayView viewWithTag:kSPKStoryMentionsButtonTag];

    if (showMentionsButton && !mentionsButton) {
        mentionsButton = SPKStorySeenButtonWithTag(overlayView, kSPKStoryMentionsButtonTag);
        [mentionsButton addTarget:overlayView action:@selector(spk_storyMentionsButtonTapped:) forControlEvents:UIControlEventTouchUpInside];

        UIImage *mentionsImage = [SPKAssetUtils instagramIconNamed:kSPKStoryMentionsBarIconResource pointSize:24.0];
        SPKSetSeenButtonImage(mentionsButton, mentionsImage);
    } else if (!showMentionsButton && mentionsButton) {
        [mentionsButton removeFromSuperview];
        mentionsButton = nil;
    }

    if (!showMentionsButton || !mentionsButton)
        return;
    SPKApplyStoryMentionsButtonStyle(mentionsButton);
    SPKUpdateStoryMentionsBadge(mentionsButton, mentionCount);

    // VoiceOver reads the uncapped count as the button's value; the badge itself
    // is hidden from assistive tech.
    mentionsButton.isAccessibilityElement = YES;
    mentionsButton.accessibilityLabel = @"Mentions";
    mentionsButton.accessibilityValue = SPKStoryMentionsLocalizedNumber(mentionCount);

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
