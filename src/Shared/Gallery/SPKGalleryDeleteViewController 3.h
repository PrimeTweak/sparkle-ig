#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, SPKGalleryDeletePageMode) {
    SPKGalleryDeletePageModeRoot = 0,
    SPKGalleryDeletePageModeUsers
};

@interface SPKGalleryDeleteViewController : UITableViewController

@property (nonatomic, copy, nullable) void (^onDidDelete)(void);

- (instancetype)initWithMode:(SPKGalleryDeletePageMode)mode;

@end

NS_ASSUME_NONNULL_END
