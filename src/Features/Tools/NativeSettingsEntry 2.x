#import "../../Utils.h"
#import <objc/runtime.h>

// Adds a Sparkle button to the navigation bar of Instagram's own
// "Settings and activity" screen.
//
// The button is a UIBarButtonItem on the controller's navigationItem, installed
// once when the screen appears. UIKit owns its placement and its glass
// treatment; nothing here runs per frame.

static const void *kSPKSettingsEntryItemAssocKey = &kSPKSettingsEntryItemAssocKey;
static const void *kSPKSettingsCloseItemAssocKey = &kSPKSettingsCloseItemAssocKey;

@interface SPKNativeSettingsEntryTarget : NSObject
@property (nonatomic, weak) UIViewController *owner;
+ (instancetype)sharedTarget;
- (void)openSparkleSettings:(id)sender;
- (void)closeSettings:(id)sender;
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

- (void)closeSettings:(id)sender {
    // Dismissal reads the hierarchy rather than a remembered controller.
    //
    // The owner was held on this shared target, so any later screen matching the
    // predicate overwrote it and the button stopped closing anything. Whatever
    // is topmost is asked to go away instead, which needs no memory at all.
    UIViewController *root = UIApplication.sharedApplication.keyWindow.rootViewController;
    UIViewController *top = root;
    while (top.presentedViewController)
        top = top.presentedViewController;

    if (top != root && top.presentingViewController) {
        [top.presentingViewController dismissViewControllerAnimated:YES completion:nil];
        return;
    }
    [self.owner dismissViewControllerAnimated:YES completion:nil];
}

- (void)openSparkleSettings:(id)sender {
    // Present from the screen this button lives on. Going through the key
    // window presented from its root — but Instagram's settings sit over that
    // root, and a controller already presenting refuses to present again, which
    // is why the tap did nothing at all.
    [SPKUtils showSettingsFromController:self.owner];
}

@end

// Matched on either signal so a rename on one side still lands: the Swift class
// name, or the title Instagram gives the screen. The controller is a Swift
// generic, so its mangled name varies by specialisation and is matched by
// substring rather than hooked directly.
static BOOL SPKIsNativeSettingsController(UIViewController *controller) {
    if (!controller)
        return NO;
    const char *name = class_getName(object_getClass(controller));
    if (name && strstr(name, "IGSettingsHostingController"))
        return YES;
    return [controller.title isEqualToString:@"Settings and activity"];
}

// Puts the bar in the shape the screen has when Instagram opens it itself.
//
// Instagram's own button here is backed by a custom view: setting its title,
// image or tint changed nothing on screen while the sides it was moved to did
// change, which leaves no other explanation. So it is replaced rather than
// restyled — a plain item, drawn black, that dismisses the screen.
//
// "Done" is not Instagram's wording either; it appears because this screen was
// routed to as a modal instead of being pushed from a profile. A close mark
// says what the control does without borrowing a label from nowhere, and a
// close control belongs on the leading edge, so the Sparkle entry takes the
// trailing one.
static void SPKArrangeSettingsBar(UIViewController *controller, UIBarButtonItem *entry) {
    UIColor *ink = [SPKUtils SPKColor_InstagramPrimaryText];
    controller.navigationController.navigationBar.tintColor = ink;
    entry.tintColor = ink;

    UIBarButtonItem *close = objc_getAssociatedObject(controller, kSPKSettingsCloseItemAssocKey);
    if (!close) {
        UIImage *mark =
            [UIImage systemImageNamed:@"xmark"
                    withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:16.0
                                                                                      weight:UIImageSymbolWeightSemibold]];
        close = [[UIBarButtonItem alloc] initWithImage:mark
                                                 style:UIBarButtonItemStylePlain
                                                target:[SPKNativeSettingsEntryTarget sharedTarget]
                                                action:@selector(closeSettings:)];
        close.accessibilityLabel = @"Close";
        objc_setAssociatedObject(controller, kSPKSettingsCloseItemAssocKey, close, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    close.tintColor = ink;

    controller.navigationItem.leftBarButtonItems = @[ close ];
    controller.navigationItem.rightBarButtonItems = @[ entry ];
}

static void SPKSeatSettingsEntryItem(UIViewController *controller) {
    if (!SPKIsNativeSettingsController(controller))
        return;

    // The entry is built once and kept. The arranging runs on every appearance,
    // because Instagram restyles this bar and would otherwise take its blue Done
    // back the moment the screen is revisited.
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

// Arranged before the first paint, not after it. Seating the bar only once the
// screen had appeared let Instagram's blue button show for a frame.
- (void)viewWillAppear:(BOOL)animated {
    %orig;
    SPKSeatSettingsEntryItem(self);
}

// Kept as well: the bar is restyled after appearance on some transitions, and
// the arranging is cheap enough to run twice.
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
