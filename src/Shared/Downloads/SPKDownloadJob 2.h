#import <Foundation/Foundation.h>

#import "SPKDownloadItem.h"
#import "SPKDownloadRequest.h"
#import "SPKDownloadTypes.h"

NS_ASSUME_NONNULL_BEGIN

@interface SPKDownloadJob : NSObject <NSCopying>
@property (nonatomic, copy) NSString *jobID;
@property (nonatomic, assign) NSTimeInterval createdAt;
@property (nonatomic, assign) NSTimeInterval updatedAt;
@property (nonatomic, assign) SPKDownloadState state;
@property (nonatomic, assign) double aggregateProgress;
@property (nonatomic, copy, nullable) NSString *title;
@property (nonatomic, copy, nullable) NSString *detail;
@property (nonatomic, strong, readonly) SPKDownloadRequest *request;
@property (nonatomic, copy, readonly) NSArray<SPKDownloadItem *> *items;
/// Mutable backing store; scheduler/store use this for in-place updates.
@property (nonatomic, strong, readonly) NSMutableArray<SPKDownloadItem *> *mutableItems;
@property (nonatomic, copy, nullable) NSString *completionAction;
/// Account that initiated the download (stamped at creation). nil = legacy /
/// pre-feature. Drives the per-account Download History filter.
@property (nonatomic, copy, nullable) NSString *ownerAccountPK;

- (instancetype)initWithRequest:(SPKDownloadRequest *)request jobID:(NSString *)jobID;
- (void)recomputeDerivedState;
- (void)markActiveItemsInterrupted;
- (void)replaceItems:(NSArray<SPKDownloadItem *> *)items;
- (nullable SPKDownloadItem *)itemWithIdentifier:(NSString *)itemID;
- (NSDictionary *)dictionaryRepresentation;
+ (nullable instancetype)fromDictionary:(NSDictionary *)dict;
@end

NS_ASSUME_NONNULL_END
