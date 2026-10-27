#import "SPKIGAlertPresenter.h"
#import "../../InstagramHeaders.h"
#import "../../Utils.h"
#include <CoreGraphics/CGGeometry.h>
#include <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>

static const void *kSPKIGAlertInputViewKey = &kSPKIGAlertInputViewKey;
static const void *kSPKIGAlertInputFieldKey = &kSPKIGAlertInputFieldKey;
static const void *kSPKIGAlertInputHasMessageKey = &kSPKIGAlertInputHasMessageKey;
static const void *kSPKIGAlertNativeActionStyleKey = &kSPKIGAlertNativeActionStyleKey;
static const void *kSPKIGAlertNativeActionStylesKey = &kSPKIGAlertNativeActionStylesKey;
static const CGFloat kSPKIGAlertInputHeight = 44.0;
static const CGFloat kSPKIGAlertInputVerticalPadding = 14.0;
static const CGFloat kSPKIGAlertInputBottomPadding = 12.0;
static const CGFloat kSPKIGAlertInputHorizontalInset = 24.0;

static CGSize (*sSPKIGAlertOriginalSizeThatFits)(id, SEL, CGSize);
static void (*sSPKIGAlertOriginalLayoutSubviews)(id, SEL);
static BOOL sSPKIGAlertHooksInstalled;

@implementation SPKIGAlertAction

+ (instancetype)actionWithTitle:(NSString *)title
                          style:(SPKIGAlertActionStyle)style
                        handler:(SPKIGAlertActionHandler)handler {
    SPKIGAlertAction *action = [[self alloc] init];
    action->_title = [title copy];
    action->_style = style;
    action->_handler = [handler copy];
    return action;
}

@end

static UIViewController *SPKIGResolvedPresenter(UIViewController *presenter) {
    return presenter ?: topMostController();
}

static id SPKIGGetIvarObject(id object, const char *name) {
    if (!object || !name)
        return nil;
    Ivar ivar = class_getInstanceVariable([object class], name);
    if (!ivar)
        return nil;
    return object_getIvar(object, ivar);
}

static void SPKIGCallActionHandler(SPKIGAlertAction *action) {
    if (action.handler) {
        action.handler();
    }
}

static UIAlertActionStyle SPKUIKitActionStyle(SPKIGAlertActionStyle style) {
    switch (style) {
    case SPKIGAlertActionStyleCancel:
        return UIAlertActionStyleCancel;
    case SPKIGAlertActionStyleDestructive:
        /// A UIKit alert's destructive tint is not customizable: UIAlertAction exposes no supported per-action color API.
        return UIAlertActionStyleDestructive;
    case SPKIGAlertActionStyleDefault:
    default:
        return UIAlertActionStyleDefault;
    }
}

static long long SPKIGNativeAlertActionStyle(SPKIGAlertActionStyle style) {
    switch (style) {
    case SPKIGAlertActionStyleCancel:
        return 2;
    case SPKIGAlertActionStyleDestructive:
        return 1;
    case SPKIGAlertActionStyleDefault:
    default:
        return 0;
    }
}

static long long SPKIGNativeActionSheetStyle(SPKIGAlertActionStyle style) {
    // IGActionSheetControllerAction uses IG's native action-style enum
    // (0 = default, 1 = destructive, 2 = cancel) — the same mapping as alerts,
    // NOT Sparkle's raw enum. Passing the raw value swapped cancel/destructive,
    // which placed Cancel red at the top and put the destructive action into the
    // dismiss (cancel) slot.
    return SPKIGNativeAlertActionStyle(style);
}

static BOOL SPKIGActionsContainDestructiveAction(NSArray<SPKIGAlertAction *> *actions) {
    for (SPKIGAlertAction *action in actions) {
        if (action.style == SPKIGAlertActionStyleDestructive) {
            return YES;
        }
    }
    return NO;
}

static long long SPKIGNativeAlertActionStyleForAction(SPKIGAlertAction *action, BOOL containsDestructiveAction) {
    if (containsDestructiveAction && action.style == SPKIGAlertActionStyleCancel) {
        return SPKIGNativeAlertActionStyle(SPKIGAlertActionStyleDefault);
    }
    return SPKIGNativeAlertActionStyle(action.style);
}

static NSString *SPKIGDescriptionTextForInputAlert(NSString *message) {
    return message.length > 0 ? message : nil;
}

