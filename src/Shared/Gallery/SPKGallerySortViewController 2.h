#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, SPKGallerySortMode) {
    SPKGallerySortModeDateAddedDesc = 0, // Newest first (default)
    SPKGallerySortModeDateAddedAsc,      // Oldest first
    SPKGallerySortModeNameAsc,           // A→Z
    SPKGallerySortModeNameDesc,          // Z→A
    SPKGallerySortModeSizeDesc,          // Largest first
    SPKGallerySortModeSizeAsc,           // Smallest first
    SPKGallerySortModeTypeAsc,           // Legacy: grouped by media type
    SPKGallerySortModeTypeDesc,          // Legacy: grouped by media type
};

@class SPKGallerySortViewController;

@protocol SPKGallerySortViewControllerDelegate <NSObject>
- (void)sortController:(SPKGallerySortViewController *)controller didSelectSortMode:(SPKGallerySortMode)mode groupByMediaType:(BOOL)groupByMediaType;
@end

@interface SPKGallerySortViewController : UIViewController

@property (nonatomic, weak) id<SPKGallerySortViewControllerDelegate> delegate;
@property (nonatomic, assign) SPKGallerySortMode currentSortMode;
@property (nonatomic, assign) BOOL currentGroupByMediaType;

/// The height the content needs at the given width (excluding the nav bar and
/// bottom safe area), so the presenter can size a single fixed sheet detent to it
/// once — no layout-time detent invalidation (which deadlocks iOS 26).
- (CGFloat)spkContentHeightForWidth:(CGFloat)width;

+ (NSArray<NSSortDescriptor *> *)sortDescriptorsForMode:(SPKGallerySortMode)mode;
+ (NSArray<NSSortDescriptor *> *)sortDescriptorsForMode:(SPKGallerySortMode)mode groupByMediaType:(BOOL)groupByMediaType;
+ (NSString *)labelForMode:(SPKGallerySortMode)mode;

@end

NS_ASSUME_NONNULL_END
