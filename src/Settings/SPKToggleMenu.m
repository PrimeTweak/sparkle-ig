#import "SPKToggleMenu.h"

#import "../Utils.h"
#import "SPKTopicSettingsSupport.h"

@interface SPKToggleMenuItem ()
- (BOOL)isEnabled;
@end

// Convention v1.2 metrics — see SPKToggleMenu.h.
// Fixed, and matched to the action menu ceiling so the two cards are the same
// width whichever one opens.
static CGFloat const kSPKToggleMenuWidth = 240.0;
static CGFloat const kSPKToggleMenuItemHeight = 44.0;  // = SPKUI_RowHeight
static CGFloat const kSPKToggleMenuCornerRadius = 13.0;
static CGFloat const kSPKToggleMenuIconSize = 22.0;
static CGFloat const kSPKToggleMenuHPad = 14.0;
static CGFloat const kSPKToggleMenuMargin = 20.0;
static CGFloat const kSPKToggleMenuContentPadding = 6.0;   // v1.4: breathing room above/below items
// The footer is a way out, not a choice: shorter than the rows above it.
static CGFloat const kSPKToggleMenuFooterHeight = 38.0;
static CGFloat const kSPKToggleMenuFooterGap = 0.0;   // the Done row is a choice row: same height, one hairline        // v1.4.1: sectioned gap before Done (lighter, slimmer)
static CGFloat const kSPKToggleMenuAnchorGap = 6.0;

#pragma mark - Item

@implementation SPKToggleMenuItem

+ (instancetype)itemWithTitle:(NSString *)title
                     iconName:(NSString *)iconName
                  defaultsKey:(NSString *)defaultsKey {
    SPKToggleMenuItem *item = [self new];
    item->_title = [title copy];
    item->_iconName = [iconName copy];
    item->_defaultsKey = [defaultsKey copy];
    return item;
}

- (BOOL)isEnabled {
    return self.enabledProvider == nil || self.enabledProvider();
}

- (BOOL)isHidden {
    return self.hiddenProvider != nil && self.hiddenProvider();
}

@end

static NSArray<SPKToggleMenuItem *> *SPKToggleMenuVisibleItems(NSArray<SPKToggleMenuItem *> *items) {
    NSMutableArray<SPKToggleMenuItem *> *visible = [NSMutableArray arrayWithCapacity:items.count];
    for (SPKToggleMenuItem *item in items) {
        if (![item isHidden])
            [visible addObject:item];
    }
    return [visible copy];
}

#pragma mark - Deferred restart

// Raised by any item that needs a restart, lowered once the question is asked.
static BOOL gSPKToggleMenuRestartNeeded = NO;

static void SPKToggleMenuNoteRestartNeeded(void) {
    gSPKToggleMenuRestartNeeded = YES;
}

static void SPKToggleMenuAskForRestartIfNeeded(void) {
    if (!gSPKToggleMenuRestartNeeded)
        return;
    gSPKToggleMenuRestartNeeded = NO;
    [SPKUtils showRestartConfirmation];
}

#pragma mark - Item control (manual frame layout — fully deterministic)

@interface SPKToggleMenuItemControl : UIControl
/// Set by the presenter for single-choice menus: applying a value closes the
/// menu through the overlay, which owns the animation and onDismiss.
@property (nonatomic, copy, nullable) void (^dismissHandler)(void);
@property (nonatomic, strong) SPKToggleMenuItem *item;
- (void)refreshAnimated:(BOOL)animated;
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIImageView *checkView;
/// Set by the presenter. In a menu where some items carry an icon, the ones
/// without still reserve the column so every title lines up.
@property (nonatomic, assign) BOOL reservesIconColumn;
@end

@implementation SPKToggleMenuItemControl