static void SPKIGPresentUIKitAlert(UIViewController *presenter,
                                   NSString *title,
                                   NSString *message,
                                   NSArray<SPKIGAlertAction *> *actions,
                                   UIAlertControllerStyle style) {
    UIViewController *resolvedPresenter = SPKIGResolvedPresenter(presenter);
    if (!resolvedPresenter)
        return;

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:message
                                                            preferredStyle:style];
    for (SPKIGAlertAction *action in actions) {
        [alert addAction:[UIAlertAction actionWithTitle:action.title
                                                  style:SPKUIKitActionStyle(action.style)
                                                handler:^(__unused UIAlertAction *uiAction) {
                                                    SPKIGCallActionHandler(action);
                                                }]];
    }

    if (style == UIAlertControllerStyleActionSheet && alert.popoverPresentationController) {
        alert.popoverPresentationController.sourceView = resolvedPresenter.view;
        alert.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(resolvedPresenter.view.bounds),
                                                                    CGRectGetMidY(resolvedPresenter.view.bounds),
                                                                    1.0,
                                                                    1.0);
    }
    [resolvedPresenter presentViewController:alert animated:YES completion:nil];
}

static void SPKIGPresentUIKitTextInputAlert(UIViewController *presenter,
                                            NSString *title,
                                            NSString *message,
                                            NSString *placeholder,
                                            NSString *initialText,
                                            BOOL autocapitalized,
                                            NSString *confirmTitle,
                                            NSString *cancelTitle,
                                            SPKIGAlertActionStyle confirmStyle,
                                            SPKIGAlertTextHandler confirmBlock,
                                            SPKIGAlertActionHandler cancelBlock) {
    UIViewController *resolvedPresenter = SPKIGResolvedPresenter(presenter);
    if (!resolvedPresenter)
        return;

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.placeholder = placeholder;
        field.text = initialText;
        field.autocapitalizationType = autocapitalized ? UITextAutocapitalizationTypeWords : UITextAutocapitalizationTypeNone;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:cancelTitle
                                              style:UIAlertActionStyleCancel
                                            handler:^(__unused UIAlertAction *action) {
                                                if (cancelBlock)
                                                    cancelBlock();
                                            }]];
    [alert addAction:[UIAlertAction actionWithTitle:confirmTitle
                                              style:SPKUIKitActionStyle(confirmStyle)
                                            handler:^(__unused UIAlertAction *action) {
                                                if (confirmBlock)
                                                    confirmBlock(alert.textFields.firstObject.text);
                                            }]];
    [resolvedPresenter presentViewController:alert animated:YES completion:nil];
}

static UIView *SPKIGCreateInputView(NSString *placeholder, NSString *initialText, BOOL autocapitalized, UITextField **textFieldOut) {
    Class formFieldContainerClass = NSClassFromString(@"IGDSFormField");
    UIView *inputView = nil;
    UITextField *textField = nil;

    if (formFieldContainerClass && [formFieldContainerClass instancesRespondToSelector:@selector(initWithFrame:)]) {
        inputView = [[formFieldContainerClass alloc] initWithFrame:CGRectMake(0.0, 0.0, 260.0, kSPKIGAlertInputHeight)];
        if ([inputView respondsToSelector:@selector(formField)]) {
            textField = ((id (*)(id, SEL))objc_msgSend)(inputView, @selector(formField));
        }
    }

    if (!textField) {
        Class formFieldClass = NSClassFromString(@"IGFormField");
        if (formFieldClass && [formFieldClass instancesRespondToSelector:@selector(initWithFrame:)]) {
            textField = [[formFieldClass alloc] initWithFrame:CGRectMake(0.0, 0.0, 260.0, kSPKIGAlertInputHeight)];
            inputView = textField;
        }
    }

    if (!textField) {
        textField = [[UITextField alloc] initWithFrame:CGRectMake(0.0, 0.0, 260.0, kSPKIGAlertInputHeight)];
        inputView = textField;
    }

    if (inputView != textField && !textField.superview) {
        textField.frame = CGRectInset(inputView.bounds, 12.0, 0.0);
        textField.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [inputView addSubview:textField];
    }
    UIColor *placeholderColor = [UIColor secondaryLabelColor];
    UIColor *fieldBackground = [UIColor colorWithWhite:0.5 alpha:0.1];

    inputView.backgroundColor = fieldBackground;
    inputView.layer.cornerRadius = 16.0;
    inputView.frame = CGRectMake(0.0, 0.0, 260.0, kSPKIGAlertInputHeight);
    inputView.clipsToBounds = NO;

    textField.backgroundColor = UIColor.clearColor;
    textField.font = [UIFont systemFontOfSize:15.0 weight:UIFontWeightRegular];
    textField.textColor = UIColor.labelColor;
    textField.tintColor = [UIColor systemBlueColor];
    textField.attributedPlaceholder = placeholder.length > 0
                                          ? [[NSAttributedString alloc] initWithString:placeholder attributes:@{NSForegroundColorAttributeName : placeholderColor}]
                                          : nil;
    textField.text = initialText;
    textField.clearButtonMode = UITextFieldViewModeWhileEditing;
    textField.autocapitalizationType = autocapitalized ? UITextAutocapitalizationTypeWords : UITextAutocapitalizationTypeNone;
    textField.returnKeyType = UIReturnKeyDone;
    textField.borderStyle = UITextBorderStyleNone;
    textField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, 12.0, 1.0)];
    textField.leftViewMode = UITextFieldViewModeAlways;

    if (textFieldOut) {
        *textFieldOut = textField;
    }
    return inputView;
}

