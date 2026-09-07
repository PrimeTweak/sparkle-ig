#import <Foundation/Foundation.h>

@class SPKDownloadJob;

NS_ASSUME_NONNULL_BEGIN

@interface SPKDownloadStore : NSObject

+ (NSString *)v2RootDirectory;
+ (NSString *)historyFilePath;
+ (NSString *)stagingDirectoryForJobID:(NSString *)jobID;

/// Deletes the transient download cache — leftover staged media (full copies
/// each download leaves behind after being exported), staged source files, and
/// preview scratch. Staging directories keyed by `keepJobIDs` and source files
/// in `keepSourcePaths` are preserved (they still back a history entry or an
/// in-flight download). Returns bytes freed.
+ (unsigned long long)purgeTransientCacheKeepingJobIDs:(nullable NSSet<NSString *> *)keepJobIDs
                                           sourcePaths:(nullable NSSet<NSString *> *)keepSourcePaths;

- (NSArray<SPKDownloadJob *> *)loadJobsMarkingInterrupted:(BOOL)markInterrupted;
- (void)replaceJobs:(NSArray<SPKDownloadJob *> *)jobs;
- (void)persistJobs:(NSArray<SPKDownloadJob *> *)jobs immediately:(BOOL)immediately;
- (void)debouncedPersistJobs:(NSArray<SPKDownloadJob *> *)jobs;
- (void)ensureDirectories;

@end

NS_ASSUME_NONNULL_END
