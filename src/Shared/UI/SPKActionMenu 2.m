#import "SPKActionMenu.h"

// The same numbers SPKToggleMenu draws with, kept here rather than imported so
// this menu never depends on the settings tree.
//
// Floor and ceiling meet: every menu is this wide. A floor above the ceiling
// would have been silently clamped, so the two are one value and the card no
// longer changes size with its contents.
static CGFloat const kSPKActionMenuMinWidth = 240.0;
// A ceiling as well as a floor. Without one the widest row set the width for
// every other and the card ran to 343 pt on a 440 pt screen, past what a system
// menu occupies — measured at 250 pt in Files. This sits a little under that,
// which is the narrowest every title still fits: the longest, "Stop marking
// messages", needs 238.5 pt. Rows longer than this truncate, as the system's do.
static CGFloat const kSPKActionMenuMaxWidth = 240.0;
static CGFloat const kSPKActionMenuRowHeight = 44.0;
static CGFloat const kSPKActionMenuCornerRadius = 13.0;
static CGFloat const kSPKActionMenuIconSize = 22.0;
static CGFloat const kSPKActionMenuHPad = 14.0;
static CGFloat const kSPKActionMenuIconGap = 12.0;
static CGFloat const kSPKActionMenuScreenMargin = 20.0;
static CGFloat const kSPKActionMenuContentPadding = 6.0;
static CGFloat const kSPKActionMenuAnchorGap = 6.0;
static CGFloat const kSPKActionMenuTitleSize = 16.0;
static CGFloat const kSPKActionMenuChevronWidth = 18.0;

#pragma mark - Node

@interface SPKActionMenuNode ()
@property (nonatomic, copy, readwrite) NSString *title;
@property (nonatomic, strong, readwrite, nullable) UIImage *image;
@property (nonatomic, copy, readwrite, nullable) dispatch_block_t handler;
@property (nonatomic, copy, readwrite, nullable) NSArray<SPKActionMenuNode *> *children;
@end

@implementation SPKActionMenuNode

+ (instancetype)leafWithTitle:(NSString *)title
                        image:(UIImage *)image
                      handler:(dispatch_block_t)handler {
    SPKActionMenuNode *node = [self new];
    node.title = title ?: @"";
    node.image = image;
    node.handler = handler;
    return node;
}

+ (instancetype)branchWithTitle:(NSString *)title
                          image:(UIImage *)image
                       children:(NSArray<SPKActionMenuNode *> *)children {
    SPKActionMenuNode *node = [self new];
    node.title = title ?: @"";
    node.image = image;
    node.children = [children copy];
    return node;
}

@end

#pragma mark - Row

typedef NS_ENUM(NSInteger, SPKActionMenuRowKind) {
    SPKActionMenuRowKindLeaf = 0,
    SPKActionMenuRowKindBranch,
    SPKActionMenuRowKindHeader   // the submenu's own row, tapped to go back
};

@interface SPKActionMenuRow : UIControl
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIImageView *chevronView;
@property (nonatomic, assign) SPKActionMenuRowKind kind;
/// Same shape as SPKToggleMenu's controls: a block set by the presenter, fired
/// through addTarget:action: — the only control pattern this project uses.
@property (nonatomic, copy, nullable) dispatch_block_t tapHandler;
@end

@implementation SPKActionMenuRow