static CGRect SPKIGFrameInView(UIView *source, UIView *target) {
    if (!source || !target)
        return CGRectNull;
    return [source.superview convertRect:source.frame toView:target];
}

static CGFloat SPKIGMeasuredBottomForLabelInView(UIView *labelView, UIView *target) {
    if (!labelView || !target)
        return CGFLOAT_MIN;
    if (labelView.hidden)
        return CGFLOAT_MIN;
    if (labelView.alpha <= 0.01)
        return CGFLOAT_MIN;

    // Check if UILabel is empty
    if ([labelView isKindOfClass:[UILabel class]]) {
        UILabel *label = (UILabel *)labelView;
        if (label.text.length == 0 && label.attributedText.length == 0) {
            return CGFLOAT_MIN;
        }
    } else if ([labelView respondsToSelector:@selector(text)]) {
        @try {
            NSString *text = [labelView valueForKey:@"text"];
            if ([text isKindOfClass:[NSString class]] && text.length == 0) {
                return CGFLOAT_MIN;
            }
        } @catch (__unused NSException *e) {
        }
    }

    CGRect frame = SPKIGFrameInView(labelView, target);
    if (CGRectIsNull(frame))
        return CGFLOAT_MIN;
    if (frame.size.height <= 0.0)
        return CGFLOAT_MIN;

    CGFloat measuredHeight = CGRectGetHeight(frame);
    if ([labelView respondsToSelector:@selector(sizeThatFits:)]) {
        CGSize measured = [labelView sizeThatFits:CGSizeMake(CGRectGetWidth(frame), CGFLOAT_MAX)];
        if (measured.height > 0.0) {
            measuredHeight = MAX(measuredHeight, ceil(measured.height));
        }
    }

    return CGRectGetMinY(frame) + measuredHeight;
}

static CGFloat SPKIGMinimumButtonY(NSArray<UIView *> *buttons, UIView *coordinateView) {
    if (!coordinateView || ![buttons isKindOfClass:[NSArray class]] || buttons.count == 0)
        return CGFLOAT_MAX;

    CGFloat minY = CGFLOAT_MAX;
    for (UIView *button in buttons) {
        CGRect buttonFrame = SPKIGFrameInView(button, coordinateView);
        if (!CGRectIsNull(buttonFrame)) {
            minY = MIN(minY, CGRectGetMinY(buttonFrame));
        }
    }
    return minY;
}

static UIView *SPKIGDirectChildAncestor(UIView *view, UIView *root) {
    if (!view || !root)
        return nil;
    UIView *current = view;
    while (current && current.superview != root) {
        current = current.superview;
    }
    return (current && current.superview == root) ? current : nil;
}

static void SPKIGShiftButtonRegionToStartAtY(UIView *root, UIView *coordinateView, NSArray<UIView *> *buttons, CGFloat minimumY) {
    if (!root || !coordinateView || ![buttons isKindOfClass:[NSArray class]] || buttons.count == 0)
        return;

    UIView *inputView = objc_getAssociatedObject(coordinateView, kSPKIGAlertInputViewKey);
    if (!inputView) {
        inputView = objc_getAssociatedObject(root, kSPKIGAlertInputViewKey);
    }

    CGFloat minButtonY = SPKIGMinimumButtonY(buttons, coordinateView);
    if (minButtonY == CGFLOAT_MAX)
        return;

    CGFloat delta = ceil(minimumY - minButtonY);
    if (delta <= 0.0)
        return;

    // Collect unique direct-child ancestors of each button within root.
    NSMutableSet<NSValue *> *shifted = [NSMutableSet set];
    for (UIView *button in buttons) {
        UIView *ancestor = SPKIGDirectChildAncestor(button, root);
        if (!ancestor || ancestor == inputView)
            continue;
        NSValue *key = [NSValue valueWithNonretainedObject:ancestor];
        if ([shifted containsObject:key])
            continue;
        [shifted addObject:key];

        CGRect frame = ancestor.frame;
        frame.origin.y += delta;
        ancestor.frame = frame;
    }

    // Also shift any other direct subviews of root that sit in the button region.
    for (UIView *subview in root.subviews) {
        if (subview == inputView)
            continue;
        NSValue *key = [NSValue valueWithNonretainedObject:subview];
        if ([shifted containsObject:key])
            continue;

        CGRect subviewFrame = SPKIGFrameInView(subview, coordinateView);
        if (CGRectIsNull(subviewFrame))
            continue;
        if (CGRectGetMinY(subviewFrame) < minButtonY - 10.0)
            continue;

        [shifted addObject:key];
        CGRect frame = subview.frame;
        frame.origin.y += delta;
        subview.frame = frame;
    }

    // Grow root if shifted content exceeds its bounds.
    CGFloat maxBottom = 0.0;
    for (NSValue *val in shifted) {
        UIView *v = [val nonretainedObjectValue];
        CGFloat bottom = CGRectGetMaxY(v.frame);
        if (bottom > maxBottom)
            maxBottom = bottom;
    }
    if (maxBottom > CGRectGetHeight(root.bounds)) {
        CGRect rootFrame = root.frame;
        rootFrame.size.height = maxBottom;
        root.frame = rootFrame;
    }
}

