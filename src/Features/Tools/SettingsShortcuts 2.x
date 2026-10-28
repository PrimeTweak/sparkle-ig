#import <objc/runtime.h>
#import <substrate.h>

#import "../../InstagramHeaders.h"
#import "../../Settings/SPKSettingsViewController.h"
#import "../../Shared/Gallery/SPKGalleryViewController.h"
#import "../../Utils.h"
#import "../../App/SPKPerfMeter.h"

static const void *kSPKGalleryTabLongPressAssocKey = &kSPKGalleryTabLongPressAssocKey;
static const void *kSPKProfileMoreSettingsLongPressAssocKey = &kSPKProfileMoreSettingsLongPressAssocKey;
static const NSTimeInterval kSPKGalleryTabLongPressDuration = 0.65;
static NSString *const kSPKGalleryQuickAccessDisabledValue = @"none";

@interface IGTabBarButton (SPKQuickActions)
- (void)spk_addLongPressWithAction:(SEL)action marker:(const void *)marker minimumDuration:(NSTimeInterval)minimumDuration;
- (void)spk_removeProfileAccountPickerLongPressIfNeeded;
- (void)spk_removeGalleryLongPressIfNeeded;
- (void)handleDirectInboxTabLongPress:(UILongPressGestureRecognizer *)sender;
@end

// Light confirmation tap fired when a tab-bar shortcut activates. The global
// UIImpactFeedbackGenerator hook (DisableHaptics.x) already respects
// general_disable_haptics, so this stays silent when the user disabled haptics.
static void SPKFireShortcutHaptic(void) {
    UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [generator prepare];
    [generator impactOccurred];
}

static NSString *SPKGalleryShortcutTabIdentifier(void) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *identifier = [defaults stringForKey:@"gallery_quick_access_tab"];
    if (identifier.length == 0) {
        identifier = kSPKGalleryQuickAccessDisabledValue;
    }
    if ([identifier isEqualToString:kSPKGalleryQuickAccessDisabledValue])
        return identifier;

    NSString *target = identifier;
    BOOL usesClassicTabOrdering = [[[NSUserDefaults standardUserDefaults] stringForKey:@"interface_nav_order"] isEqualToString:@"classic"];
    if (usesClassicTabOrdering && [target isEqualToString:@"direct-inbox-tab"])
        return @"camera-tab";
    if (!usesClassicTabOrdering && [target isEqualToString:@"camera-tab"])
        return @"direct-inbox-tab";
    return target;
}

static BOOL SPKTabButtonMatchesTarget(NSString *identifier, NSString *label, NSString *target) {
    if (target.length == 0 || [target isEqualToString:kSPKGalleryQuickAccessDisabledValue])
        return NO;

    NSString *candidate = [NSString stringWithFormat:@"%@ %@", identifier ?: @"", label ?: @""].lowercaseString;
    if ([identifier isEqualToString:target])
        return YES;
    if ([target isEqualToString:@"mainfeed-tab"] && ([candidate containsString:@"mainfeed"] || [candidate containsString:@"home"]))
        return YES;
    if ([target isEqualToString:@"reels-tab"] && ([candidate containsString:@"clips"] || [candidate containsString:@"reels"]))
        return YES;
    if ([target isEqualToString:@"camera-tab"] && [candidate containsString:@"create"])
        return YES;
    if ([target isEqualToString:@"explore-tab"] && ([candidate containsString:@"explore"] || [candidate containsString:@"search"]))
        return YES;
    if ([target isEqualToString:@"direct-inbox-tab"] && ([candidate containsString:@"direct"] ||
                                                         [candidate containsString:@"inbox"] ||
                                                         [candidate containsString:@"message"]))
        return YES;
    if ([target isEqualToString:@"profile-tab"] && ([candidate containsString:@"profile"] ||
                                                    [candidate containsString:@"tab_avatar"]))
        return YES;
    return NO;
}




// The gallery shortcut is the only one left on the tab bar, so the tab it asks
// for is the tab it gets. It used to arbitrate against a settings shortcut that
// no longer exists, falling back down a priority list when the two collided.
static NSString *SPKResolvedGalleryShortcutTabIdentifier(void) {
    NSString *preferred = SPKGalleryShortcutTabIdentifier();
    if (preferred.length == 0 || [preferred isEqualToString:kSPKGalleryQuickAccessDisabledValue])
        return nil;
    return preferred;
}

