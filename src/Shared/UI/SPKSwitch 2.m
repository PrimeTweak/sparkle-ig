// SPKSwitch — a UISwitch subclass that keeps its on-tint and thumb-tint matched
// to the Sparkle palette across trait/appearance changes (light/dark, app
// becoming active, window changes). Color application is re-scheduled shortly
// after state changes because the system can reset tints mid-animation,
// particularly with the iOS 26 Liquid Glass switch styling.
#import "SPKSwitch.h"

#import "../../Utils.h"

@implementation SPKSwitch

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self spk_commonInit];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        [self spk_commonInit];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    [self spk_applyColors];
    [self spk_scheduleColorRefresh];
}

- (void)didMoveToWindow {
    [super didMoveToWindow];
    [self spk_applyColors];
    [self spk_scheduleColorRefresh];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [self spk_applyColors];
}

- (void)setOn:(BOOL)on {
    [super setOn:on];
    [self spk_applyColors];
}

- (void)setOn:(BOOL)on animated:(BOOL)animated {
    [super setOn:on animated:animated];
    [self spk_applyColors];
    [self spk_scheduleColorRefresh];
}

- (void)spk_commonInit {
    [self spk_applyColors];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(spk_applyColors)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
}

- (UITraitCollection *)spk_effectiveTraitCollection {
    UITraitCollection *windowTraits = self.window.traitCollection;
    if (windowTraits.userInterfaceStyle != UIUserInterfaceStyleUnspecified) {
        return windowTraits;
    }
    return self.traitCollection;
}

- (void)spk_applyColors {
    UITraitCollection *traits = [self spk_effectiveTraitCollection];
    self.onTintColor = [SPKUtils SPKColor_SettingsSwitchOnTintForTraitCollection:traits];
    self.thumbTintColor = [SPKUtils SPKColor_SettingsSwitchThumbTintForTraitCollection:traits];
}

- (void)spk_scheduleColorRefresh {
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        [weakSelf spk_applyColors];
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [weakSelf spk_applyColors];
    });
}

@end