static UIColor *SPKIGDangerActionColor(void) {
    return [SPKUtils SPKColor_InstagramDestructive];
}

static NSNumber *SPKIGNativeStyleForButton(id alertView, UIView *button, NSUInteger index) {
    NSMapTable *buttonToActionMap = SPKIGGetIvarObject(alertView, "_buttonToActionMap");
    id nativeAction = nil;
    if ([buttonToActionMap respondsToSelector:@selector(objectForKey:)]) {
        nativeAction = [buttonToActionMap objectForKey:button];
    }

    NSNumber *mappedStyle = nativeAction ? objc_getAssociatedObject(nativeAction, kSPKIGAlertNativeActionStyleKey) : nil;
    if (mappedStyle)
        return mappedStyle;

    NSArray<NSNumber *> *styles = objc_getAssociatedObject(alertView, kSPKIGAlertNativeActionStylesKey);
    return index < styles.count ? styles[index] : nil;
}

static NSArray<UIView *> *SPKIGFindAlertButtons(id alertView) {
    if (!alertView)
        return @[];
    NSMutableArray<UIView *> *buttons = [NSMutableArray array];

    // 1. Try _buttons ivar
    id ivarButtons = SPKIGGetIvarObject(alertView, "_buttons");
    if ([ivarButtons isKindOfClass:[NSArray class]]) {
        for (id btn in ivarButtons) {
            if ([btn isKindOfClass:[UIView class]]) {
                [buttons addObject:btn];
            }
        }
        if (buttons.count > 0)
            return buttons.copy;
    }

    // 2. Try keyEnumerator on _buttonToActionMap
    id buttonToActionMap = SPKIGGetIvarObject(alertView, "_buttonToActionMap");
    if ([buttonToActionMap respondsToSelector:@selector(keyEnumerator)]) {
        for (id key in [buttonToActionMap keyEnumerator]) {
            if ([key isKindOfClass:[UIView class]]) {
                [buttons addObject:key];
            }
        }
        if (buttons.count > 0)
            return buttons.copy;
    }

    // 3. Recursive subview search
    if ([alertView isKindOfClass:[UIView class]]) {
        NSMutableArray<UIView *> *queue = [NSMutableArray arrayWithObject:alertView];
        while (queue.count > 0) {
            UIView *current = queue.firstObject;
            [queue removeObjectAtIndex:0];

            NSString *className = NSStringFromClass([current class]);
            if ([current isKindOfClass:[UIButton class]] ||
                [className rangeOfString:@"Button"
                                 options:NSCaseInsensitiveSearch]
                        .location != NSNotFound ||
                [className rangeOfString:@"ActionView"
                                 options:NSCaseInsensitiveSearch]
                        .location != NSNotFound) {
                [buttons addObject:current];
            } else {
                [queue addObjectsFromArray:current.subviews];
            }
        }
    }

    return buttons.copy;
}

static void SPKIGStyleAlertButtons(id alertView) {
    NSArray<UIView *> *buttons = SPKIGFindAlertButtons(alertView);
    if (buttons.count == 0)
        return;

    UIColor *dangerColor = SPKIGDangerActionColor();
    [buttons enumerateObjectsUsingBlock:^(UIView *button, NSUInteger index, __unused BOOL *stop) {
        NSNumber *styleNumber = SPKIGNativeStyleForButton(alertView, button, index);
        if (styleNumber.integerValue != SPKIGAlertActionStyleDestructive)
            return;

        button.tintColor = dangerColor;
        if ([button respondsToSelector:@selector(setTitleColor:forState:)]) {
            ((void (*)(id, SEL, id, UIControlState))objc_msgSend)(button, @selector(setTitleColor:forState:), dangerColor, UIControlStateNormal);
        }
    }];
}

