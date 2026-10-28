#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// YES when running on iOS 26+ with the Liquid Glass runtime (`UIGlassEffect`)
/// available. Chip bars use this to decide between glass capsules and the solid
/// fill fallback.
BOOL SPKChipGlassAvailable(void);

/// Installs (once) and updates a Liquid Glass capsule background on a chip
/// button. Selected chips get a tinted, prominent glass; unselected chips get
/// clear glass. The glass view is cached on the chip via an associated object,
/// so repeated calls (e.g. from `refreshSelection`) only swap the effect.
///
/// Returns YES when glass was applied — the caller should leave the chip's own
/// `backgroundColor` clear. Returns NO on pre-iOS-26, where the caller keeps its
/// existing solid fill.
BOOL SPKChipApplyGlass(UIButton *chip, BOOL selected, CGFloat cornerRadius, UIColor *_Nullable selectedTint);

NS_ASSUME_NONNULL_END
