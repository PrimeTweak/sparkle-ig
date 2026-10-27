#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SPKTransformZoomController : NSObject <UIScrollViewDelegate>

@property (nonatomic, weak, readonly) UIView *targetView;
@property (nonatomic, weak, readonly) UIView *containerView;
@property (nonatomic, copy, nullable) void (^zoomStateChangedBlock)(BOOL isZoomed);

- (instancetype)initWithTargetView:(UIView *)targetView containerView:(UIView *)containerView;
- (void)resetZoomAnimated:(BOOL)animated;
- (BOOL)isZoomed;
- (void)layoutZoomHelper;
/// Tears down the display link; call before releasing the controller.
- (void)invalidate;

@end

NS_ASSUME_NONNULL_END