static CGSize SPKIGAlertHookSizeThatFits(id self, SEL _cmd, CGSize size) {
    CGSize fittingSize = sSPKIGAlertOriginalSizeThatFits ? sSPKIGAlertOriginalSizeThatFits(self, _cmd, size) : CGSizeZero;
    UIView *inputView = objc_getAssociatedObject(self, kSPKIGAlertInputViewKey);
    if (!inputView) {
        return fittingSize;
    }

    CGFloat extraHeight = kSPKIGAlertInputVerticalPadding + kSPKIGAlertInputHeight + kSPKIGAlertInputBottomPadding;
    fittingSize.height += extraHeight;
    return fittingSize;
}

static void SPKIGAlertHookLayoutSubviews(id self, SEL _cmd) {
    if (sSPKIGAlertOriginalLayoutSubviews) {
        sSPKIGAlertOriginalLayoutSubviews(self, _cmd);
    }

    UIView *alertView = (UIView *)self;
    SPKIGStyleAlertButtons(self);

    UIView *inputView = objc_getAssociatedObject(self, kSPKIGAlertInputViewKey);
    if (!inputView)
        return;

    UIView *scrollView = SPKIGGetIvarObject(self, "_scrollView");
    UIView *container = scrollView ?: alertView;
    if (inputView.superview != container) {
        [inputView removeFromSuperview];
        [container addSubview:inputView];
    }

    UIView *descriptionLabel = SPKIGGetIvarObject(self, "_descriptionLabel");
    UIView *titleLabel = SPKIGGetIvarObject(self, "_titleLabel");
    CGFloat width = MIN(CGRectGetWidth(container.bounds) - (kSPKIGAlertInputHorizontalInset * 2.0), 280.0);
    width = MAX(width, 160.0);

    CGFloat labelBottom = CGFLOAT_MIN;
    CGFloat descBottom = SPKIGMeasuredBottomForLabelInView(descriptionLabel, container);
    CGFloat titleBottom = SPKIGMeasuredBottomForLabelInView(titleLabel, container);

    if (descBottom != CGFLOAT_MIN && titleBottom != CGFLOAT_MIN) {
        labelBottom = MAX(descBottom, titleBottom);
    } else if (descBottom != CGFLOAT_MIN) {
        labelBottom = descBottom;
    } else {
        labelBottom = titleBottom;
    }

    CGFloat y = labelBottom != CGFLOAT_MIN
                    ? labelBottom + kSPKIGAlertInputVerticalPadding
                    : kSPKIGAlertInputVerticalPadding;
    y = MAX(y, kSPKIGAlertInputVerticalPadding);

    CGFloat x = floor((CGRectGetWidth(container.bounds) - width) / 2.0);
    inputView.frame = CGRectMake(x, y, width, kSPKIGAlertInputHeight);

    NSArray<UIView *> *buttons = SPKIGFindAlertButtons(self);
    CGFloat minimumButtonY = CGRectGetMaxY(inputView.frame) + kSPKIGAlertInputBottomPadding;
    if (scrollView && [buttons isKindOfClass:[NSArray class]]) {
        // Separate buttons into those inside vs outside the scrollView.
        NSMutableArray<UIView *> *buttonsInScroll = [NSMutableArray array];
        NSMutableArray<UIView *> *buttonsOutsideScroll = [NSMutableArray array];
        for (UIView *button in buttons) {
            BOOL insideScroll = NO;
            UIView *walk = button.superview;
            while (walk) {
                if (walk == scrollView) {
                    insideScroll = YES;
                    break;
                }
                if (walk == alertView)
                    break;
                walk = walk.superview;
            }
            if (insideScroll) {
                [buttonsInScroll addObject:button];
            } else {
                [buttonsOutsideScroll addObject:button];
            }
        }

        // Shift buttons inside the scrollView using scrollView-local coordinates.
        if (buttonsInScroll.count > 0) {
            SPKIGShiftButtonRegionToStartAtY(scrollView, scrollView, buttonsInScroll, minimumButtonY);
            // Grow scrollView content if needed.
            if ([scrollView isKindOfClass:[UIScrollView class]]) {
                CGFloat maxBottom = 0.0;
                for (UIView *sub in scrollView.subviews) {
                    CGFloat bottom = CGRectGetMaxY(sub.frame);
                    if (bottom > maxBottom)
                        maxBottom = bottom;
                }
                ((UIScrollView *)scrollView).contentSize = CGSizeMake(CGRectGetWidth(scrollView.bounds), maxBottom);
            }
        }

        // Shift buttons outside the scrollView using alertView coordinates.
        if (buttonsOutsideScroll.count > 0) {
            CGRect inputFrameInAlert = SPKIGFrameInView(inputView, alertView);
            CGFloat minimumButtonYInAlert = CGRectIsNull(inputFrameInAlert)
                                                ? minimumButtonY
                                                : CGRectGetMaxY(inputFrameInAlert) + kSPKIGAlertInputBottomPadding;
            SPKIGShiftButtonRegionToStartAtY(alertView, alertView, buttonsOutsideScroll, minimumButtonYInAlert);
        }
    } else {
        SPKIGShiftButtonRegionToStartAtY(container, container, buttons, minimumButtonY);
    }

    // Trim the alert to tightly fit the actual content after repositioning.
    if (buttons.count > 0) {
        CGFloat maxButtonBottom = 0.0;
        for (UIView *button in buttons) {
            CGRect buttonFrameInAlert = SPKIGFrameInView(button, alertView);
            if (!CGRectIsNull(buttonFrameInAlert)) {
                CGFloat bottom = CGRectGetMaxY(buttonFrameInAlert);
                if (bottom > maxButtonBottom)
                    maxButtonBottom = bottom;
            }
        }
        if (maxButtonBottom > 0.0) {
            CGFloat desiredHeight = maxButtonBottom;
            CGFloat currentHeight = CGRectGetHeight(alertView.frame);
            if (currentHeight > desiredHeight + 1.0) {
                CGRect frame = alertView.frame;
                CGFloat shrink = currentHeight - desiredHeight;
                frame.size.height = desiredHeight;
                frame.origin.y += shrink / 2.0;
                alertView.frame = frame;

                // Also resize the immediate container if it wraps the alert tightly.
                UIView *wrapper = alertView.superview;
                if (wrapper && fabs(CGRectGetHeight(wrapper.bounds) - currentHeight) < 2.0) {
                    CGRect wrapperFrame = wrapper.frame;
                    wrapperFrame.size.height = desiredHeight;
                    wrapperFrame.origin.y += shrink / 2.0;
                    wrapper.frame = wrapperFrame;
                }
            }
        }
    }
}

