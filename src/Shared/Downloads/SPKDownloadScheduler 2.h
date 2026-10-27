#import <Foundation/Foundation.h>

#import "SPKDownloadJob.h"
#import "SPKDownloadRequest.h"
#import "SPKDownloadTypes.h"

@class SPKDownloadPresenter;
@class SPKDownloadStore;

NS_ASSUME_NONNULL_BEGIN

@interface SPKDownloadScheduler : NSObject

@property (nonatomic, weak, nullable) SPKDownloadPresenter *presenter;
@property (nonatomic, strong) SPKDownloadStore *store;

- (NSArray<SPKDownloadJob *> *)allJobs;
- (nullable SPKDownloadJob *)jobWithID:(NSString *)jobID;

- (void)submitRequest:(SPKDownloadRequest *)request completion:(void (^_Nullable)(NSString *_Nullable jobID, NSError *_Nullable error))completion;
- (void)cancelJobID:(NSString *)jobID;
- (void)cancelItemID:(NSString *)itemID inJobID:(NSString *)jobID;
- (void)retryJobID:(NSString *)jobID;
- (void)retryItemID:(NSString *)itemID inJobID:(NSString *)jobID;
- (void)clearFinishedHistory;
- (void)refreshConcurrencyLimit;
- (void)removeJobID:(NSString *)jobID;

- (void)reportItemProgressForJobID:(NSString *)jobID
                            itemID:(NSString *)itemID
                             block:(void (^)(SPKDownloadItem *item))block;

@end

NS_ASSUME_NONNULL_END
