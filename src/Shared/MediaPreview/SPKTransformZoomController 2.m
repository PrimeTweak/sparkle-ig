#import "SPKTransformZoomController.h"

static CGFloat const kVideoMaxZoom = 5.0;
static CGFloat const kVideoMinZoom = 1.0;
static CGFloat const kVideoZoomEpsilon = 0.02;

@interface SPKZoomScrollView : UIScrollView
@end

@implementation SPKZoomScrollView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    }
    return self;
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    if (gestureRecognizer == self.panGestureRecognizer) {
        // Only allow panning on the zoom scroll view when actually zoomed in.
        // This lets the parent page-scroll-view and vertical dismiss gestures
        // operate normally when the video is unzoomed at rest.
        return self.zoomScale > kVideoMinZoom + kVideoZoomEpsilon;
    }
    return [super gestureRecognizerShouldBegin:gestureRecognizer];
}

@end

/// Forward-declare so the display-link proxy (defined before @implementation) can call it.
@interface SPKTransformZoomController ()
- (void)updateTargetTransform;
@end

/// Weak-proxy target for `CADisplayLink` so the link does not retain the zoom
/// controller (CADisplayLink retains its target).
@interface _SPKDisplayLinkProxy : NSObject
@property (nonatomic, weak) SPKTransformZoomController *owner;
@end

@implementation _SPKDisplayLinkProxy
- (void)displayLinkFired:(CADisplayLink *)link {
    SPKTransformZoomController *strong = self.owner;
    if (strong) {
        [strong updateTargetTransform];
    } else {
        [link invalidate];
    }
}
@end

@interface SPKTransformZoomController () {
    SPKZoomScrollView *_scrollView;
    UIView *_dummyContentView;
    CADisplayLink *_displayLink;
    BOOL _lastReportedZoomState;
}
@end

@implementation SPKTransformZoomController

- (instancetype)initWithTargetView:(UIView *)targetView containerView:(UIView *)containerView {
    self = [super init];
    if (self) {
        _targetView = targetView;
        _containerView = containerView;

        CGRect bounds = containerView.bounds;
        if (CGRectIsEmpty(bounds)) {
            bounds = CGRectMake(0, 0, 375, 812);
        }

        _scrollView = [[SPKZoomScrollView alloc] initWithFrame:bounds];
        _scrollView.minimumZoomScale = kVideoMinZoom;
        _scrollView.maximumZoomScale = kVideoMaxZoom;
        _scrollView.delegate = self;
        _scrollView.showsHorizontalScrollIndicator = NO;
        _scrollView.showsVerticalScrollIndicator = NO;
        _scrollView.backgroundColor = [UIColor clearColor];
        _scrollView.userInteractionEnabled = YES;
        _scrollView.bouncesZoom = YES;

        [containerView insertSubview:_scrollView atIndex:0];

        _dummyContentView = [[UIView alloc] initWithFrame:bounds];
        _dummyContentView.backgroundColor = [UIColor clearColor];
        [_scrollView addSubview:_dummyContentView];
        _scrollView.contentSize = bounds.size;
        // Route the scroll view's gestures to containerView (the static parent view)
        [containerView addGestureRecognizer:_scrollView.pinchGestureRecognizer];
        [containerView addGestureRecognizer:_scrollView.panGestureRecognizer];
    }
    return self;
}

- (BOOL)isZoomed {
    return _scrollView.zoomScale > kVideoMinZoom + kVideoZoomEpsilon || _scrollView.isZooming || _scrollView.isZoomBouncing;
}

- (void)resetZoomAnimated:(BOOL)animated {
    [_scrollView setZoomScale:kVideoMinZoom animated:animated];
    if (!animated) {
        _targetView.transform = CGAffineTransformIdentity;
        [self stopDisplayLink];
    }
}