static void SPKIGSwizzleInstanceMethod(Class cls, SEL origSel, IMP newImp, IMP *outOrigImp) {
    if (!cls || !origSel || !newImp)
        return;
    Method origMethod = class_getInstanceMethod(cls, origSel);
    if (!origMethod)
        return;

    const char *types = method_getTypeEncoding(origMethod);
    IMP origImp = method_getImplementation(origMethod);

    if (class_addMethod(cls, origSel, newImp, types)) {
        if (outOrigImp)
            *outOrigImp = origImp;
    } else {
        IMP prevImp = method_setImplementation(origMethod, newImp);
        if (outOrigImp)
            *outOrigImp = prevImp;
    }
}

static void SPKIGInstallAlertHooksIfNeeded(Class alertClass) {
    if (sSPKIGAlertHooksInstalled || !alertClass)
        return;

    SPKIGSwizzleInstanceMethod(alertClass, @selector(sizeThatFits:), (IMP)SPKIGAlertHookSizeThatFits, (IMP *)&sSPKIGAlertOriginalSizeThatFits);
    SPKIGSwizzleInstanceMethod(alertClass, @selector(layoutSubviews), (IMP)SPKIGAlertHookLayoutSubviews, (IMP *)&sSPKIGAlertOriginalLayoutSubviews);

    sSPKIGAlertHooksInstalled = YES;
}

@implementation SPKIGAlertPresenter