- (instancetype)initWithItem:(SPKToggleMenuItem *)item {
    if ((self = [super initWithFrame:CGRectZero])) {
        _item = item;

        // SPKSettingsIcon() never returns nil: an unknown or empty name yields
        // the placeholder glyph. The image is built only for a real name so the
        // layout below can test for its absence.
        UIImage *iconImage = item.iconName.length > 0
            ? [SPKSettingsIcon(item.iconName) imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]
            : nil;
        _iconView = [[UIImageView alloc] initWithImage:iconImage];
        _iconView.tintColor = UIColor.labelColor;
        _iconView.contentMode = UIViewContentModeScaleAspectFit;
        [self addSubview:_iconView];

        _titleLabel = [UILabel new];
        _titleLabel.text = item.title;
        _titleLabel.font = [UIFont systemFontOfSize:16.0];
        _titleLabel.textColor = UIColor.labelColor;
        [self addSubview:_titleLabel];

        _checkView = [[UIImageView alloc] initWithImage:
            [UIImage systemImageNamed:@"checkmark"
                    withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:14.0
                                                                                      weight:UIImageSymbolWeightSemibold]]];
        _checkView.tintColor = UIColor.labelColor;
        _checkView.contentMode = UIViewContentModeScaleAspectFit;
        [self addSubview:_checkView];

        [self refreshAnimated:NO];
        [self addTarget:self action:@selector(didTap) forControlEvents:UIControlEventTouchUpInside];

        self.isAccessibilityElement = YES;
        self.accessibilityLabel = item.title;
        self.accessibilityTraits = UIAccessibilityTraitButton;
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat h = self.bounds.size.height;
    CGFloat w = self.bounds.size.width;
    // An item that declares no icon reserves no column: the title starts at the
    // margin instead of sitting beside an "unknown glyph" placeholder.
    BOOL hasIcon = (self.iconView.image != nil);
    BOOL reserves = hasIcon || self.reservesIconColumn;
    self.iconView.hidden = !hasIcon;
    self.iconView.frame = hasIcon
        ? CGRectMake(kSPKToggleMenuHPad, (h - kSPKToggleMenuIconSize) / 2.0,
                     kSPKToggleMenuIconSize, kSPKToggleMenuIconSize)
        : CGRectMake(kSPKToggleMenuHPad, h / 2.0, 0.0, 0.0);
    CGFloat checkW = 18.0;
    self.checkView.frame = CGRectMake(w - kSPKToggleMenuHPad - checkW,
                                      (h - checkW) / 2.0, checkW, checkW);
    CGFloat titleX = reserves
        ? kSPKToggleMenuHPad + kSPKToggleMenuIconSize + 12.0
        : kSPKToggleMenuHPad;
    self.titleLabel.frame = CGRectMake(titleX, 0,
                                       CGRectGetMinX(self.checkView.frame) - 8.0 - titleX, h);
}

- (void)refreshAnimated:(BOOL)animated {
    BOOL enabled = [self.item isEnabled];
    BOOL on;
    if (self.item.selectedProvider)
        on = self.item.selectedProvider();
    else if (self.item.pickValue.length > 0)
        on = [[SPKUtils getStringPref:self.item.defaultsKey] isEqualToString:self.item.pickValue];
    else
        on = enabled ? [SPKUtils getBoolPref:self.item.defaultsKey] : NO;
    self.alpha = enabled ? 1.0 : 0.35;
    self.accessibilityValue = on ? @"On" : @"Off";

    void (^apply)(void) = ^{
        self.checkView.alpha = on ? 1.0 : 0.0;
        self.checkView.transform = on ? CGAffineTransformIdentity
                                      : CGAffineTransformMakeScale(0.6, 0.6);
    };
    if (animated) {
        [UIView animateWithDuration:0.2 animations:apply];
    } else {
        apply();
    }
}

- (void)didTap {
    if (![self.item isEnabled])
        return;

    // Single-choice: the host applies the value and the menu closes, the way a
    // system picker behaves. Multi-choice keeps toggling in place.
    if (self.item.pickValue.length > 0) {
        [[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight] impactOccurred];
        if (self.item.pickHandler)
            self.item.pickHandler();
        if (self.dismissHandler)
            self.dismissHandler();
        return;
    }

    BOOL next = ![SPKUtils getBoolPref:self.item.defaultsKey];
    SPKPreferenceSetObject(@(next), self.item.defaultsKey);
    if (self.item.changeHandler)
        self.item.changeHandler(next);
    [[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight] impactOccurred];

    // One item can decide whether its siblings stay enabled (the "last visible
    // tab" guard), so refresh the whole menu, not just the row that was hit.
    for (UIView *sibling in self.superview.subviews) {
        if ([sibling isKindOfClass:[SPKToggleMenuItemControl class]])
            [(SPKToggleMenuItemControl *)sibling refreshAnimated:(sibling == self)];
    }

    // Asked for once, when the menu closes.
    //
    // Prompting on every tap turned a run of four toggles into four dialogs,
    // each interrupting the next choice. The menu is one decision; the restart
    // it needs is one question at the end of it.
    if (self.item.requiresRestart)
        SPKToggleMenuNoteRestartNeeded();
}

- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    if (![self.item isEnabled])
        return;
    self.backgroundColor = highlighted
        ? [UIColor.labelColor colorWithAlphaComponent:0.08]
        : UIColor.clearColor;
}

@end

#pragma mark - Menu

@interface SPKToggleMenuOverlay : UIControl
@property (nonatomic, strong) UIView *menuContainer;
@property (nonatomic, copy) void (^onDismiss)(void);
@end

@implementation SPKToggleMenuOverlay

- (void)spk_dismissFromDone {
    [[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight] impactOccurred];
    [self dismiss];
}

- (void)dismiss {
    [UIView animateWithDuration:0.22
        delay:0
        options:UIViewAnimationOptionCurveEaseOut
        animations:^{
            self.menuContainer.alpha = 0.0;
            self.menuContainer.transform = CGAffineTransformMakeScale(0.90, 0.90);
            self.backgroundColor = UIColor.clearColor;
        }
        completion:^(__unused BOOL finished) {
            [self removeFromSuperview];
            if (self.onDismiss)
                self.onDismiss();
            SPKToggleMenuAskForRestartIfNeeded();
        }];
}

@end

@implementation SPKToggleMenu

+ (void)presentWithChoices:(NSArray<SPKToggleMenuItem *> *)items
                  fromView:(UIView *)anchorView
          inViewController:(UIViewController *)viewController
                 onDismiss:(void (^)(void))onDismiss {
    [self spk_presentItems:items fromView:anchorView inViewController:viewController
                 showsDone:NO onDismiss:onDismiss];
}

+ (void)presentWithItems:(NSArray<SPKToggleMenuItem *> *)items
                fromView:(UIView *)anchorView
        inViewController:(UIViewController *)viewController
               onDismiss:(void (^)(void))onDismiss {
    [self spk_presentItems:items fromView:anchorView inViewController:viewController
                 showsDone:YES onDismiss:onDismiss];
}

