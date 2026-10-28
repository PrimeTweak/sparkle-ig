#import "SPKProfileAnalyzerModels.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// Posted on every save/update/reset. userInfo carries @"user_pk" (the account
// the data belongs to), or an empty dict for whole-store resets.
extern NSNotificationName const SPKProfileAnalyzerDataDidChangeNotification;

// Per-account on-disk store under
//   Documents/Sparkle/ProfileAnalyzer/
// Layout (one set of files per account PK):
//   <pk>.current.json   — latest snapshot
//   <pk>.previous.json  — snapshot before the latest (for delta computation)
//   <pk>.baseline.json  — optional user-pinned reference snapshot
//   <pk>.header.json    — cached self-profile header info
//   <pk>.visits.json    — visited-profiles log (newest-first)
//   <pk>.changelog.json — durable follower/following change log (newest-first)
@interface SPKProfileAnalyzerStorage : NSObject

#pragma mark - Snapshots

+ (nullable SPKProfileAnalyzerSnapshot *)currentSnapshotForUserPK:(NSString *)userPK;
+ (nullable SPKProfileAnalyzerSnapshot *)previousSnapshotForUserPK:(NSString *)userPK;
+ (nullable SPKProfileAnalyzerSnapshot *)baselineSnapshotForUserPK:(NSString *)userPK;
+ (BOOL)saveBaselineSnapshot:(SPKProfileAnalyzerSnapshot *)snapshot forUserPK:(NSString *)userPK;
+ (void)clearBaselineForUserPK:(NSString *)userPK;

// Rotates current -> previous, then writes the new current.
+ (BOOL)saveSnapshot:(SPKProfileAnalyzerSnapshot *)snapshot forUserPK:(NSString *)userPK;
// Overwrites current without rotating — used for in-app follow/unfollow mutations.
+ (BOOL)updateCurrentSnapshot:(SPKProfileAnalyzerSnapshot *)snapshot forUserPK:(NSString *)userPK;

+ (void)resetForUserPK:(NSString *)userPK;
+ (void)resetAll;

#pragma mark - Change log

// All change events for an account, newest-first.
+ (NSArray<SPKProfileAnalyzerChangeEvent *> *)changeEventsForUserPK:(NSString *)userPK;
// Appends newly-detected events (dedup by eventID), caps the log, persists.
+ (void)appendChangeEvents:(NSArray<SPKProfileAnalyzerChangeEvent *> *)events forUserPK:(NSString *)userPK;
// Unseen event count per type: @{ @(SPKPAChangeType): @(count) }. Single read.
+ (NSDictionary<NSNumber *, NSNumber *> *)unseenChangeCountsForUserPK:(NSString *)userPK;
// Marks every event of `type` as seen (clears that category's badge).
+ (void)markChangeEventsSeenForType:(SPKPAChangeType)type forUserPK:(NSString *)userPK;
// Drops individual logged events (identified by `eventID`) — the swipe-to-delete path
// in the change lists. A deleted event is not re-detected by a later scan (the delta is
// computed against the rotated snapshot, which already contains the change), but
// importing a backup that still holds it will bring it back.
+ (void)removeChangeEventsWithIDs:(NSArray<NSString *> *)eventIDs forUserPK:(NSString *)userPK;
+ (void)clearChangeLogForUserPK:(NSString *)userPK;

#pragma mark - Header cache

+ (nullable NSDictionary *)headerInfoForUserPK:(NSString *)userPK;
+ (void)saveHeaderInfo:(NSDictionary *)info forUserPK:(NSString *)userPK;

#pragma mark - Visited profiles

+ (NSArray<SPKProfileAnalyzerVisit *> *)visitedProfilesForUserPK:(NSString *)userPK;
+ (void)recordVisitForUser:(SPKProfileAnalyzerUser *)user forUserPK:(NSString *)userPK;
+ (void)removeVisitForUserPK:(NSString *)userPK visitedPK:(NSString *)visitedPK;
+ (void)clearVisitsForUserPK:(NSString *)userPK;
// Refresh metadata for an existing visit without bumping last_seen / visit_count.
+ (void)refreshVisitedUser:(SPKProfileAnalyzerUser *)user forUserPK:(NSString *)userPK;

#pragma mark - Maintenance / backup

// Absolute path to the storage root. Used by backup/restore + storage stats.
+ (NSString *)storageRootPath;
// Total bytes on disk for one account (snapshots + visits + header).
+ (unsigned long long)storageSizeBytesForUserPK:(NSString *)userPK;
// Replace the entire store directory with the contents at sourcePath (import).
+ (BOOL)replaceStorageWithDirectoryAtPath:(NSString *)sourcePath error:(NSError **)error;

// Non-destructive import: per account, the visited-profiles log is unioned (dedup by
// visited pk, existing entries kept), and the snapshots (current/previous/baseline/
// header) are adopted ONLY for accounts with no local snapshot — never overwriting
// existing analysis or a pinned baseline. When `ownerFilterPK` is non-nil, only that
// account is merged. Returns the number of visits added, or -1 on a hard failure.
+ (NSInteger)mergeFromStorageDirectory:(NSString *)sourcePath
                         ownerFilterPK:(nullable NSString *)ownerFilterPK
                                 error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
