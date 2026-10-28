#import <Foundation/Foundation.h>

@class SPKDownloadJob;

NS_ASSUME_NONNULL_BEGIN

@interface SPKDownloadPresenter : NSObject

@property (nonatomic, copy, nullable) void (^openHistoryForJobID)(NSString *_Nullable jobID);
@property (nonatomic, copy, nullable) void (^cancelAllActiveHandler)(void);
@property (nonatomic, copy, readonly, nullable) NSString *activeJobID;
@property (nonatomic, copy, nullable) void (^cancelHandlerForActiveJob)(NSString *jobID);

- (void)handleJobSnapshot:(SPKDownloadJob *)job;
- (void)dismissProgress;
- (void)prepareForNewJobSubmission;

- (BOOL)jobIsActive:(SPKDownloadJob *)job;
- (BOOL)hasActiveJobWithoutPillForJobID:(NSString *)jobID;
- (void)reshowPillForJob:(SPKDownloadJob *)job;

@end

NS_ASSUME_NONNULL_END