- (instancetype)initWithNode:(SPKActionMenuNode *)node kind:(SPKActionMenuRowKind)kind {
    if ((self = [super initWithFrame:CGRectZero])) {
        _kind = kind;

        _iconView = [[UIImageView alloc] initWithImage:node.image];
        _iconView.tintColor = UIColor.labelColor;
        _iconView.contentMode = UIViewContentModeScaleAspectFit;
        [self addSubview:_iconView];

        _titleLabel = [UILabel new];
        _titleLabel.text = node.title;
        _titleLabel.textColor = UIColor.labelColor;
        // The header names the level you are in, so it carries the weight.
        _titleLabel.font = (kind == SPKActionMenuRowKindHeader)
            ? [UIFont systemFontOfSize:kSPKActionMenuTitleSize weight:UIFontWeightSemibold]
            : [UIFont systemFontOfSize:kSPKActionMenuTitleSize];
        [self addSubview:_titleLabel];

        if (kind != SPKActionMenuRowKindLeaf) {
            NSString *symbol = (kind == SPKActionMenuRowKindHeader) ? @"chevron.down" : @"chevron.right";
            UIImageSymbolConfiguration *config =
                [UIImageSymbolConfiguration configurationWithPointSize:13.0 weight:UIImageSymbolWeightSemibold];
            _chevronView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:symbol
                                                                      withConfiguration:config]];
            _chevronView.tintColor = UIColor.labelColor;
            _chevronView.contentMode = UIViewContentModeScaleAspectFit;
            [self addSubview:_chevronView];
        }

        [self addTarget:self action:@selector(didTap) forControlEvents:UIControlEventTouchUpInside];

        // A leaf with no handler is information, not a control.
        if (kind == SPKActionMenuRowKindLeaf && node.handler == nil) {
            self.userInteractionEnabled = NO;
            self.alpha = 0.45;
        }

        self.isAccessibilityElement = YES;
        self.accessibilityLabel = node.title;
        self.accessibilityTraits = UIAccessibilityTraitButton;
    }
    return self;
}

- (void)didTap {
    if (self.tapHandler)
        self.tapHandler();
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat h = self.bounds.size.height;
    CGFloat w = self.bounds.size.width;

    // A row without a glyph reserves no column — same rule as the settings menu.
    BOOL hasIcon = (self.iconView.image != nil);
    self.iconView.hidden = !hasIcon;
    self.iconView.frame = hasIcon
        ? CGRectMake(kSPKActionMenuHPad, (h - kSPKActionMenuIconSize) / 2.0,
                     kSPKActionMenuIconSize, kSPKActionMenuIconSize)
        : CGRectZero;

    CGFloat titleX = hasIcon ? kSPKActionMenuHPad + kSPKActionMenuIconSize + kSPKActionMenuIconGap
                             : kSPKActionMenuHPad;
    CGFloat titleRight = kSPKActionMenuHPad;
    if (self.chevronView) {
        self.chevronView.frame = CGRectMake(w - kSPKActionMenuHPad - kSPKActionMenuChevronWidth,
                                            (h - kSPKActionMenuChevronWidth) / 2.0,
                                            kSPKActionMenuChevronWidth, kSPKActionMenuChevronWidth);
        titleRight = kSPKActionMenuHPad + kSPKActionMenuChevronWidth + 8.0;
    }
    self.titleLabel.frame = CGRectMake(titleX, 0, MAX(0.0, w - titleX - titleRight), h);
}

- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    self.backgroundColor = highlighted ? [UIColor.labelColor colorWithAlphaComponent:0.08]
                                       : UIColor.clearColor;
}

@end

#pragma mark - Overlay

@interface SPKActionMenuOverlay : UIControl
@property (nonatomic, strong, nullable) UIView *menuContainer;
@property (nonatomic, copy, nullable) void (^onDismiss)(void);
@property (nonatomic, copy, nullable) dispatch_block_t pendingAction;
/// Kept so the header row can walk back up without rebuilding the tree.
@property (nonatomic, copy, nullable) NSArray<SPKActionMenuNode *> *rootNodes;
- (void)dismiss;
@end

@implementation SPKActionMenuOverlay

- (void)dismiss {
    UIView *container = self.menuContainer;
    void (^finished)(BOOL) = ^(BOOL done) {
        (void)done;
        [self removeFromSuperview];
        if (self.onDismiss)
            self.onDismiss();
        // The action runs after the menu is gone, so anything it presents does
        // not fight this overlay for the window.
        if (self.pendingAction)
            self.pendingAction();
    };
    [UIView animateWithDuration:0.22
                          delay:0
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
                         self.backgroundColor = UIColor.clearColor;
                         container.alpha = 0.0;
                         container.transform = CGAffineTransformMakeScale(0.90, 0.90);
                     }
                     completion:finished];
}

