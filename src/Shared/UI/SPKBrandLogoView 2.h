#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// A premium, reusable vector-drawn Sparkle logo view with built-in twinkling
/// and breathing micro-animations. It automatically scales to fit its bounds.
@interface SPKBrandLogoView : UIView

@property (nonatomic, strong, readonly) UIView *mainStarContainer;
@property (nonatomic, strong, readonly) UIView *flankingStarsContainer;

/// Starts the twinkling and breathing animations.
- (void)startAnimating;

/// Stops the animations.
- (void)stopAnimating;

/// Dynamically scales and fades the logo parts based on the scroll progress of the onboarding sheet.
- (void)setScrollProgress:(CGFloat)progress;

@end

NS_ASSUME_NONNULL_END
