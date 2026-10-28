#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// A single page's content in a paged sheet.
///
/// A page has a title, an optional body paragraph, and an optional list of rows.
/// Each row is a dictionary with a `text` key plus optionally:
///   - `icon`  — an Instagram catalog asset name (see SPKAssetUtils overrides),
///   - absent  — a "teaser" row (accented italic text with a leading spacer).
@interface SPKPagedSheetPage : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *body;
@property (nonatomic, copy, nullable) NSArray<NSDictionary *> *rows;

+ (instancetype)pageWithTitle:(NSString *)title
                         body:(NSString *)body
                         rows:(nullable NSArray<NSDictionary *> *)rows;
@end

/// A reusable, brand-heroed paged intro/announcement sheet.
///
/// Owns the shared scaffolding: the animated Sparkle brand hero, a horizontal
/// paging scroll view whose pages each scroll vertically to fit small screens, a
/// page control, a glass primary CTA, and a skip button. Subclasses supply only
/// their content and CTA wording by overriding the hooks below.
///
/// The hero animates on both axes: it scales/rotates as pages change and gently
/// collapses (scales, fades, tucks up) as a long page scrolls, springing back at
/// the top.
@interface SPKPagedSheetViewController : UIViewController

/// Invoked once, after the sheet dismisses, when the user finishes, skips, or
/// (when interactive dismiss is allowed) swipes it away. Use it to persist state.
@property (nonatomic, copy, nullable) void (^onFinish)(void);

/// Overrides the final page's CTA title for this presentation only (e.g. an
/// onboarding that hands off to What's New with a "Show What's New" button). When
/// nil, `-finishButtonTitle` is used.
@property (nonatomic, copy, nullable) NSString *finishTitleOverride;

/// Presents the sheet modally as a page sheet from `presenter` (or the top-most
/// view controller when nil). No-ops if a presentation is already in flight.
/// Polymorphic: works for any subclass via `+[self alloc]`.
+ (void)presentFromViewController:(nullable UIViewController *)presenter
                         onFinish:(nullable void (^)(void))onFinish;

#pragma mark - Subclass hooks

/// The pages to display. Required — the base returns an empty list.
- (NSArray<SPKPagedSheetPage *> *)buildPages;

/// CTA title shown on every page except the last. Default: "Continue".
- (NSString *)continueButtonTitle;

/// CTA title shown on the final page. Default: "Get Started".
- (NSString *)finishButtonTitle;

/// Whether a swipe-down should dismiss (and count as finishing) the sheet.
/// Default: NO (the intro is deliberate). What's New overrides to YES.
- (BOOL)allowsInteractiveDismiss;

@end

NS_ASSUME_NONNULL_END