@end

#pragma mark - Presenter

@implementation SPKActionMenu

+ (CGFloat)widthForNodes:(NSArray<SPKActionMenuNode *> *)nodes available:(CGFloat)available {
    UIFont *font = [UIFont systemFontOfSize:kSPKActionMenuTitleSize];
    UIFont *bold = [UIFont systemFontOfSize:kSPKActionMenuTitleSize weight:UIFontWeightSemibold];
    CGFloat widest = 0.0;
    for (SPKActionMenuNode *node in nodes) {
        CGFloat text = [node.title sizeWithAttributes:@{NSFontAttributeName : font}].width;
        CGFloat boldText = [node.title sizeWithAttributes:@{NSFontAttributeName : bold}].width;
        CGFloat row = kSPKActionMenuHPad + kSPKActionMenuIconSize + kSPKActionMenuIconGap
            + MAX(text, boldText) + 8.0 + kSPKActionMenuChevronWidth + kSPKActionMenuHPad;
        widest = MAX(widest, row);
        if (node.children.count > 0)
            widest = MAX(widest, [self widthForNodes:node.children available:available]);
    }
    CGFloat capped = MIN(ceil(widest), kSPKActionMenuMaxWidth);
    return MIN(MAX(capped, kSPKActionMenuMinWidth), available);
}

+ (void)presentNodes:(NSArray<SPKActionMenuNode *> *)nodes
            fromView:(UIView *)anchorView
           onDismiss:(void (^)(void))onDismiss {
    UIWindow *window = anchorView.window;
    if (window == nil || nodes.count == 0)
        return;

    UIEdgeInsets safe = window.safeAreaInsets;
    CGFloat available = window.bounds.size.width - safe.left - safe.right - 2.0 * kSPKActionMenuScreenMargin;
    CGFloat width = [self widthForNodes:nodes available:available];

    SPKActionMenuOverlay *overlay = [[SPKActionMenuOverlay alloc] initWithFrame:window.bounds];
    overlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    overlay.backgroundColor = UIColor.clearColor;
    overlay.onDismiss = onDismiss;
    overlay.rootNodes = nodes;
    [overlay addTarget:overlay action:@selector(dismiss) forControlEvents:UIControlEventTouchUpInside];

    UIView *container = [UIView new];
    container.layer.cornerRadius = kSPKActionMenuCornerRadius;
    container.layer.cornerCurve = kCACornerCurveContinuous;
    container.layer.shadowColor = UIColor.blackColor.CGColor;
    container.layer.shadowOpacity = 0.22;
    container.layer.shadowRadius = 24.0;
    container.layer.shadowOffset = CGSizeMake(0, 10);
    overlay.menuContainer = container;

    // Same material as the system's menus: glass on iOS 26+, system material
    // before that.
    Class glassEffectClass = NSClassFromString(@"UIGlassEffect");
    UIVisualEffect *effect = glassEffectClass
        ? [[glassEffectClass alloc] init]
        : [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterial];
    // Interactive glass is what deforms under a finger instead of sitting flat.
    // Set through KVC and guarded: on a system without the property this is a
    // no-op rather than a crash, and it compiles against any SDK.
    if ([effect respondsToSelector:NSSelectorFromString(@"setInteractive:")])
        [effect setValue:@YES forKey:@"interactive"];
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:effect];
    blurView.layer.cornerRadius = kSPKActionMenuCornerRadius;
    blurView.layer.cornerCurve = kCACornerCurveContinuous;
    blurView.clipsToBounds = YES;
    [container addSubview:blurView];

    [overlay addSubview:container];
    [window addSubview:overlay];

    [self fillMenu:blurView
          overlay:overlay
        container:container
            width:width
           anchor:anchorView
           window:window
            nodes:nodes
           header:nil
         animated:NO];

    container.alpha = 0.0;
    container.transform = CGAffineTransformMakeScale(0.82, 0.82);
    // Damping below 0.7 with launch velocity overshoots and settles back, which
    // is what reads as a bounce.
    UISpringTimingParameters *openTiming =
        [[UISpringTimingParameters alloc] initWithMass:1.0
                                             stiffness:200.0
                                               damping:17.5
                                       initialVelocity:CGVectorMake(0.0, 6.0)];
    UIViewPropertyAnimator *openAnimator =
        [[UIViewPropertyAnimator alloc] initWithDuration:0.0 timingParameters:openTiming];
    [openAnimator addAnimations:^{
        overlay.backgroundColor = [UIColor.blackColor colorWithAlphaComponent:0.08];
        container.alpha = 1.0;
        container.transform = CGAffineTransformIdentity;
    }];
    [openAnimator startAnimation];
}