static BOOL SPKTabIdentifierMatchesGalleryShortcut(NSString *identifier, NSString *label) {
    return SPKTabButtonMatchesTarget(identifier, label, SPKResolvedGalleryShortcutTabIdentifier());
}

static BOOL SPKShouldReplaceProfileTabLongPress(NSString *identifier, NSString *label) {
    return [SPKGalleryShortcutTabIdentifier() isEqualToString:@"profile-tab"] &&
           [identifier isEqualToString:@"profile-tab"] &&
           [(label ?: @"") isEqualToString:@"Profile"];
}

%group SPKSettingsShortcutsHooks

%hook IGTabBarButton

- (void)setAccessibilityIdentifier:(NSString *)identifier {
    %orig;
    [self setNeedsLayout];
}

- (void)setAccessibilityLabel:(NSString *)label {
    %orig;
    [self setNeedsLayout];
}

- (void)layoutSubviews {
    %orig;
    SPK_PERF_SCOPE(@"SettingsShortcuts.layoutSubviews");

    NSString *identifier = self.accessibilityIdentifier ?: @"";
    NSString *label = self.accessibilityLabel ?: @"";

    BOOL matchesGallery = SPKTabIdentifierMatchesGalleryShortcut(identifier, label);

    if (matchesGallery) {
        if (SPKShouldReplaceProfileTabLongPress(identifier, label)) {
            [self spk_removeProfileAccountPickerLongPressIfNeeded];
        }
        [self spk_addLongPressWithAction:@selector(handleDirectInboxTabLongPress:) marker:kSPKGalleryTabLongPressAssocKey minimumDuration:kSPKGalleryTabLongPressDuration];
    } else {
        [self spk_removeGalleryLongPressIfNeeded];
    }
}

%new - (void)spk_addLongPressWithAction:(SEL)action marker:(const void *)marker minimumDuration:(NSTimeInterval)minimumDuration {
for (UIGestureRecognizer *gesture in self.gestureRecognizers) {
    if (![gesture isKindOfClass:[UILongPressGestureRecognizer class]])
        continue;
    if (objc_getAssociatedObject(gesture, marker)) {
        return;
    }
}

UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:action];
longPress.minimumPressDuration = minimumDuration;
BOOL shouldCancel = (marker == kSPKGalleryTabLongPressAssocKey);
longPress.cancelsTouchesInView = shouldCancel;
longPress.delaysTouchesBegan = shouldCancel;
longPress.delaysTouchesEnded = shouldCancel;

for (UIGestureRecognizer *existing in self.gestureRecognizers) {
    [existing requireGestureRecognizerToFail:longPress];
}

[self addGestureRecognizer:longPress];
objc_setAssociatedObject(longPress, marker, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

%new - (void)spk_removeProfileAccountPickerLongPressIfNeeded {
for (UIGestureRecognizer *gesture in [self.gestureRecognizers copy]) {
    if (![gesture isKindOfClass:[UILongPressGestureRecognizer class]])
        continue;
    if (objc_getAssociatedObject(gesture, kSPKGalleryTabLongPressAssocKey))
        continue;

    UILongPressGestureRecognizer *longPress = (UILongPressGestureRecognizer *)gesture;
    if (fabs(longPress.minimumPressDuration - 0.5) > 0.01)
        continue;

    [self removeGestureRecognizer:gesture];
}
}

%new - (void)spk_removeGalleryLongPressIfNeeded {
for (UIGestureRecognizer *gesture in [self.gestureRecognizers copy]) {
    if (![gesture isKindOfClass:[UILongPressGestureRecognizer class]])
        continue;
    if (objc_getAssociatedObject(gesture, kSPKGalleryTabLongPressAssocKey)) {
        [self removeGestureRecognizer:gesture];
    }
}
}



%new - (void)handleDirectInboxTabLongPress:(UILongPressGestureRecognizer *)sender {
if (sender.state != UIGestureRecognizerStateBegan)
    return;

SPKFireShortcutHaptic();
[SPKGalleryViewController presentGallery];
}
%end


%end

void SPKInstallSettingsShortcutsHooksIfNeeded(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        %init(SPKSettingsShortcutsHooks);
    });
}
