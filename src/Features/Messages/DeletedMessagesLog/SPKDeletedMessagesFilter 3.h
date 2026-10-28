#import "SPKDeletedMessagesModels.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, SPKDMDateRange) {
    SPKDMDateRangeAll = 0,
    SPKDMDateRangeToday,
    SPKDMDateRangeWeek,
    SPKDMDateRangeMonth,
    SPKDMDateRangeCustom,
};

typedef NS_ENUM(NSInteger, SPKDMSort) {
    SPKDMSortRecent = 0, // newest deleted first
    SPKDMSortOldest,
    SPKDMSortCountDesc, // groups only
};

// Filter spec shared between the top VC and the per-user detail VC.
@interface SPKDeletedMessagesFilter : NSObject <NSCopying>

@property (nonatomic, copy, nullable) NSString *searchText;
// Set of NSNumber-wrapped SPKDeletedMessageKind. Empty = match all kinds.
@property (nonatomic, strong) NSMutableSet<NSNumber *> *kinds;
@property (nonatomic, assign) SPKDMDateRange dateRange;
@property (nonatomic, strong, nullable) NSDate *customStart;
@property (nonatomic, strong, nullable) NSDate *customEnd;
@property (nonatomic, assign) SPKDMSort sort;

- (BOOL)isEmpty;
- (BOOL)hasKindFilter; // YES when at least one kind is selected
- (BOOL)matchesKind:(SPKDeletedMessageKind)kind;
- (void)toggleKind:(SPKDeletedMessageKind)kind;
- (void)clearKinds;

- (NSArray<SPKDeletedMessage *> *)apply:(NSArray<SPKDeletedMessage *> *)messages;
- (NSArray<SPKDeletedMessageGroup *> *)applyToGroups:(NSArray<SPKDeletedMessageGroup *> *)groups;

@end

NS_ASSUME_NONNULL_END
