#import "SPKDialog.h"
#import "../../Utils.h"
#import "../../Settings/SPKPreferences.h"
#import "SPKIGAlertPresenter.h"

// Sparkle's own dialog.
//
// Instagram's alert is used everywhere else in this tweak and looks like
// Instagram: a light card with blue words. Nothing about it belongs to Sparkle,
// and on a screen already dressed in glass and black it reads as a visitor.
//
// This is the same material the rest of the tweak is made of — glass, ink, a
// single hairline — and the same entrance the action menu uses, so a dialog and
// a menu feel like two parts of one thing.
//
// Layout is by frame rather than constraints: the card sizes itself to its text
// and the whole view lives for a few seconds, so a layout pass buys nothing.

// Measured against the action menu and the toggle menu, which agree on every
// one of these: same width, same corner, same row height, same margin, same
// shadow. A dialog that differed on seven of eight read as a stranger among
// them.
static CGFloat const kSPKDialogWidth = 240.0;
static CGFloat const kSPKDialogCornerRadius = 13.0;
static CGFloat const kSPKDialogPadding = 14.0;
static CGFloat const kSPKDialogButtonHeight = 44.0;
static CGFloat const kSPKDialogTitleGap = 6.0;
static CGFloat const kSPKDialogMessageGap = 16.0;

#pragma mark - Action

@implementation SPKDialogAction

+ (instancetype)actionWithTitle:(NSString *)title
                          style:(SPKDialogActionStyle)style
                        handler:(dispatch_block_t)handler {
    SPKDialogAction *action = [SPKDialogAction new];
    action->_title = [title copy];
    action->_style = style;
    action->_handler = [handler copy];
    return action;
}

@end

#pragma mark - Button

// A flat button that darkens while held, the way the tweak's rows do.
@interface SPKDialogButton : UIControl
@property (nonatomic, strong) UILabel *label;
@property (nonatomic, strong) SPKDialogAction *action;
@end

@implementation SPKDialogButton

- (instancetype)initWithAction:(SPKDialogAction *)action {
    self = [super initWithFrame:CGRectZero];
    if (!self)
        return nil;

    _action = action;

    _label = [UILabel new];
    _label.text = action.title;
    _label.textAlignment = NSTextAlignmentCenter;
    _label.font = [UIFont systemFontOfSize:16.0
                                    weight:action.style == SPKDialogActionStyleCancel
                                               ? UIFontWeightRegular
                                               : UIFontWeightSemibold];
    _label.textColor = action.style == SPKDialogActionStyleDestructive
        ? [SPKUtils SPKColor_InstagramDestructive]
        : (action.style == SPKDialogActionStyleCancel
               ? [SPKUtils SPKColor_InstagramSecondaryText]
               : [SPKUtils SPKColor_InstagramPrimaryText]);
    [self addSubview:_label];
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.label.frame = self.bounds;
}

- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    self.backgroundColor = highlighted
        ? [[SPKUtils SPKColor_InstagramPrimaryText] colorWithAlphaComponent:0.06]
        : UIColor.clearColor;
}

@end

#pragma mark - Overlay

@class SPKDialogButton;

@interface SPKDialogOverlay : UIView
@property (nonatomic, strong) UIView *card;
@property (nonatomic, strong) UIView *scrim;
- (void)buttonTapped:(SPKDialogButton *)button;
- (void)dismissWithHandler:(nullable dispatch_block_t)handler;
@end

@implementation SPKDialogOverlay

// Taps outside the card do nothing. A dialog asks a question, and dismissing it
// by accident answers neither of its buttons.
- (void)dismissWithHandler:(dispatch_block_t)handler {
    [UIView animateWithDuration:0.18
        delay:0.0
        options:UIViewAnimationOptionCurveEaseIn
        animations:^{
            self.scrim.alpha = 0.0;
            self.card.alpha = 0.0;
            self.card.transform = CGAffineTransformMakeScale(0.94, 0.94);
        }
        completion:^(__unused BOOL finished) {
            [self removeFromSuperview];
            if (handler)
                handler();
        }];
}

- (void)buttonTapped:(SPKDialogButton *)button {
    [self dismissWithHandler:button.action.handler];
}

@end

#pragma mark - Presentation

@implementation SPKDialog