+ (void)spk_presentItems:(NSArray<SPKToggleMenuItem *> *)items
                fromView:(UIView *)anchorView
        inViewController:(UIViewController *)viewController
               showsDone:(BOOL)showsDone
               onDismiss:(void (^)(void))onDismiss {
    UIWindow *window = viewController.view.window ?: anchorView.window;
    items = SPKToggleMenuVisibleItems(items);
    if (window == nil || items.count == 0)
        return;

    CGFloat hairline = 1.0 / MAX(UIScreen.mainScreen.scale, 1.0);
    CGFloat menuHeight = 2.0 * kSPKToggleMenuContentPadding
        + items.count * kSPKToggleMenuItemHeight + (items.count - 1) * hairline
        + (showsDone ? kSPKToggleMenuFooterGap + kSPKToggleMenuFooterHeight : 0.0);

    SPKToggleMenuOverlay *overlay = [[SPKToggleMenuOverlay alloc] initWithFrame:window.bounds];
    overlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    overlay.backgroundColor = UIColor.clearColor;
    overlay.onDismiss = onDismiss;
    [overlay addTarget:overlay action:@selector(dismiss) forControlEvents:UIControlEventTouchUpInside];

    // Container: system-material blur, menu-style rounding and shadow.
    // Everything below is plain frame math — no Auto Layout in this tree.
    UIView *container = [UIView new];
    container.layer.cornerRadius = kSPKToggleMenuCornerRadius;
    container.layer.cornerCurve = kCACornerCurveContinuous;
    container.layer.shadowColor = UIColor.blackColor.CGColor;
    container.layer.shadowOpacity = 0.22;
    container.layer.shadowRadius = 24.0;
    container.layer.shadowOffset = CGSizeMake(0, 10);
    overlay.menuContainer = container;

    // Matches the material of the system's own menus: glass on iOS 26+,
    // the classic system material before that.
    UIVisualEffect *menuEffect;
    Class glassEffectClass = NSClassFromString(@"UIGlassEffect");
    if (glassEffectClass) {
        menuEffect = [[glassEffectClass alloc] init];
    } else {
        menuEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterial];
    }
    // Interactive glass deforms under a finger. Set through KVC and guarded so
    // it is a no-op on systems without the property.
    if ([menuEffect respondsToSelector:NSSelectorFromString(@"setInteractive:")])
        [menuEffect setValue:@YES forKey:@"interactive"];
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:menuEffect];
    blurView.frame = CGRectMake(0, 0, kSPKToggleMenuWidth, menuHeight);
    blurView.layer.cornerRadius = kSPKToggleMenuCornerRadius;
    blurView.layer.cornerCurve = kCACornerCurveContinuous;
    blurView.clipsToBounds = YES;
    [container addSubview:blurView];

    // A menu where no item carries an icon has no icon column at all; titles
    // start at the margin. One icon anywhere makes every row reserve it.
    BOOL menuHasAnyIcon = NO;
    for (SPKToggleMenuItem *candidate in items) {
        if (candidate.iconName.length > 0) {
            menuHasAnyIcon = YES;
            break;
        }
    }

    CGFloat y = kSPKToggleMenuContentPadding;
    for (NSUInteger i = 0; i < items.count; i++) {
        if (i > 0) {
            UIView *separator = [UIView new];
            separator.backgroundColor = UIColor.separatorColor;
            separator.frame = CGRectMake(0, y, kSPKToggleMenuWidth, hairline);
            [blurView.contentView addSubview:separator];
            y += hairline;
        }
        SPKToggleMenuItemControl *control = [[SPKToggleMenuItemControl alloc] initWithItem:items[i]];
        control.reservesIconColumn = menuHasAnyIcon;
        if (!showsDone) {
            __weak SPKToggleMenuOverlay *weakOverlay = overlay;
            control.dismissHandler = ^{
                [weakOverlay spk_dismissFromDone];
            };
        }
        control.frame = CGRectMake(0, y, kSPKToggleMenuWidth, kSPKToggleMenuItemHeight);
        [blurView.contentView addSubview:control];
        y += kSPKToggleMenuItemHeight;
    }

    if (showsDone) {
        // v1.4 footer — sectioned gap, then an explicit way out. Same dismissal
        // path as tapping outside (animation + onDismiss), with a light tick.
        // A single hairline and clear air, not a filled slab: the footer reads as
        // its own group without putting a grey bar through the menu.
        UIView *gapBand = [[UIView alloc] initWithFrame:CGRectMake(0, y, kSPKToggleMenuWidth, kSPKToggleMenuFooterGap)];
        gapBand.backgroundColor = UIColor.clearColor;
        UIView *gapTop = [[UIView alloc] initWithFrame:CGRectMake(0, 0, kSPKToggleMenuWidth, hairline)];
        gapTop.backgroundColor = UIColor.separatorColor;
        [gapBand addSubview:gapTop];
        [blurView.contentView addSubview:gapBand];
        y += kSPKToggleMenuFooterGap;

        UIControl *doneControl = [[UIControl alloc] initWithFrame:CGRectMake(0, y, kSPKToggleMenuWidth, kSPKToggleMenuFooterHeight)];
        UILabel *doneLabel = [[UILabel alloc] initWithFrame:doneControl.bounds];
        doneLabel.text = @"Done";
        doneLabel.font = [UIFont systemFontOfSize:16.0 weight:UIFontWeightSemibold];
        doneLabel.textColor = UIColor.labelColor;
        doneLabel.textAlignment = NSTextAlignmentCenter;
        doneLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [doneControl addSubview:doneLabel];
        [doneControl addTarget:overlay action:@selector(spk_dismissFromDone) forControlEvents:UIControlEventTouchUpInside];
        [blurView.contentView addSubview:doneControl];
        y += kSPKToggleMenuFooterHeight;
    }

    // Placement: below the anchor when it fits, otherwise above — then clamp
    // both axes into the safe area so the menu can never leave the screen.
    CGRect anchorFrame = [anchorView convertRect:anchorView.bounds toView:overlay];
    UIEdgeInsets safe = window.safeAreaInsets;
    CGFloat minX = safe.left + kSPKToggleMenuMargin;
    CGFloat maxX = window.bounds.size.width - safe.right - kSPKToggleMenuMargin - kSPKToggleMenuWidth;
    CGFloat minY = safe.top + kSPKToggleMenuMargin;
    CGFloat maxY = window.bounds.size.height - safe.bottom - kSPKToggleMenuMargin - menuHeight;

    CGFloat x = CGRectGetMaxX(anchorFrame) - kSPKToggleMenuWidth - kSPKToggleMenuMargin;
    x = MAX(minX, MIN(x, maxX));

    CGFloat belowY = CGRectGetMaxY(anchorFrame) + kSPKToggleMenuAnchorGap;
    BOOL fitsBelow = belowY <= maxY;
    CGFloat menuY = fitsBelow ? belowY
                              : CGRectGetMinY(anchorFrame) - kSPKToggleMenuAnchorGap - menuHeight;
    menuY = MAX(minY, MIN(menuY, maxY));

    // The corner anchor goes on BEFORE the frame: moving an anchor point on a
    // laid-out layer shifts it by half its size. Set first, the frame lands right.
    container.layer.anchorPoint = CGPointMake(1.0, fitsBelow ? 0.0 : 1.0);
    container.frame = CGRectMake(x, menuY, kSPKToggleMenuWidth, menuHeight);
    [overlay addSubview:container];
    [window addSubview:overlay];

    // A spring described by its physics rather than a duration: the panel grows
    // out of the row and settles.
    container.alpha = 0.0;
    container.transform = CGAffineTransformMakeScale(0.82, 0.82);
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

