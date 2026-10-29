#import "../../Utils.h"
#import <objc/runtime.h>

// Adds a Sparkle button and a close button to the navigation bar of Instagram's
// own "Settings and activity" screen, seated once per appearance.

static const void *kSPKSettingsEntryItemAssocKey = &kSPKSettingsEntryItemAssocKey;
static const void *kSPKSettingsCloseItemAssocKey = &kSPKSettingsCloseItemAssocKey;
static const void *kSPKSettingsCloseTargetAssocKey = &kSPKSettingsCloseTargetAssocKey;

@interface SPKNativeSettingsEntryTarget : NSObject
@property (nonatomic, weak) UIViewController *owner;
+ (instancetype)sharedTarget;
- (void)openSparkleSettings:(id)sender;
@end

@implementation SPKNativeSettingsEntryTarget

+ (instancetype)sharedTarget {
    static SPKNativeSettingsEntryTarget *target;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        target = [SPKNativeSettingsEntryTarget new];
    });
    return target;
}

// Presents from the screen the button lives on: Instagram's settings already sit
// over the window's root, which would refuse a second presentation.
- (void)openSparkleSettings:(id)sender {
    [SPKUtils showSettingsFromController:self.owner];
}

@end

// One per screen, so a later settings screen never takes over another's button.
@interface SPKNativeSettingsCloseTarget : NSObject
@property (nonatomic, weak) UIViewController *controller;
- (void)close:(id)sender;
@end

@implementation SPKNativeSettingsCloseTarget

// The profile menu pushes the screen and the instagram://settings route presents
// it, so the button goes back in the first case and dismisses in the second.
- (void)close:(id)sender {
    UIViewController *controller = self.controller;
    UINavigationController *navigation = controller.navigationController;
    UIViewController *stacked = controller;
    while (stacked.parentViewController && stacked.parentViewController != navigation)
        stacked = stacked.parentViewController;

    NSUInteger index = navigation ? [navigation.viewControllers indexOfObject:stacked] : NSNotFound;
    if (index != NSNotFound && index > 0) {
        [navigation popToViewController:navigation.viewControllers[index - 1] animated:YES];
        return;
    }
    [controller dismissViewControllerAnimated:YES completion:nil];
}

@end

// The controller is a Swift generic whose mangled name varies, so it is matched
// by class-name substring or by the title Instagram gives the screen.
static BOOL SPKIsNativeSettingsController(UIViewController *controller) {
    if (!controller)
        return NO;
    const char *name = class_getName(object_getClass(controller));
    if (name && strstr(name, "IGSettingsHostingController"))
        return YES;
    return [controller.title isEqualToString:@"Settings and activity"];
}

// Instagram's own left button is backed by a custom view that ignores title, image
// and tint, so it is replaced by a black close mark; the Sparkle entry takes the
// trailing side.
static void SPKArrangeSettingsBar(UIViewController *controller, UIBarButtonItem *entry) {
    UIColor *ink = [SPKUtils SPKColor_InstagramPrimaryText];
    controller.navigationController.navigationBar.tintColor = ink;
    entry.tintColor = ink;

    UIBarButtonItem *close = objc_getAssociatedObject(controller, kSPKSettingsCloseItemAssocKey);
    if (!close) {
        SPKNativeSettingsCloseTarget *target = [SPKNativeSettingsCloseTarget new];
        target.controller = controller;
        objc_setAssociatedObject(controller, kSPKSettingsCloseTargetAssocKey, target, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

        UIImage *mark =
            [UIImage systemImageNamed:@"xmark"
                    withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:16.0
                                                                                      weight:UIImageSymbolWeightSemibold]];
        close = [[UIBarButtonItem alloc] initWithImage:mark
                                                 style:UIBarButtonItemStylePlain
                                                target:target
                                                action:@selector(close:)];
        close.accessibilityLabel = @"Close";
        objc_setAssociatedObject(controller, kSPKSettingsCloseItemAssocKey, close, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    close.tintColor = ink;

    controller.navigationItem.leftBarButtonItems = @[ close ];
    controller.navigationItem.rightBarButtonItems = @[ entry ];
}

// Arranged on every appearance: Instagram restyles this bar and would otherwise
// bring its blue button back when the screen is revisited.
static void SPKSeatSettingsEntryItem(UIViewController *controller) {
    if (!SPKIsNativeSettingsController(controller))
        return;

    UIBarButtonItem *entry = objc_getAssociatedObject(controller, kSPKSettingsEntryItemAssocKey);
    if (!entry) {
        UIImage *icon =
            [UIImage systemImageNamed:@"sparkles"
                    withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:18.0
                                                                                      weight:UIImageSymbolWeightRegular]];
        entry = [[UIBarButtonItem alloc] initWithImage:icon
                                                 style:UIBarButtonItemStylePlain
                                                target:[SPKNativeSettingsEntryTarget sharedTarget]
                                                action:@selector(openSparkleSettings:)];
        entry.accessibilityLabel = @"Sparkle";
        objc_setAssociatedObject(controller, kSPKSettingsEntryItemAssocKey, entry, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    [SPKNativeSettingsEntryTarget sharedTarget].owner = controller;
    SPKArrangeSettingsBar(controller, entry);
}

%group SPKNativeSettingsEntryHooks

%hook UIViewController

// Before the first paint, so Instagram's blue button never shows for a frame.
- (void)viewWillAppear:(BOOL)animated {
    %orig;
    SPKSeatSettingsEntryItem(self);
}

// Again after appearance: some transitions restyle the bar once the screen is up.
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    SPKSeatSettingsEntryItem(self);
}

%end

%end

void SPKInstallNativeSettingsEntryHooksIfNeeded(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        %init(SPKNativeSettingsEntryHooks);
    });
}
