#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// A Sparkle-styled pill button whose progress fills inside the pill (originally the Profile
/// Analyzer scan button). Theme-aware: the pill fill tracks the primary-text color (white-ish in
/// dark, black-ish in light) and the title is the inverse, so it "fills up" while busy without a
/// contrast-breaking accent color. Add a target/action as with any \c UIControl.
@interface SPKProgressPillButton : UIControl

/// 0..1 fill fraction. Only visible while \c busy is YES.
@property (nonatomic, assign) double progress;

/// When YES the pill dims its track and reveals the progress fill; setting NO resets progress.
@property (nonatomic, assign, getter=isBusy) BOOL busy;

- (void)setText:(NSString *)text;
/// Like \c setText: but cross-dissolves the label when the text actually changes.
/// Use for discrete state swaps (e.g. "Scan Now" ⇄ "Scan Again"); keep
/// rapid updates (progress status) on \c setText: to avoid flicker.
- (void)setTextAnimated:(NSString *)text;
- (void)setProgress:(double)progress animated:(BOOL)animated;

@end

NS_ASSUME_NONNULL_END
