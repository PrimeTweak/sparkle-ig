#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class SPKChipBar;

@protocol SPKChipBarDelegate <NSObject>
@optional
// Fires whenever the selection changes. `selectedIndices` is the full set of
// currently-selected chip indices (useful when multiSelect is YES).
- (void)chipBar:(SPKChipBar *)bar didChangeSelection:(NSSet<NSNumber *> *)selectedIndices;

// Fires when a specific index is selected (useful when multiSelect is NO).
- (void)chipBar:(SPKChipBar *)bar didSelectIndex:(NSInteger)index;
@end

// Horizontally scrollable, customizable chip strip. Supports both multi-select
// and single-select modes. Tapping a selected chip in single-select mode maintains
// selection (similar to a segmented control).
@interface SPKChipBar : UIView

@property (nonatomic, weak, nullable) id<SPKChipBarDelegate> delegate;

// If YES, allows multiple selections. If NO, acts as a segmented control. Default: NO.
@property (nonatomic, assign) BOOL multiSelect;

// If YES, scrolling is disabled and the chips are distributed to fill the bar's
// width equally (a segmented-control-style row) using a slightly smaller font so
// they never get clipped on narrow screens. If NO (default), the bar scrolls
// horizontally with intrinsically-sized chips. Set before `setItems:`.
@property (nonatomic, assign) BOOL distributesToFit;

// If YES, scrolling is disabled and the chips fill the bar's width sized
// *proportionally* to their content — so a longer label gets a wider chip and
// the labels keep their full font (no per-chip shrink). Use this instead of
// `distributesToFit` when the labels differ a lot in length. Mutually exclusive
// with `distributesToFit`. Set before `setItems:`.
@property (nonatomic, assign) BOOL distributesProportionally;

// The currently selected index (for single-select mode). Default: 0.
@property (nonatomic, assign) NSInteger selectedIndex;

// The set of currently selected indices (for multi-select mode).
@property (nonatomic, copy) NSSet<NSNumber *> *selectedIndices;

// Configures titles and optional icons for each chip.
- (void)setItems:(NSArray<NSString *> *)titles symbols:(nullable NSArray<NSString *> *)symbols;

// Configures titles, icons, and specific selected-state icons for each chip.
- (void)setItems:(NSArray<NSString *> *)titles
            symbols:(nullable NSArray<NSString *> *)symbols
    selectedSymbols:(nullable NSArray<NSString *> *)selectedSymbols;

// Clears all selection.
- (void)clearSelection;

@end

NS_ASSUME_NONNULL_END
