#import "SPKDownloadStore.h"

#import "../SPKStoragePaths.h"
#import "SPKDownloadJob.h"
#import "SPKDownloadTypes.h"

@interface SPKDownloadStore ()
@property (nonatomic, strong, nullable) NSTimer *debounceTimer;
@property (nonatomic, copy, nullable) NSArray<SPKDownloadJob *> *pendingJobs;
@end

@implementation SPKDownloadStore

+ (NSString *)v2RootDirectory {
    return [[SPKStoragePaths downloadsDirectory] stringByAppendingPathComponent:@"v2"];
}

+ (NSString *)historyFilePath {
    return [[self v2RootDirectory] stringByAppendingPathComponent:@"history.json"];
}

+ (NSString *)stagingRootDirectory {
    return [[self v2RootDirectory] stringByAppendingPathComponent:@"staging"];
}

+ (NSString *)stagingDirectoryForJobID:(NSString *)jobID {
    return [[self stagingRootDirectory] stringByAppendingPathComponent:jobID ?: @"unknown"];
}

+ (NSString *)sourcesRootDirectory {
    return [[self v2RootDirectory] stringByAppendingPathComponent:@"sources"];
}

+ (NSString *)previewsRootDirectory {
    return [[self v2RootDirectory] stringByAppendingPathComponent:@"previews"];
}

+ (unsigned long long)purgeTransientCacheKeepingJobIDs:(NSSet<NSString *> *)keepJobIDs
                                           sourcePaths:(NSSet<NSString *> *)keepSourcePaths {
    NSFileManager *fm = NSFileManager.defaultManager;
    unsigned long long freed = 0;

    // staging/<jobID> — a whole directory per download; keep listed/in-flight jobs.
    NSString *staging = [self stagingRootDirectory];
    for (NSString *entry in [fm contentsOfDirectoryAtPath:staging error:nil]) {
        if ([keepJobIDs containsObject:entry])
            continue;
        NSString *path = [staging stringByAppendingPathComponent:entry];
        freed += [SPKStoragePaths sizeOfDirectory:path];
        [fm removeItemAtPath:path error:nil];
    }

    // sources/<uuid>.<ext> — staged input files; keep any a live job points at.
    NSString *sources = [self sourcesRootDirectory];
    for (NSString *entry in [fm contentsOfDirectoryAtPath:sources error:nil]) {
        NSString *path = [sources stringByAppendingPathComponent:entry];
        if ([keepSourcePaths containsObject:path])
            continue;
        NSDictionary *attrs = [fm attributesOfItemAtPath:path error:nil];
        freed += [attrs[NSFileSize] unsignedLongLongValue];
        [fm removeItemAtPath:path error:nil];
    }

    // previews/ — regenerable scratch, never referenced after use.
    NSString *previews = [self previewsRootDirectory];
    for (NSString *entry in [fm contentsOfDirectoryAtPath:previews error:nil]) {
        NSString *path = [previews stringByAppendingPathComponent:entry];
        NSDictionary *attrs = [fm attributesOfItemAtPath:path error:nil];
        if ([attrs[NSFileType] isEqual:NSFileTypeDirectory])
            freed += [SPKStoragePaths sizeOfDirectory:path];
        else
            freed += [attrs[NSFileSize] unsignedLongLongValue];
        [fm removeItemAtPath:path error:nil];
    }

    return freed;
}

- (void)ensureDirectories {
    NSFileManager *fm = NSFileManager.defaultManager;
    NSArray *paths = @[
        [SPKDownloadStore v2RootDirectory],
        [[SPKDownloadStore v2RootDirectory] stringByAppendingPathComponent:@"staging"],
        [[SPKDownloadStore v2RootDirectory] stringByAppendingPathComponent:@"sources"],
        [[SPKDownloadStore v2RootDirectory] stringByAppendingPathComponent:@"previews"],
    ];
    for (NSString *path in paths) {
        [fm createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    }
}

- (NSArray<SPKDownloadJob *> *)loadJobsMarkingInterrupted:(BOOL)markInterrupted {
    [self ensureDirectories];
    NSData *data = [NSData dataWithContentsOfFile:[SPKDownloadStore historyFilePath]];
    if (data.length == 0)
        return @[];
    NSDictionary *root = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if (![root isKindOfClass:NSDictionary.class])
        return @[];
    if ([root[@"schemaVersion"] integerValue] != SPKDownloadStoreSchemaVersion)
        return @[];
    NSMutableArray<SPKDownloadJob *> *jobs = [NSMutableArray array];
    for (NSDictionary *entry in root[@"jobs"] ?: @[]) {
        SPKDownloadJob *job = [SPKDownloadJob fromDictionary:entry];
        if (!job)
            continue;
        if (markInterrupted) {
            [job markActiveItemsInterrupted];
        }
        [jobs addObject:job];
    }
    return jobs;
}

- (void)replaceJobs:(NSArray<SPKDownloadJob *> *)jobs {
    [self persistJobs:jobs immediately:YES];
}

- (void)persistJobs:(NSArray<SPKDownloadJob *> *)jobs immediately:(BOOL)immediately {
    (void)immediately;
    [self ensureDirectories];
    NSMutableArray *serialized = [NSMutableArray array];
    for (SPKDownloadJob *job in jobs) {
        [serialized addObject:[job dictionaryRepresentation]];
    }
    NSDictionary *root = @{
        @"schemaVersion" : @(SPKDownloadStoreSchemaVersion),
        @"jobs" : serialized,
    };
    NSData *data = [NSJSONSerialization dataWithJSONObject:root options:NSJSONWritingPrettyPrinted error:nil];
    if (!data)
        return;
    NSString *path = [SPKDownloadStore historyFilePath];
    NSString *tmp = [path stringByAppendingString:@".tmp"];
    if ([data writeToFile:tmp atomically:YES]) {
        [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
        [[NSFileManager defaultManager] moveItemAtPath:tmp toPath:path error:nil];
    }
}

- (void)debouncedPersistJobs:(NSArray<SPKDownloadJob *> *)jobs {
    self.pendingJobs = jobs;
    [self.debounceTimer invalidate];
    __weak typeof(self) weakSelf = self;
    self.debounceTimer = [NSTimer scheduledTimerWithTimeInterval:0.35
                                                         repeats:NO
                                                           block:^(NSTimer *timer) {
                                                               (void)timer;
                                                               __strong typeof(weakSelf) strongSelf = weakSelf;
                                                               if (!strongSelf.pendingJobs)
                                                                   return;
                                                               [strongSelf persistJobs:strongSelf.pendingJobs immediately:YES];
                                                               strongSelf.pendingJobs = nil;
                                                           }];
}

@end