// Presents over whatever window the caller's screen lives in.
//
// Every migrated call site held a controller, not a window, so this saves each
// of them from looking one up.
// The text prompts keep Instagram's alert whichever way the switch is set.
//
// A field inside the card would have to carry the keyboard, its own return key
// and the disabled state of an empty confirm button — none of which this dialog
// knows how to draw yet. Routing them here keeps one code path for callers and
// leaves the shape honest.
+ (BOOL)presentTextInputFromController:(UIViewController *)controller
                                 title:(NSString *)title
                               message:(NSString *)message
                           placeholder:(NSString *)placeholder
                           initialText:(NSString *)initialText
                       autocapitalized:(BOOL)autocapitalized
                          confirmTitle:(NSString *)confirmTitle
                           cancelTitle:(NSString *)cancelTitle
                          confirmStyle:(SPKDialogActionStyle)confirmStyle
                          confirmBlock:(SPKDialogTextHandler)confirmBlock
                           cancelBlock:(dispatch_block_t)cancelBlock {
    SPKIGAlertActionStyle style = SPKIGAlertActionStyleDefault;
    if (confirmStyle == SPKDialogActionStyleCancel)
        style = SPKIGAlertActionStyleCancel;
    else if (confirmStyle == SPKDialogActionStyleDestructive)
        style = SPKIGAlertActionStyleDestructive;

    return [SPKIGAlertPresenter presentTextInputAlertFromViewController:controller
                                                          title:title
                                                        message:message
                                                    placeholder:placeholder
                                                    initialText:initialText
                                                autocapitalized:autocapitalized
                                                   confirmTitle:confirmTitle
                                                    cancelTitle:cancelTitle
                                                   confirmStyle:style
                                                   confirmBlock:confirmBlock
                                                    cancelBlock:cancelBlock];
}

+ (BOOL)presentFromController:(UIViewController *)controller
                        title:(NSString *)title
                      message:(NSString *)message
                      actions:(NSArray<SPKDialogAction *> *)actions {
    // The same switch that decides whether a button opens Sparkle's menu or the
    // system one decides this too, so the tweak wears one style or the other and
    // never both at once.
    if (![SPKUtils getBoolPref:kSPKPrefSparkleAppearance]) {
        NSMutableArray<SPKIGAlertAction *> *native = [NSMutableArray array];
        for (SPKDialogAction *action in actions) {
            SPKIGAlertActionStyle style = SPKIGAlertActionStyleDefault;
            if (action.style == SPKDialogActionStyleCancel)
                style = SPKIGAlertActionStyleCancel;
            else if (action.style == SPKDialogActionStyleDestructive)
                style = SPKIGAlertActionStyleDestructive;

            [native addObject:[SPKIGAlertAction actionWithTitle:action.title
                                                          style:style
                                                        handler:action.handler]];
        }
        return [SPKIGAlertPresenter presentAlertFromViewController:controller
                                                             title:title
                                                           message:message
                                                           actions:native];
    }

    // A nil controller is allowed, as it was on the presenter this replaced: the
    // startup guard raises its alert before any screen exists.
    UIWindow *window = controller.view.window ?: UIApplication.sharedApplication.keyWindow;
    return [self presentInWindow:window title:title message:message actions:actions];
}

