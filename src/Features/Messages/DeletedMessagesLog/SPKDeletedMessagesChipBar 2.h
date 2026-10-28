#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class SPKDeletedMessagesChipBar;

@protocol SPKDeletedMessagesChipBarDelegate <NSObject>
// Fires whenever the selection changes. `selectedIndices` is the full set of
// currently-selected chip indices. An empty set means "show all".
- (void)chipBar:(SPKDeletedMessagesChipBar *)bar didChangeSelection:(NSSet<NSNumber *> *)selectedIndices;
@end

// Horizontally scrollable, multi-select chip strip. Tapping a chip toggles it;
// retapping deselects it. With nothing selected the caller shows everything,
// so there's no dedicated "All" chip — clearing the selection is "show all".
@interface SPKDeletedMessagesChipBar : UIView

@property (nonatomic, weak) id<SPKDeletedMessagesChipBarDelegate> delegate;
@property (nonatomic, copy, readonly) NSSet<NSNumber *> *selectedIndices;

- (void)setItems:(NSArray<NSString *> *)titles symbols:(nullable NSArray<NSString *> *)symbols;
// Same as above, but supplies a separate icon shown when a chip is selected
// (e.g. the filled variant). `selectedSymbols` must align with `symbols`.
- (void)setItems:(NSArray<NSString *> *)titles
            symbols:(nullable NSArray<NSString *> *)symbols
    selectedSymbols:(nullable NSArray<NSString *> *)selectedSymbols;
- (void)clearSelection;

@end

NS_ASSUME_NONNULL_END
