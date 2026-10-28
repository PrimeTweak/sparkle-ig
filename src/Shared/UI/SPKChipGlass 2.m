#import "SPKChipGlass.h"
#import <objc/runtime.h>

// Cached UIVisualEffectView (glass capsule) per chip, so selection changes only
// swap the effect instead of rebuilding the view + constraints each pass.
static const char kSPKChipGlassViewKey = 0;

// Liquid Glass adapts its material light/dark to the content scrolling behind it.
// A dark capsule would leave the chip's (statically dark) label unreadable, so we
// need the label to flip with the glass. UIKit propagates the glass's adapted
// appearance to its contentView's trait collection (this is why content hosted
// there stays legible), so a zero-size probe placed in the contentView reports
// the live style. We mirror that style onto the chip's title/image via
// overrideUserInterfaceStyle — never the whole chip, since the glass is a
// descendant of the chip and would otherwise be pinned to a fixed style (feedback
// loop). The chips already use Instagram's dynamic light/dark colors, so once the
// label resolves against the adapted style it reads correctly on either material.
@interface SPKGlassLegibilityProbe : UIView
@property (nonatomic, copy) void (^onStyleChange)(UIUserInterfaceStyle style);
@end

@implementation SPKGlassLegibilityProbe
- (void)traitCollectionDidChange:(UITraitCollection *)previous {
    [super traitCollectionDidChange:previous];
    if (previous.userInterfaceStyle != self.traitCollection.userInterfaceStyle && self.onStyleChange) {
        self.onStyleChange(self.traitCollection.userInterfaceStyle);
    }
}
@end

static void SPKApplyLegibilityStyle(UIButton *chip, UIUserInterfaceStyle style) {
    chip.titleLabel.overrideUserInterfaceStyle = style;
    chip.imageView.overrideUserInterfaceStyle = style;
}

BOOL SPKChipGlassAvailable(void) {
    if (@available(iOS 26.0, *)) {
        return NSClassFromString(@"UIGlassEffect") != nil;
    }
    return NO;
}

// UIGlassEffect ships in the iOS 26 SDK; this project builds against 16.2, so it
// is created and configured entirely at runtime. `interactive` and `tintColor`
// are real properties on the class — set via KVC to avoid referencing selectors
// the compiler doesn't know about.
static UIVisualEffect *SPKMakeGlassEffect(BOOL selected, UIColor *selectedTint) {
    Class glassClass = NSClassFromString(@"UIGlassEffect");
    if (!glassClass)
        return nil;
    id effect = [[glassClass alloc] init];
    if (![effect isKindOfClass:[UIVisualEffect class]])
        return nil;
    @try {
        [effect setValue:@YES forKey:@"interactive"];
    } @catch (__unused NSException *e) {
    }
    if (selected && selectedTint) {
        @try {
            [effect setValue:selectedTint forKey:@"tintColor"];
        } @catch (__unused NSException *e) {
        }
    }
    return effect;
}

BOOL SPKChipApplyGlass(UIButton *chip, BOOL selected, CGFloat cornerRadius, UIColor *selectedTint) {
    if (!chip || !SPKChipGlassAvailable())
        return NO;
    UIVisualEffect *effect = SPKMakeGlassEffect(selected, selectedTint);
    if (!effect)
        return NO;

    UIVisualEffectView *glass = objc_getAssociatedObject(chip, &kSPKChipGlassViewKey);
    if (!glass) {
        glass = [[UIVisualEffectView alloc] initWithEffect:effect];
        glass.translatesAutoresizingMaskIntoConstraints = NO;
        glass.userInteractionEnabled = NO; // taps pass through to the chip
        glass.clipsToBounds = YES;
        glass.layer.cornerCurve = kCACornerCurveContinuous;
        [chip insertSubview:glass atIndex:0];
        [NSLayoutConstraint activateConstraints:@[
            [glass.leadingAnchor constraintEqualToAnchor:chip.leadingAnchor],
            [glass.trailingAnchor constraintEqualToAnchor:chip.trailingAnchor],
            [glass.topAnchor constraintEqualToAnchor:chip.topAnchor],
            [glass.bottomAnchor constraintEqualToAnchor:chip.bottomAnchor],
        ]];
        objc_setAssociatedObject(chip, &kSPKChipGlassViewKey, glass, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

        // Keep the label/icon legible as the glass adapts (see class comment).
        SPKGlassLegibilityProbe *probe = [SPKGlassLegibilityProbe new];
        probe.userInteractionEnabled = NO;
        probe.hidden = YES;
        probe.translatesAutoresizingMaskIntoConstraints = NO;
        [glass.contentView addSubview:probe];
        [NSLayoutConstraint activateConstraints:@[
            [probe.leadingAnchor constraintEqualToAnchor:glass.contentView.leadingAnchor],
            [probe.topAnchor constraintEqualToAnchor:glass.contentView.topAnchor],
            [probe.widthAnchor constraintEqualToConstant:0.0],
            [probe.heightAnchor constraintEqualToConstant:0.0],
        ]];
        __weak UIButton *weakChip = chip;
        probe.onStyleChange = ^(UIUserInterfaceStyle style) {
            SPKApplyLegibilityStyle(weakChip, style);
        };
        SPKApplyLegibilityStyle(chip, probe.traitCollection.userInterfaceStyle);
    } else {
        glass.effect = effect;
        [chip sendSubviewToBack:glass]; // stay behind the title/image
    }
    glass.layer.cornerRadius = cornerRadius;
    chip.backgroundColor = [UIColor clearColor];
    return YES;
}
