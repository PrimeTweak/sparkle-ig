#import <UIKit/UIKit.h>

#import "SPKSetting.h"

NS_ASSUME_NONNULL_BEGIN

/// The "what does this do?" sheet behind a section's ⓘ button.
///
/// Built from the section's own rows: every row carrying a `helpText` contributes
/// one entry, rendered with that row's icon and title. Because the entries are
/// keyed by the row object, a hidden or reordered row can't desync the
/// explanations the way a numbered footer does.
///
/// The row title is already shown above its text here, so a `helpText` that only
/// restates the title reads twice. Leave `helpText` nil on those rows — they're
/// simply absent from the sheet.
@interface SPKSettingsHelpSheetViewController : UIViewController

+ (void)presentForSectionTitle:(nullable NSString *)sectionTitle
                          rows:(NSArray<SPKSetting *> *)rows
            fromViewController:(UIViewController *)presenter;

@end

/// The rows of `section` that carry help text, in display order. Rows currently
/// removed by their `hiddenProvider` are skipped.
FOUNDATION_EXPORT NSArray<SPKSetting *> *SPKSettingsHelpRowsInSection(NSDictionary *section);

NS_ASSUME_NONNULL_END
