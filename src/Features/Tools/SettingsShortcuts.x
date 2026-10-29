#import <objc/runtime.h>
#import <substrate.h>

#import "../../InstagramHeaders.h"
#import "../../Settings/SPKSettingsViewController.h"
#import "../../Shared/Gallery/SPKGalleryViewController.h"
#import "../../Shared/Navigation/SPKTabConfiguration.h"
#import "../../Utils.h"
#import "../../App/SPKPerfMeter.h"

static const void *kSPKHomeTabSettingsLongPressAssocKey = &kSPKHomeTabSettingsLongPressAssocKey;
static const void *kSPKGalleryTabLongPressAssocKey = &kSPKGalleryTabLongPressAssocKey;
static const NSTimeInterval kSPKHomeTabLongPressDuration = 0.5;
static const NSTimeInterval kSPKGalleryTabLongPressDuration = 0.65;
static NSString *const kSPKGalleryQuickAccessDisabledValue = @"none";

@interface IGTabBarButton (SPKQuickActions)
- (void)spk_addLongPressWithAction:(SEL)action marker:(const void *)marker minimumDuration:(NSTimeInterval)minimumDuration;
- (void)spk_removeProfileAccountPickerLongPressIfNeeded;
- (void)spk_removeGalleryLongPressIfNeeded;
- (void)spk_removeSettingsLongPressIfNeeded;
- (void)handleHomeTabLongPress:(UILongPressGestureRecognizer *)sender;
- (void)handleDirectInboxTabLongPress:(UILongPressGestureRecognizer *)sender;
@end