+ (BOOL)presentInWindow:(UIWindow *)window
                  title:(NSString *)title
                message:(NSString *)message
                actions:(NSArray<SPKDialogAction *> *)actions {
    if (!window || actions.count == 0)
        return NO;

    SPKDialogOverlay *overlay = [[SPKDialogOverlay alloc] initWithFrame:window.bounds];
    overlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

    UIView *scrim = [[UIView alloc] initWithFrame:window.bounds];
    scrim.autoresizingMask = overlay.autoresizingMask;
    scrim.backgroundColor = [UIColor.blackColor colorWithAlphaComponent:0.32];
    scrim.alpha = 0.0;
    [overlay addSubview:scrim];
    overlay.scrim = scrim;

    // ---- card ----------------------------------------------------------
    UIView *card = [UIView new];
    card.layer.cornerRadius = kSPKDialogCornerRadius;
    card.layer.cornerCurve = kCACornerCurveContinuous;
    card.layer.shadowColor = UIColor.blackColor.CGColor;
    card.layer.shadowOpacity = 0.22;
    card.layer.shadowRadius = 24.0;
    card.layer.shadowOffset = CGSizeMake(0.0, 10.0);
    overlay.card = card;

    Class glassEffectClass = NSClassFromString(@"UIGlassEffect");
    UIVisualEffect *effect = glassEffectClass
        ? [[glassEffectClass alloc] init]
        : [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterial];
    UIVisualEffectView *glass = [[UIVisualEffectView alloc] initWithEffect:effect];
    glass.layer.cornerRadius = kSPKDialogCornerRadius;
    glass.layer.cornerCurve = kCACornerCurveContinuous;
    glass.clipsToBounds = YES;
    [card addSubview:glass];

    CGFloat textWidth = kSPKDialogWidth - 2.0 * kSPKDialogPadding;

    UILabel *titleLabel = [UILabel new];
    titleLabel.text = title;
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.numberOfLines = 0;
    titleLabel.font = [UIFont systemFontOfSize:16.0 weight:UIFontWeightSemibold];
    titleLabel.textColor = [SPKUtils SPKColor_InstagramPrimaryText];
    CGSize titleSize = [titleLabel sizeThatFits:CGSizeMake(textWidth, CGFLOAT_MAX)];
    [glass.contentView addSubview:titleLabel];

    UILabel *messageLabel = [UILabel new];
    messageLabel.text = message;
    messageLabel.textAlignment = NSTextAlignmentCenter;
    messageLabel.numberOfLines = 0;
    messageLabel.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightRegular];
    messageLabel.textColor = [SPKUtils SPKColor_InstagramSecondaryText];
    CGSize messageSize = message.length > 0
        ? [messageLabel sizeThatFits:CGSizeMake(textWidth, CGFLOAT_MAX)]
        : CGSizeZero;
    if (message.length > 0)
        [glass.contentView addSubview:messageLabel];

    CGFloat textBlock = kSPKDialogPadding + titleSize.height;
    if (message.length > 0)
        textBlock += kSPKDialogTitleGap + messageSize.height;
    textBlock += kSPKDialogMessageGap;

    // Side by side while two short words fit; stacked otherwise, so a long
    // label is never squeezed into half a card.
    BOOL horizontal = actions.count == 2;
    for (SPKDialogAction *action in actions) {
        CGFloat needed = [action.title sizeWithAttributes:@{
            NSFontAttributeName : [UIFont systemFontOfSize:16.0 weight:UIFontWeightSemibold]
        }].width;
        if (needed > (kSPKDialogWidth / 2.0) - 24.0)
            horizontal = NO;
    }

    CGFloat buttonBlock = horizontal ? kSPKDialogButtonHeight
                                     : kSPKDialogButtonHeight * (CGFloat)actions.count;
    CGFloat cardHeight = textBlock + buttonBlock;

    card.frame = CGRectMake(0.0, 0.0, kSPKDialogWidth, cardHeight);
    card.center = CGPointMake(CGRectGetMidX(window.bounds), CGRectGetMidY(window.bounds));
    glass.frame = card.bounds;

    titleLabel.frame = CGRectMake(kSPKDialogPadding, kSPKDialogPadding, textWidth, titleSize.height);
    if (message.length > 0) {
        messageLabel.frame = CGRectMake(kSPKDialogPadding,
                                        CGRectGetMaxY(titleLabel.frame) + kSPKDialogTitleGap,
                                        textWidth,
                                        messageSize.height);
    }

    UIColor *hairline = [[SPKUtils SPKColor_InstagramPrimaryText] colorWithAlphaComponent:0.12];
    CGFloat hairlineWidth = 1.0 / UIScreen.mainScreen.scale;

    UIView *topRule = [[UIView alloc] initWithFrame:CGRectMake(0.0, textBlock, kSPKDialogWidth, hairlineWidth)];
    topRule.backgroundColor = hairline;
    [glass.contentView addSubview:topRule];

    [actions enumerateObjectsUsingBlock:^(SPKDialogAction *action, NSUInteger index, __unused BOOL *stop) {
        SPKDialogButton *button = [[SPKDialogButton alloc] initWithAction:action];
        button.frame = horizontal
            ? CGRectMake((kSPKDialogWidth / (CGFloat)actions.count) * (CGFloat)index,
                         textBlock,
                         kSPKDialogWidth / (CGFloat)actions.count,
                         kSPKDialogButtonHeight)
            : CGRectMake(0.0,
                         textBlock + kSPKDialogButtonHeight * (CGFloat)index,
                         kSPKDialogWidth,
                         kSPKDialogButtonHeight);
        [button addTarget:overlay action:@selector(buttonTapped:) forControlEvents:UIControlEventTouchUpInside];
        [glass.contentView addSubview:button];

        if (index == 0)
            return;
        CGRect separator = horizontal
            ? CGRectMake(CGRectGetMinX(button.frame), textBlock, hairlineWidth, kSPKDialogButtonHeight)
            : CGRectMake(0.0, CGRectGetMinY(button.frame), kSPKDialogWidth, hairlineWidth);
        UIView *rule = [[UIView alloc] initWithFrame:separator];
        rule.backgroundColor = hairline;
        [glass.contentView addSubview:rule];
    }];

    [overlay addSubview:card];
    [window addSubview:overlay];

    card.alpha = 0.0;
    card.transform = CGAffineTransformMakeScale(0.9, 0.9);
    [UIView animateWithDuration:0.3
                          delay:0.0
         usingSpringWithDamping:0.82
          initialSpringVelocity:0.0
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
                         scrim.alpha = 1.0;
                         card.alpha = 1.0;
                         card.transform = CGAffineTransformIdentity;
                     }
                     completion:nil];
    return YES;
}

@end