+ (BOOL)presentAlertFromViewController:(UIViewController *)presenter
                                 title:(NSString *)title
                               message:(NSString *)message
                               actions:(NSArray<SPKIGAlertAction *> *)actions {
    Class actionClass = NSClassFromString(@"IGCustomAlertAction");
    Class alertClass = NSClassFromString(@"IGDSAlertDialogView");
    Class styleClass = NSClassFromString(@"IGDSAlertDialogStyle");
    SEL actionSelector = @selector(actionWithTitle:style:handler:);
    SEL alertSelector = NSSelectorFromString(@"initWithStyle:titleText:descriptionText:actions:showHorizontalButtons:");

    if (!actionClass || !alertClass || ![actionClass respondsToSelector:actionSelector] || ![alertClass instancesRespondToSelector:alertSelector]) {
        SPKIGPresentUIKitAlert(presenter, title, message, actions, UIAlertControllerStyleAlert);
        return NO;
    }

    SPKIGInstallAlertHooksIfNeeded(alertClass);

    BOOL containsDestructiveAction = SPKIGActionsContainDestructiveAction(actions);
    NSMutableArray *nativeActions = [NSMutableArray arrayWithCapacity:actions.count];
    NSMutableArray<NSNumber *> *nativeActionStyles = [NSMutableArray arrayWithCapacity:actions.count];
    for (SPKIGAlertAction *action in actions) {
        id nativeAction = ((id (*)(id, SEL, id, long long, id))objc_msgSend)(actionClass,
                                                                             actionSelector,
                                                                             action.title,
                                                                             SPKIGNativeAlertActionStyleForAction(action, containsDestructiveAction),
                                                                             ^{
                                                                                 SPKIGCallActionHandler(action);
                                                                             });
        if (!nativeAction) {
            SPKIGPresentUIKitAlert(presenter, title, message, actions, UIAlertControllerStyleAlert);
            return NO;
        }
        objc_setAssociatedObject(nativeAction, kSPKIGAlertNativeActionStyleKey, @(action.style), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [nativeActions addObject:nativeAction];
        [nativeActionStyles addObject:@(action.style)];
    }

    id style = styleClass ? [[styleClass alloc] init] : nil;
    id alertView = ((id (*)(id, SEL, id, id, id, id, BOOL))objc_msgSend)([alertClass alloc],
                                                                         alertSelector,
                                                                         style,
                                                                         title,
                                                                         message,
                                                                         nativeActions,
                                                                         actions.count <= 2);
    if (![alertView respondsToSelector:@selector(show)]) {
        SPKIGPresentUIKitAlert(presenter, title, message, actions, UIAlertControllerStyleAlert);
        return NO;
    }

    objc_setAssociatedObject(alertView, kSPKIGAlertNativeActionStylesKey, nativeActionStyles, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    ((void (*)(id, SEL))objc_msgSend)(alertView, @selector(show));
    return YES;
}

+ (BOOL)presentActionSheetFromViewController:(UIViewController *)presenter
                                       title:(NSString *)title
                                     message:(NSString *)message
                                     actions:(NSArray<SPKIGAlertAction *> *)actions {
    return [self presentActionSheetFromViewController:presenter
                                                title:title
                                              message:message
                                              actions:actions
                                           forceSheet:NO];
}

+ (BOOL)presentActionSheetFromViewController:(UIViewController *)presenter
                                       title:(NSString *)title
                                     message:(NSString *)message
                                     actions:(NSArray<SPKIGAlertAction *> *)actions
                                  forceSheet:(BOOL)forceSheet {
    if (!forceSheet && SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"26.0")) {
        return [self presentAlertFromViewController:presenter
                                              title:title
                                            message:message
                                            actions:actions];
    }

    Class actionClass = NSClassFromString(@"IGActionSheetControllerAction");
    Class sheetClass = NSClassFromString(@"IGActionSheetController");
    SEL actionSelector = NSSelectorFromString(@"initWithTitle:subtitle:style:handler:accessibilityIdentifier:accessibilityLabel:");
    SEL sheetSelector = @selector(initWithActions:);

    if (!actionClass || !sheetClass || ![actionClass instancesRespondToSelector:actionSelector] || ![sheetClass instancesRespondToSelector:sheetSelector]) {
        SPKIGPresentUIKitAlert(presenter, title, message, actions, UIAlertControllerStyleActionSheet);
        return NO;
    }

    NSMutableArray *nativeActions = [NSMutableArray arrayWithCapacity:actions.count];
    for (SPKIGAlertAction *action in actions) {
        // Include caller-provided cancel actions: the native IGActionSheetController
        // does not render a built-in Cancel on iOS 18 and lower, so skipping them
        // left the sheet with no way to dismiss. (iOS 26 takes the alert path above.)
        id nativeAction = ((id (*)(id, SEL, id, id, long long, id, id, id))objc_msgSend)([actionClass alloc], actionSelector, action.title, nil, SPKIGNativeActionSheetStyle(action.style), ^{
            SPKIGCallActionHandler(action);
        },
                                                                                         nil, action.title);
        if (!nativeAction) {
            SPKIGPresentUIKitAlert(presenter, title, message, actions, UIAlertControllerStyleActionSheet);
            return NO;
        }
        [nativeActions addObject:nativeAction];
    }

    id sheet = nil;
    SEL titledSheetSelector = NSSelectorFromString(@"initWithHeader:primaryText:secondaryText:actions:layoutSpec:impressionTag:");
    if ((title.length > 0 || message.length > 0) && [sheetClass instancesRespondToSelector:titledSheetSelector]) {
        NSAttributedString *primaryText = title.length > 0 ? [[NSAttributedString alloc] initWithString:title] : nil;
        NSAttributedString *secondaryText = message.length > 0 ? [[NSAttributedString alloc] initWithString:message] : nil;
        sheet = ((id (*)(id, SEL, id, id, id, id, id, id))objc_msgSend)([sheetClass alloc],
                                                                        titledSheetSelector,
                                                                        nil,
                                                                        primaryText,
                                                                        secondaryText,
                                                                        nativeActions,
                                                                        nil,
                                                                        nil);
    } else {
        sheet = ((id (*)(id, SEL, id))objc_msgSend)([sheetClass alloc], sheetSelector, nativeActions);
    }
    if (![sheet respondsToSelector:@selector(show)]) {
        SPKIGPresentUIKitAlert(presenter, title, message, actions, UIAlertControllerStyleActionSheet);
        return NO;
    }

    ((void (*)(id, SEL))objc_msgSend)(sheet, @selector(show));
    return YES;
}

+ (BOOL)presentTextInputAlertFromViewController:(UIViewController *)presenter
                                          title:(NSString *)title
                                        message:(NSString *)message
                                    placeholder:(NSString *)placeholder
                                    initialText:(NSString *)initialText
                                autocapitalized:(BOOL)autocapitalized
                                   confirmTitle:(NSString *)confirmTitle
                                    cancelTitle:(NSString *)cancelTitle
                                   confirmStyle:(SPKIGAlertActionStyle)confirmStyle
                                   confirmBlock:(SPKIGAlertTextHandler)confirmBlock
                                    cancelBlock:(SPKIGAlertActionHandler)cancelBlock {
    __block UITextField *textField = nil;
    UIView *inputView = SPKIGCreateInputView(placeholder, initialText, autocapitalized, &textField);

    Class actionClass = NSClassFromString(@"IGCustomAlertAction");
    Class alertClass = NSClassFromString(@"IGDSAlertDialogView");
    Class styleClass = NSClassFromString(@"IGDSAlertDialogStyle");
    SEL actionSelector = @selector(actionWithTitle:style:handler:);
    SEL alertSelector = NSSelectorFromString(@"initWithStyle:titleText:descriptionText:actions:showHorizontalButtons:");

    if (!inputView || !textField || !actionClass || !alertClass || ![actionClass respondsToSelector:actionSelector] || ![alertClass instancesRespondToSelector:alertSelector]) {
        SPKIGPresentUIKitTextInputAlert(presenter, title, message, placeholder, initialText, autocapitalized, confirmTitle, cancelTitle, confirmStyle, confirmBlock, cancelBlock);
        return NO;
    }

    SPKIGInstallAlertHooksIfNeeded(alertClass);

    id cancelAction = ((id (*)(id, SEL, id, long long, id))objc_msgSend)(actionClass,
                                                                         actionSelector,
                                                                         cancelTitle,
                                                                         SPKIGNativeAlertActionStyle(SPKIGAlertActionStyleCancel),
                                                                         ^{
                                                                             if (cancelBlock)
                                                                                 cancelBlock();
                                                                         });
    id confirmAction = ((id (*)(id, SEL, id, long long, id))objc_msgSend)(actionClass,
                                                                          actionSelector,
                                                                          confirmTitle,
                                                                          SPKIGNativeAlertActionStyle(confirmStyle),
                                                                          ^{
                                                                              if (confirmBlock)
                                                                                  confirmBlock(textField.text);
                                                                          });
    if (!cancelAction || !confirmAction) {
        SPKIGPresentUIKitTextInputAlert(presenter, title, message, placeholder, initialText, autocapitalized, confirmTitle, cancelTitle, confirmStyle, confirmBlock, cancelBlock);
        return NO;
    }
    objc_setAssociatedObject(cancelAction, kSPKIGAlertNativeActionStyleKey, @(SPKIGAlertActionStyleCancel), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(confirmAction, kSPKIGAlertNativeActionStyleKey, @(confirmStyle), OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    id style = styleClass ? [[styleClass alloc] init] : nil;
    NSString *descriptionText = SPKIGDescriptionTextForInputAlert(message);
    id alertView = ((id (*)(id, SEL, id, id, id, id, BOOL))objc_msgSend)([alertClass alloc],
                                                                         alertSelector,
                                                                         style,
                                                                         title,
                                                                         descriptionText,
                                                                         @[ cancelAction, confirmAction ],
                                                                         YES);
    if (![alertView respondsToSelector:@selector(show)]) {
        SPKIGPresentUIKitTextInputAlert(presenter, title, message, placeholder, initialText, autocapitalized, confirmTitle, cancelTitle, confirmStyle, confirmBlock, cancelBlock);
        return NO;
    }

    objc_setAssociatedObject(alertView, kSPKIGAlertInputViewKey, inputView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(alertView, kSPKIGAlertInputFieldKey, textField, OBJC_ASSOCIATION_ASSIGN);
    objc_setAssociatedObject(alertView, kSPKIGAlertInputHasMessageKey, @(message.length > 0), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(alertView, kSPKIGAlertNativeActionStylesKey, @[ @(SPKIGAlertActionStyleCancel), @(confirmStyle) ], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    ((void (*)(id, SEL))objc_msgSend)(alertView, @selector(show));
    dispatch_async(dispatch_get_main_queue(), ^{
        [textField becomeFirstResponder];
    });
    return YES;
}

@end
