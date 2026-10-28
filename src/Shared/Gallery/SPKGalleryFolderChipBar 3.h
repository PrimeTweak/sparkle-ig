#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Horizontally scrolling strip of folder "chips" shown as a collection view
/// section header. Tapping a chip navigates into that folder (the host pushes a
/// child gallery); long-press surfaces an optional context menu. Visual style
/// matches the capsule chips used elsewhere in the app.
@interface SPKGalleryFolderChipBar : UICollectionReusableView

/// Preferred height for the header (use in referenceSizeForHeaderInSection).
+ (CGFloat)preferredHeight;

/// Configures the chips. `names` are the display names, `counts` the item count
/// per folder (aligned with `names`). `onSelect` fires with the tapped index;
/// `menuProvider` (optional) returns a context menu for a given index.
- (void)configureWithFolderNames:(NSArray<NSString *> *)names
                          counts:(NSArray<NSNumber *> *)counts
                        onSelect:(void (^)(NSInteger index))onSelect
                    menuProvider:(nullable UIMenu *_Nullable (^)(NSInteger index))menuProvider;

@end

NS_ASSUME_NONNULL_END
