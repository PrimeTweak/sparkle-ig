#import "../../Utils.h"

// Instagram Plus surfaces an upsell button (an IGTapButton with
// accessibilityIdentifier "aura_upsell_button" — "Aura" is IG's internal
// codename for the Plus program) that opens the subscription sheet. In the story
// viewer list it sits where the (server-locked) "Search Viewer List" entry would
// be. Since that search can't be unlocked client-side, this just hides the
// upsell button so it doesn't take up space or bait taps.
//
// We match on the accessibility identifier (stable, language-independent). We
// enforce in two places: setAccessibilityIdentifier: hides the button as soon as
// the id is assigned, and setHidden: re-asserts if IG later tries to un-hide it
// (which it does — observed on-device). setHidden: only fires on visibility
// changes, so this stays off the per-layout hot path that every IGTapButton in
// the app would otherwise pay.
//
// The hook is installed unconditionally and self-gates on the pref, so toggling
// takes effect without a restart. IGTapButton exists across IG versions.

static NSString *const kSPKAuraUpsellButtonIdentifier = @"aura_upsell_button";

static inline BOOL SPKHideViewerPlusButtonEnabled(void) {
    return [SPKUtils getBoolPref:@"stories_hide_ig_plus_button"];
}

%group SPKHideViewerPlusButtonHooks

%hook IGTapButton

- (void)setAccessibilityIdentifier:(NSString *)identifier {
    %orig(identifier);

    if ([identifier isEqualToString:kSPKAuraUpsellButtonIdentifier] && SPKHideViewerPlusButtonEnabled()) {
        self.hidden = YES;
        SPKLog(@"Upsell", @"[Sparkle] Hid Instagram Plus upsell button");
    }
}

- (void)setHidden:(BOOL)hidden {
    // Keep our target hidden if IG tries to show it again.
    if (!hidden && SPKHideViewerPlusButtonEnabled() &&
        [self.accessibilityIdentifier isEqualToString:kSPKAuraUpsellButtonIdentifier]) {
        %orig(YES);
        return;
    }
    %orig(hidden);
}

%end

%end

void SPKInstallHideViewerPlusButtonHooksIfEnabled(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        %init(SPKHideViewerPlusButtonHooks);
    });
}