@end

#pragma mark - Gate row

SPKSetting *SPKToggleMenuRowSetting(NSString *title,
                                    NSString *iconName,
                                    NSArray<SPKToggleMenuItem *> *items) {
    SPKSetting *row = [SPKSetting buttonCellWithTitle:title
                                             subtitle:nil
                                                 icon:SPKSettingsIcon(iconName)
                                               action:^{
                                                   // No-op — `action` is nonnull. The settings VC
                                                   // routes spk_toggleMenuItems before ever calling it.
                                               }];
    row.userInfo = @{@"spk_toggleMenuItems" : [items copy]};

    // "Off" / "N on" — re-read on every reloadData, like the root counters.
    row.accessoryTextProvider = ^NSString * {
        NSUInteger on = 0;
        for (SPKToggleMenuItem *item in SPKToggleMenuVisibleItems(items)) {
            if ([SPKUtils getBoolPref:item.defaultsKey])
                on++;
        }
        return on == 0 ? @"Off" : [NSString stringWithFormat:@"%lu on", (unsigned long)on];
    };

    // Search index: expose each item as a real switch row so it stays findable
    // and togglable from search results. Never shown as a page. Items inherit
    // the gate's searchKeywords so family terms ("mark seen", "confirm") match.
    __weak SPKSetting *weakRow = row;
    row.searchSectionsProvider = ^NSArray * {
        NSArray<SPKToggleMenuItem *> *visible = SPKToggleMenuVisibleItems(items);
        NSMutableArray<SPKSetting *> *rows = [NSMutableArray arrayWithCapacity:visible.count];
        for (SPKToggleMenuItem *item in visible) {
            SPKSetting *searchRow = item.requiresRestart
                ? [SPKSetting switchCellWithTitle:item.title
                                             icon:SPKSettingsIcon(item.iconName)
                                      defaultsKey:item.defaultsKey
                                  requiresRestart:YES]
                : [SPKSetting switchCellWithTitle:item.title
                                             icon:SPKSettingsIcon(item.iconName)
                                      defaultsKey:item.defaultsKey];
            searchRow.enabledProvider = item.enabledProvider;
            searchRow.searchKeywords = weakRow.searchKeywords;
            [rows addObject:searchRow];
        }
        return @[ SPKTopicSection(title, [rows copy], nil) ];
    };

    return row;
}
