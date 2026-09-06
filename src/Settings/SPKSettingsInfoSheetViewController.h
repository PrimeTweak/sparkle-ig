#import <UIKit/UIKit.h>

#import "SPKSetting.h"

NS_ASSUME_NONNULL_BEGIN

/// The "what does this do?" sheet behind a section's info button.
///
/// Built from the section's own rows: every row carrying `helpText` contributes
/// one entry, shown with that row's icon and title. Keying the explanations to
/// the row objects means a hidden or reordered row cannot desync them, which a
/// numbered footer could.
@interface SPKSettingsInfoSheetViewController : UIViewController

- (instancetype)initWithTitle:(nullable NSString *)title
                         rows:(NSArray<SPKSetting *> *)rows NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithNibName:(nullable NSString *)nibName bundle:(nullable NSBundle *)bundle NS_UNAVAILABLE;
- (instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;

/// Wraps the sheet in Sparkle's modal chrome and presents it from `presenter`.
/// Does nothing when `rows` is empty.
+ (void)presentFromViewController:(UIViewController *)presenter
                            title:(nullable NSString *)title
                             rows:(NSArray<SPKSetting *> *)rows;

@end

/// Section dictionary key holding an `NSNumber` boolean that overrides whether
/// the section's group is explained by an info button or by a plain footer. Set
/// it with `SPKTopicSectionWithInfoSheet()`; absent, the row count decides.
FOUNDATION_EXPORT NSString *const SPKTopicSectionInfoSheetKey;

/// The rows of `section` that carry help text, in display order. Rows currently
/// removed by their `hiddenProvider` are skipped, so an explanation never
/// describes a control the reader cannot find.
FOUNDATION_EXPORT NSArray<SPKSetting *> *SPKSettingsHelpRowsInSection(NSDictionary *section);

NS_ASSUME_NONNULL_END