// Draws one level. `header` is nil at the top; inside a submenu it is that
// submenu's own node, drawn as the first row and tapped to come back.
+ (void)fillMenu:(UIVisualEffectView *)blurView
         overlay:(SPKActionMenuOverlay *)overlay
       container:(UIView *)container
           width:(CGFloat)width
          anchor:(UIView *)anchorView
          window:(UIWindow *)window
           nodes:(NSArray<SPKActionMenuNode *> *)nodes
          header:(SPKActionMenuNode *)header
        animated:(BOOL)animated {
    // Cross-fade: the outgoing level is photographed and faded out over the new
    // one, so the rows dissolve while the box resizes instead of being swapped
    // under it in a single frame.
    UIView *outgoing = nil;
    if (animated && blurView.contentView.subviews.count > 0) {
        outgoing = [blurView.contentView snapshotViewAfterScreenUpdates:NO];
        outgoing.frame = blurView.contentView.bounds;
        outgoing.autoresizingMask = UIViewAutoresizingNone;
    }
    for (UIView *old in [blurView.contentView.subviews copy])
        [old removeFromSuperview];

    CGFloat hairline = 1.0 / MAX(UIScreen.mainScreen.scale, 1.0);
    NSUInteger rowCount = nodes.count + (header ? 1 : 0);
    CGFloat height = 2.0 * kSPKActionMenuContentPadding
        + rowCount * kSPKActionMenuRowHeight
        + (rowCount > 0 ? (rowCount - 1) * hairline : 0.0);

    CGFloat y = kSPKActionMenuContentPadding;
    __weak SPKActionMenuOverlay *weakOverlay = overlay;

    // The position is an argument: a block captures a plain local by value at
    // creation, so reading the running offset from inside would pin every
    // hairline to the first row.
    void (^addSeparator)(CGFloat) = ^(CGFloat lineY) {
        UIView *separator = [UIView new];
        separator.backgroundColor = UIColor.separatorColor;
        separator.frame = CGRectMake(0, lineY, width, hairline);
        [blurView.contentView addSubview:separator];
    };

    if (header) {
        SPKActionMenuRow *headerRow = [[SPKActionMenuRow alloc] initWithNode:header
                                                                       kind:SPKActionMenuRowKindHeader];
        headerRow.frame = CGRectMake(0, y, width, kSPKActionMenuRowHeight);
        [blurView.contentView addSubview:headerRow];
        y += kSPKActionMenuRowHeight;
        headerRow.tapHandler = ^{
            SPKActionMenuOverlay *strongOverlay = weakOverlay;
            if (!strongOverlay)
                return;
            [self fillMenu:blurView overlay:strongOverlay container:container width:width
                    anchor:anchorView window:window nodes:strongOverlay.rootNodes
                    header:nil animated:YES];
        };
        addSeparator(y);
        y += hairline;
    }

    for (NSUInteger i = 0; i < nodes.count; i++) {
        if (i > 0) {
            addSeparator(y);
            y += hairline;
        }
        SPKActionMenuNode *node = nodes[i];
        BOOL isBranch = (node.children.count > 0);
        SPKActionMenuRow *row = [[SPKActionMenuRow alloc]
            initWithNode:node
                    kind:isBranch ? SPKActionMenuRowKindBranch : SPKActionMenuRowKindLeaf];
        row.frame = CGRectMake(0, y, width, kSPKActionMenuRowHeight);
        [blurView.contentView addSubview:row];
        y += kSPKActionMenuRowHeight;

        if (isBranch) {
            row.tapHandler = ^{
                SPKActionMenuOverlay *strongOverlay = weakOverlay;
                if (!strongOverlay)
                    return;
                [self fillMenu:blurView overlay:strongOverlay container:container width:width
                        anchor:anchorView window:window nodes:node.children
                        header:node animated:YES];
            };
        } else {
            row.tapHandler = ^{
                SPKActionMenuOverlay *strongOverlay = weakOverlay;
                if (!strongOverlay)
                    return;
                strongOverlay.pendingAction = node.handler;
                [strongOverlay dismiss];
            };
        }
    }

    if (outgoing) {
        [blurView.contentView addSubview:outgoing];
        for (UIView *row in blurView.contentView.subviews) {
            if (row != outgoing)
                row.alpha = 0.0;
        }
    }

    // Placement: below the anchor when it fits, above otherwise, then clamped
    // into the safe area on both axes.
    CGRect anchorFrame = [anchorView convertRect:anchorView.bounds toView:overlay];
    UIEdgeInsets safe = window.safeAreaInsets;
    CGFloat minX = safe.left + kSPKActionMenuScreenMargin;
    CGFloat maxX = window.bounds.size.width - safe.right - kSPKActionMenuScreenMargin - width;
    CGFloat minY = safe.top + kSPKActionMenuScreenMargin;
    CGFloat maxY = window.bounds.size.height - safe.bottom - kSPKActionMenuScreenMargin - height;

    CGFloat x = CGRectGetMaxX(anchorFrame) - width;
    x = MAX(minX, MIN(x, MAX(minX, maxX)));

    CGFloat belowY = CGRectGetMaxY(anchorFrame) + kSPKActionMenuAnchorGap;
    CGFloat menuY = (belowY <= maxY) ? belowY
                                     : CGRectGetMinY(anchorFrame) - kSPKActionMenuAnchorGap - height;
    menuY = MAX(minY, MIN(menuY, MAX(minY, maxY)));

    CGRect target = CGRectMake(x, menuY, width, height);
    CGRect glassTarget = CGRectMake(0, 0, width, height);
    if (animated) {
        // Stiffness 210 / damping 19: a 0.43 s response at a 0.66 damping ratio.
        UISpringTimingParameters *timing =
            [[UISpringTimingParameters alloc] initWithMass:1.0
                                                 stiffness:210.0
                                                   damping:19.0
                                           initialVelocity:CGVectorMake(0.0, 0.0)];
        UIViewPropertyAnimator *animator =
            [[UIViewPropertyAnimator alloc] initWithDuration:0.0 timingParameters:timing];
        [animator addAnimations:^{
            container.frame = target;
            // The glass resizes inside the animation so it travels with the
            // container rather than snapping ahead of it.
            blurView.frame = glassTarget;
            outgoing.alpha = 0.0;
        }];
        [animator addCompletion:^(__unused UIViewAnimatingPosition position) {
            [outgoing removeFromSuperview];
        }];
        [animator startAnimation];

        // The rows arrive one behind the other rather than all at once — the
        // detail that makes a system menu feel alive instead of redrawn.
        NSInteger step = 0;
        for (UIView *row in blurView.contentView.subviews) {
            if (row == outgoing)
                continue;
            [UIView animateWithDuration:0.26
                                  delay:MIN(0.10, step * 0.022)
                                options:UIViewAnimationOptionCurveEaseOut
                             animations:^{ row.alpha = 1.0; }
                             completion:nil];
            step++;
        }
    } else {
        // First present: the anchor corner must be set BEFORE the frame, or the
        // layer shifts by half its size when the anchor point moves.
        container.layer.anchorPoint = CGPointMake(1.0, (belowY <= maxY) ? 0.0 : 1.0);
        container.frame = target;
        blurView.frame = glassTarget;
    }
}


@end
