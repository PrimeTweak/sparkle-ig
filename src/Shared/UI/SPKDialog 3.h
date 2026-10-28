#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, SPKDialogActionStyle) {
    SPKDialogActionStyleDefault,
    SPKDialogActionStyleCancel,
    SPKDialogActionStyleDestructive,
};

@interface SPKDialogAction : NSObject
@property (nonatomic, copy, readonly) NSString *title;
@property (nonatomic, readonly) SPKDialogActionStyle style;
@property (nonatomic, copy, readonly, nullable) dispatch_block_t handler;

+ (instancetype)actionWithTitle:(NSString *)title
                          style:(SPKDialogActionStyle)style
                        handler:(nullable dispatch_block_t)handler;
@end

// Sparkle's own dialog, in the tweak's material rather than Instagram's.
//
// The card is laid over the window, so it survives a controller being swapped
// underneath it, and it cannot be dismissed by tapping outside: a dialog asks a
// question and one of its buttons has to answer.
@interface SPKDialog : NSObject

// Returns whether the dialog was put on screen: callers that have a fallback
// path need to know when it was not.
+ (BOOL)presentFromController:(nullable UIViewController *)controller
                        title:(NSString *)title
                      message:(nullable NSString *)message
                      actions:(NSArray<SPKDialogAction *> *)actions;

typedef void (^SPKDialogTextHandler)(NSString *text);

// A dialog carrying a single text field, for the handful of prompts that ask
// for a name rather than a yes or no.
+ (BOOL)presentTextInputFromController:(nullable UIViewController *)controller
                                 title:(NSString *)title
                               message:(nullable NSString *)message
                           placeholder:(nullable NSString *)placeholder
                           initialText:(nullable NSString *)initialText
                       autocapitalized:(BOOL)autocapitalized
                          confirmTitle:(NSString *)confirmTitle
                           cancelTitle:(NSString *)cancelTitle
                          confirmStyle:(SPKDialogActionStyle)confirmStyle
                          confirmBlock:(SPKDialogTextHandler)confirmBlock
                           cancelBlock:(nullable dispatch_block_t)cancelBlock;

+ (BOOL)presentInWindow:(UIWindow *)window
                  title:(NSString *)title
                message:(nullable NSString *)message
                actions:(NSArray<SPKDialogAction *> *)actions;

@end

NS_ASSUME_NONNULL_END
