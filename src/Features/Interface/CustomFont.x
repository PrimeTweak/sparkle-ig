#import "../../App/SPKStabilityGuard.h"
#import "../../InstagramHeaders.h"
#import "../../Shared/Fonts/SPKFontManager.h"
#import "../../Utils.h"

// Replaces the app-wide typeface with a font the user imported.
//
// Two families of entry point matter. Instagram's own text goes through the
// `ig_*SystemFont*` category on UIFont (its design system funnels every label
// through those), and UIKit's own chrome -- alerts, the keyboard, Sparkle's own
// settings UI -- goes through `+systemFontOfSize:` and friends. Hooking only the
// first leaves half the app untouched, which reads as a broken feature.
//
// Everything here replaces the *face* and never the size: each hook calls through
// first and rebuilds at the size the original returned. That keeps Dynamic Type
// working (the `*DynamicFont*` variants scale the size before returning it) and
// means a font that IG sized specially stays sized specially.
//
// Deliberately NOT hooked:
//   - monospaced-digit variants: swapping in a proportional face breaks the
//     column alignment they exist for (timers, view counts, countdowns).
//   - branded and script faces (`ig_LogoRegularOfSize:`, `ig_Sans*`, and the
//     story text-tool fonts): those are artwork and composer content, not UI
//     chrome. Replacing them would corrupt the logo and the story font picker.

static inline UIFont *SPKCustomFontReplace(UIFont *original, UIFontWeight weight, BOOL italic) {
    if (!original)
        return original;
    UIFont *replacement = [SPKFontManager fontOfSize:original.pointSize weight:weight italic:italic];
    return replacement ?: original;
}

// The weight a UIKit font already carries, so the replacement can match a font
// UIKit derived rather than one we were told the weight of.
static UIFontWeight SPKCustomFontWeightOf(UIFont *font) {
    NSDictionary *traits = [font.fontDescriptor objectForKey:UIFontDescriptorTraitsAttribute];
    NSNumber *weight = traits[UIFontWeightTrait];
    return weight ? weight.doubleValue : UIFontWeightRegular;
}

static BOOL SPKCustomFontIsItalic(UIFont *font) {
    return (font.fontDescriptor.symbolicTraits & UIFontDescriptorTraitItalic) != 0;
}

%group SPKCustomFontHooks

%hook UIFont

#pragma mark - UIKit chrome

+ (UIFont *)systemFontOfSize:(CGFloat)size {
    return SPKCustomFontReplace(%orig, UIFontWeightRegular, NO);
}

+ (UIFont *)systemFontOfSize:(CGFloat)size weight:(UIFontWeight)weight {
    return SPKCustomFontReplace(%orig, weight, NO);
}

+ (UIFont *)boldSystemFontOfSize:(CGFloat)size {
    return SPKCustomFontReplace(%orig, UIFontWeightBold, NO);
}

+ (UIFont *)italicSystemFontOfSize:(CGFloat)size {
    return SPKCustomFontReplace(%orig, UIFontWeightRegular, YES);
}

// Dynamic Type. The original already resolved the user's text size and the
// style's weight, so both are read back off it rather than assumed.
+ (UIFont *)preferredFontForTextStyle:(UIFontTextStyle)style {
    UIFont *original = %orig;
    return SPKCustomFontReplace(original, SPKCustomFontWeightOf(original), SPKCustomFontIsItalic(original));
}

+ (UIFont *)preferredFontForTextStyle:(UIFontTextStyle)style compatibleWithTraitCollection:(UITraitCollection *)traitCollection {
    UIFont *original = %orig;
    return SPKCustomFontReplace(original, SPKCustomFontWeightOf(original), SPKCustomFontIsItalic(original));
}

#pragma mark - Instagram's design system

+ (UIFont *)ig_systemFontOfSize:(CGFloat)size weight:(CGFloat)weight {
    return SPKCustomFontReplace(%orig, weight, NO);
}

+ (UIFont *)ig_systemFontOfSize:(CGFloat)size {
    return SPKCustomFontReplace(%orig, UIFontWeightRegular, NO);
}

+ (UIFont *)ig_lightSystemFontOfSize:(CGFloat)size {
    return SPKCustomFontReplace(%orig, UIFontWeightLight, NO);
}

+ (UIFont *)ig_mediumSystemFontOfSize:(CGFloat)size {
    return SPKCustomFontReplace(%orig, UIFontWeightMedium, NO);
}

+ (UIFont *)ig_semiboldSystemFontOfSize:(CGFloat)size {
    return SPKCustomFontReplace(%orig, UIFontWeightSemibold, NO);
}

+ (UIFont *)ig_boldSystemFontOfSize:(CGFloat)size {
    return SPKCustomFontReplace(%orig, UIFontWeightBold, NO);
}

+ (UIFont *)ig_heavySystemFontOfSize:(CGFloat)size {
    return SPKCustomFontReplace(%orig, UIFontWeightHeavy, NO);
}

+ (UIFont *)ig_italicSystemFontOfSize:(CGFloat)size {
    return SPKCustomFontReplace(%orig, UIFontWeightRegular, YES);
}

+ (UIFont *)ig_systemDynamicFontOfSize:(CGFloat)size {
    return SPKCustomFontReplace(%orig, UIFontWeightRegular, NO);
}

+ (UIFont *)ig_systemDynamicFontOfSize:(CGFloat)size weight:(CGFloat)weight {
    return SPKCustomFontReplace(%orig, weight, NO);
}

+ (UIFont *)ig_lightSystemDynamicFontOfSize:(CGFloat)size {
    return SPKCustomFontReplace(%orig, UIFontWeightLight, NO);
}

+ (UIFont *)ig_semiboldSystemDynamicFontOfSize:(CGFloat)size {
    return SPKCustomFontReplace(%orig, UIFontWeightSemibold, NO);
}

+ (UIFont *)ig_boldSystemDynamicFontOfSize:(CGFloat)size {
    return SPKCustomFontReplace(%orig, UIFontWeightBold, NO);
}

+ (UIFont *)ig_heavySystemDynamicFontOfSize:(CGFloat)size {
    return SPKCustomFontReplace(%orig, UIFontWeightHeavy, NO);
}

%end

%end

// Installed from %ctor rather than the staged registry: fonts are requested by the
// very first view Instagram builds, long before the surface timers fire, and a label
// keeps whatever font it was built with. Installing late would leave the launch UI
// permanently on the system face.
//
// The hooks go in unconditionally and re-read the preference on every call (through
// SPKFontManager's cached lookup), so turning the feature on doesn't need a second
// restart. Only the kill switch is honored here, since that one is meant to keep
// Sparkle out of the way entirely.
%ctor {
    if ([NSUserDefaults.standardUserDefaults boolForKey:@"tools_disable_all"] || SPKStabilityGuardIsSafeStartupMode())
        return;
    %init(SPKCustomFontHooks);
}

// The registry entry exists so the feature appears in Hook Bisect alongside the
// others; the real installation already happened in %ctor.
void SPKInstallCustomFontHooksIfEnabled(void) {
}