- (void)layoutZoomHelper {
    if (!_scrollView || !_containerView || !_dummyContentView)
        return;

    // Only resize when unzoomed so we do not distort active scaling transforms
    if (![self isZoomed]) {
        CGRect bounds = _containerView.bounds;
        _scrollView.frame = bounds;
        _dummyContentView.frame = bounds;
        _scrollView.contentSize = bounds.size;
    }
}

- (void)updateTargetTransform {
    if (!_targetView || !_scrollView || !_dummyContentView)
        return;

    // Use presentation layers to get the actual frame coordinates during active animations
    // (such as scroll view deceleration or zoom bounce).
    CALayer *dummyPres = _dummyContentView.layer.presentationLayer ?: _dummyContentView.layer;
    CALayer *containerPres = _containerView.layer.presentationLayer ?: _containerView.layer;
    
    CGRect targetFrame = [dummyPres convertRect:_dummyContentView.bounds toLayer:containerPres];

    CGFloat scale = targetFrame.size.width / _dummyContentView.bounds.size.width;
    
    CGPoint translation = CGPointZero;
    if (scale > 1.0) {
        CGPoint center = CGPointMake(CGRectGetMidX(targetFrame), CGRectGetMidY(targetFrame));
        CGPoint originalCenter = CGPointMake(_containerView.bounds.size.width * 0.5, _containerView.bounds.size.height * 0.5);
        translation = CGPointMake(center.x - originalCenter.x, center.y - originalCenter.y);
    }

    CGAffineTransform t = CGAffineTransformMakeTranslation(translation.x, translation.y);
    t = CGAffineTransformScale(t, scale, scale);
    _targetView.transform = t;
}

#pragma mark - UIScrollViewDelegate

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
    return _dummyContentView;
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    [self updateTargetTransform];
}

- (void)scrollViewDidZoom:(UIScrollView *)scrollView {
    [self updateTargetTransform];
    [self notifyZoomState];
}

- (void)scrollViewDidEndZooming:(UIScrollView *)scrollView withView:(nullable UIView *)view atScale:(CGFloat)scale {
    if (scale <= kVideoMinZoom + kVideoZoomEpsilon) {
        // Final cleanup — the display link tracked UIScrollView's own bounce
        // spring frame-by-frame, so the target view should already be at (or
        // very near) identity.  Force it exactly to avoid sub-pixel drift.
        _targetView.transform = CGAffineTransformIdentity;
    } else {
        [self updateTargetTransform];
    }
    [self stopDisplayLink];
    [self notifyZoomState];
}

- (void)scrollViewWillBeginZooming:(UIScrollView *)scrollView withView:(nullable UIView *)view {
    // Start tracking presentation-layer frames.  The link stays alive through
    // the entire gesture AND UIScrollView's bounce-back animation so the video
    // mirrors the exact same native spring curve that photos get for free.
    [self startDisplayLink];
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView {
    [self notifyZoomState];
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    [self updateTargetTransform];
    [self stopDisplayLink];
}

#pragma mark - Display Link

/// A display-link that fires every frame while a zoom gesture or bounce animation
/// is active, mirroring the dummy-view's presentation-layer transform onto the
/// real player view.  scrollViewDidZoom: alone under-samples the spring-back
/// animation, leaving the player at a stale sub-1.0 scale until the next touch.
- (void)startDisplayLink {
    if (_displayLink)
        return;
    _SPKDisplayLinkProxy *proxy = [[_SPKDisplayLinkProxy alloc] init];
    proxy.owner = self;
    _displayLink = [CADisplayLink displayLinkWithTarget:proxy selector:@selector(displayLinkFired:)];
    [_displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)stopDisplayLink {
    [_displayLink invalidate];
    _displayLink = nil;
}

- (void)notifyZoomState {
    BOOL zoomed = [self isZoomed];
    if (zoomed != _lastReportedZoomState) {
        _lastReportedZoomState = zoomed;
        if (self.zoomStateChangedBlock) {
            self.zoomStateChangedBlock(zoomed);
        }
    }
}

- (void)invalidate {
    [self stopDisplayLink];
}

- (void)dealloc {
    [self stopDisplayLink];
}

@end