// Light confirmation tap fired when a tab-bar shortcut activates. The global
// UIImpactFeedbackGenerator hook (DisableHaptics.x) already respects
// general_disable_haptics, so this stays silent when the user disabled haptics.
static void SPKFireShortcutHaptic(void) {
    if (![SPKUtils getBoolPref:@"tools_shortcut_haptics"])
        return;
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

static NSArray<NSString *> *SPKShortcutTabPriority(void) {
    return @[ @"mainfeed-tab", @"reels-tab", @"direct-inbox-tab", @"camera-tab", @"explore-tab", @"profile-tab" ];
}

static NSString *SPKSparkleTabIdentifierForAccessibilityIdentifier(NSString *identifier) {
    if ([identifier isEqualToString:@"mainfeed-tab"]) return SPKTabIdentifierFeed;
    if ([identifier isEqualToString:@"reels-tab"]) return SPKTabIdentifierClips;
    if ([identifier isEqualToString:@"direct-inbox-tab"]) return SPKTabIdentifierDirect;
    if ([identifier isEqualToString:@"camera-tab"]) return SPKTabIdentifierCreate;
    if ([identifier isEqualToString:@"explore-tab"]) return SPKTabIdentifierSearch;
    if ([identifier isEqualToString:@"profile-tab"]) return SPKTabIdentifierProfile;
    return nil;
}

static BOOL SPKTabHiddenForIdentifier(NSString *identifier) {
    BOOL usesClassic = [[SPKUtils getStringPref:@"interface_nav_order"] isEqualToString:@"classic"];
    // A hidden tab that Saved borrows keeps its button on the bar, so the
    // shortcut stays on it instead of moving to the next tab.
    NSString *sparkleIdentifier = SPKSparkleTabIdentifierForAccessibilityIdentifier(identifier);
    if (sparkleIdentifier && [sparkleIdentifier isEqualToString:SPKEffectiveSavedCarrier()])
        return NO;
    if ([identifier isEqualToString:@"mainfeed-tab"])
        return [SPKUtils getBoolPref:@"interface_hide_feed_tab"];
    if ([identifier isEqualToString:@"reels-tab"])
        return [SPKUtils getBoolPref:@"interface_hide_reels_tab"];
    if ([identifier isEqualToString:@"direct-inbox-tab"])
        return usesClassic || [SPKUtils getBoolPref:@"interface_hide_msgs_tab"];
    if ([identifier isEqualToString:@"camera-tab"])
        return !usesClassic || [SPKUtils getBoolPref:@"interface_hide_create_tab"];
    if ([identifier isEqualToString:@"explore-tab"])
        return [SPKUtils getBoolPref:@"interface_hide_explore_tab"];
    if ([identifier isEqualToString:@"profile-tab"])
        return [SPKUtils getBoolPref:@"interface_hide_profile_tab"];
    return NO;
}

// Quick settings access sits on Home, or on the first visible tab when Home is hidden.
static NSString *SPKResolvedSettingsShortcutTabIdentifier(void) {
    if (![SPKUtils getBoolPref:@"tools_settings_shortcut"])
        return nil;
    for (NSString *identifier in SPKShortcutTabPriority()) {
        if (!SPKTabHiddenForIdentifier(identifier))
            return identifier;
    }
    return nil;
}

// The settings shortcut keeps its tab when both ask for the same one; the gallery
// moves to the next visible tab.
static NSString *SPKResolvedGalleryShortcutTabIdentifier(void) {
    NSString *preferred = SPKGalleryShortcutTabIdentifier();
    if (preferred.length == 0 || [preferred isEqualToString:kSPKGalleryQuickAccessDisabledValue])
        return nil;
    NSString *settingsHost = SPKResolvedSettingsShortcutTabIdentifier();
    if (![preferred isEqualToString:settingsHost])
        return preferred;
    for (NSString *identifier in SPKShortcutTabPriority()) {
        if (!SPKTabHiddenForIdentifier(identifier) && ![identifier isEqualToString:settingsHost])
            return identifier;
    }
    return nil;
}

static BOOL SPKTabIdentifierMatchesGalleryShortcut(NSString *identifier, NSString *label) {
    return SPKTabButtonMatchesTarget(identifier, label, SPKResolvedGalleryShortcutTabIdentifier());
}

// The accessibility label is localized, so identity comes from the identifier match.
static BOOL SPKShouldReplaceProfileTabLongPress(NSString *identifier, NSString *label) {
    return [SPKResolvedGalleryShortcutTabIdentifier() isEqualToString:@"profile-tab"] &&
           SPKTabButtonMatchesTarget(identifier, label, @"profile-tab");
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

    NSString *settingsHost = SPKResolvedSettingsShortcutTabIdentifier();
    BOOL hostsSettings = settingsHost && SPKTabButtonMatchesTarget(identifier, label, settingsHost);
    BOOL matchesGallery = !hostsSettings && SPKTabIdentifierMatchesGalleryShortcut(identifier, label);

    if (hostsSettings) {
        [self spk_addLongPressWithAction:@selector(handleHomeTabLongPress:) marker:kSPKHomeTabSettingsLongPressAssocKey minimumDuration:kSPKHomeTabLongPressDuration];
        // Instagram's own long press on the tab has the same duration, which makes
        // the failure requirement unreliable, so it gives way entirely.
        for (UIGestureRecognizer *gesture in [self.gestureRecognizers copy]) {
            if ([gesture isKindOfClass:[UILongPressGestureRecognizer class]] &&
                !objc_getAssociatedObject(gesture, kSPKHomeTabSettingsLongPressAssocKey))
                [self removeGestureRecognizer:gesture];
        }
    } else {
        [self spk_removeSettingsLongPressIfNeeded];
    }

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
BOOL shouldCancel = (marker == kSPKGalleryTabLongPressAssocKey || marker == kSPKHomeTabSettingsLongPressAssocKey);
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



%new - (void)spk_removeSettingsLongPressIfNeeded {
for (UIGestureRecognizer *gesture in [self.gestureRecognizers copy]) {
    if ([gesture isKindOfClass:[UILongPressGestureRecognizer class]] &&
        objc_getAssociatedObject(gesture, kSPKHomeTabSettingsLongPressAssocKey))
        [self removeGestureRecognizer:gesture];
}
}

%new - (void)handleHomeTabLongPress:(UILongPressGestureRecognizer *)sender {
if (sender.state != UIGestureRecognizerStateBegan)
    return;

SPKFireShortcutHaptic();
[SPKUtils showSettingsVC:[self window]];
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
