#import "SPKProfileAnalyzerModels.h"
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, SPKPAListKind) {
    SPKPAListKindPlain,         // no action button (e.g. lost followers)
    SPKPAListKindUnfollow,      // you follow them — show Unfollow
    SPKPAListKindFollow,        // you don't follow them — show Follow
    SPKPAListKindProfileUpdate, // previous → current change rows
    SPKPAListKindVisited,       // visited-profiles tracker — last-seen subtitle
};

@interface SPKProfileAnalyzerListViewController : UIViewController

- (instancetype)initWithTitle:(NSString *)title
                        users:(NSArray<SPKProfileAnalyzerUser *> *)users
                         kind:(SPKPAListKind)kind;

- (instancetype)initWithTitle:(NSString *)title
               profileUpdates:(NSArray<SPKProfileAnalyzerProfileChange *> *)updates;

// Grouped variants — split a change category into "Latest" (unseen) above
// "Previous" (seen). Empty groups are omitted.
- (instancetype)initWithTitle:(NSString *)title
                  latestUsers:(NSArray<SPKProfileAnalyzerUser *> *)latestUsers
                previousUsers:(NSArray<SPKProfileAnalyzerUser *> *)previousUsers
                         kind:(SPKPAListKind)kind;

- (instancetype)initWithTitle:(NSString *)title
         latestProfileUpdates:(NSArray<SPKProfileAnalyzerProfileChange *> *)latestUpdates
       previousProfileUpdates:(NSArray<SPKProfileAnalyzerProfileChange *> *)previousUpdates;

- (instancetype)initVisitedListWithTitle:(NSString *)title
                                  visits:(NSArray<SPKProfileAnalyzerVisit *> *)visits;

// Visited-list only: invoked when the user swipes to remove a visit, so the
// owner can persist the deletion. Optional.
@property (nonatomic, copy, nullable) void (^onRemoveVisit)(SPKProfileAnalyzerVisit *visit);

// Visited-list only: invoked when the user clears the whole history from the ⋯
// menu, so the owner can wipe stored visits. Optional.
@property (nonatomic, copy, nullable) void (^onClearHistory)(void);

// Change lists: setting this enables swipe-to-delete on the rows, and hands back the
// item the user removed (a `SPKProfileAnalyzerUser`, or a
// `SPKProfileAnalyzerProfileChange` for Profile Updates) so the owner can drop the
// matching event from the durable change log. Setting it is what turns the swipe on,
// so a list whose owner cannot persist a deletion never offers one. Optional.
@property (nonatomic, copy, nullable) void (^onRemoveEntry)(id item);

@end

NS_ASSUME_NONNULL_END
