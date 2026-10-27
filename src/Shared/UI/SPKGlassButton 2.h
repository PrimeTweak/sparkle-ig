#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// A button that adopts iOS 26+ Liquid Glass (.prominentGlass)
/// and falls back cleanly to the standard solid-color prominent style on older iOS versions.
@interface SPKGlassButton : UIButton

- (void)setText:(NSString *)text;
- (void)setTextAnimated:(NSString *)text;

@end

NS_ASSUME_NONNULL_END
