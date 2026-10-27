#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// Cached user record (one per follower / following / visit entry).
@interface SPKProfileAnalyzerUser : NSObject <NSCopying>

@property (nonatomic, copy) NSString *pk;
@property (nonatomic, copy) NSString *username;
@property (nonatomic, copy, nullable) NSString *fullName;
@property (nonatomic, copy, nullable) NSString *profilePicURL;
// Stable IG-internal pic id; only changes when the user uploads a new photo.
@property (nonatomic, copy, nullable) NSString *profilePicID;
@property (nonatomic, assign) BOOL isPrivate;
@property (nonatomic, assign) BOOL isVerified;

// Builds a user from an IG private-API `users` array entry.
+ (nullable instancetype)userFromAPIDict:(NSDictionary *)dict;
// Builds a user from a persisted JSON dict (see -toJSONDict).
+ (nullable instancetype)userFromJSONDict:(NSDictionary *)dict;
// Builds a user from a live IGUser object via _fieldCache probing.
+ (nullable instancetype)userFromIGUserObject:(id)igUser;
- (NSDictionary *)toJSONDict;

@end

// One visited-profile entry — first/last seen + cumulative count.
@interface SPKProfileAnalyzerVisit : NSObject

@property (nonatomic, strong) SPKProfileAnalyzerUser *user;
@property (nonatomic, strong) NSDate *firstSeen;
@property (nonatomic, strong) NSDate *lastSeen;
@property (nonatomic, assign) NSInteger visitCount;

+ (nullable instancetype)visitFromJSONDict:(NSDictionary *)dict;
- (NSDictionary *)toJSONDict;

@end

// Point-in-time capture of an account's graph + self info; persisted as JSON.
@interface SPKProfileAnalyzerSnapshot : NSObject

@property (nonatomic, strong) NSDate *scanDate;
@property (nonatomic, copy) NSString *selfPK;
@property (nonatomic, copy, nullable) NSString *selfUsername;
@property (nonatomic, copy, nullable) NSString *selfFullName;
@property (nonatomic, copy, nullable) NSString *selfProfilePicURL;
@property (nonatomic, assign) NSInteger followerCount;
@property (nonatomic, assign) NSInteger followingCount;
@property (nonatomic, assign) NSInteger mediaCount;
@property (nonatomic, copy) NSArray<SPKProfileAnalyzerUser *> *followers;
@property (nonatomic, copy) NSArray<SPKProfileAnalyzerUser *> *following;

+ (nullable instancetype)snapshotFromJSONDict:(NSDictionary *)dict;
- (NSDictionary *)toJSONDict;

@end

// Per-user change between snapshots (username / fullName / pic).
@interface SPKProfileAnalyzerProfileChange : NSObject
@property (nonatomic, strong) SPKProfileAnalyzerUser *previous;
@property (nonatomic, strong) SPKProfileAnalyzerUser *current;
@property (nonatomic, readonly) BOOL usernameChanged;
@property (nonatomic, readonly) BOOL fullNameChanged;
@property (nonatomic, readonly) BOOL profilePicChanged;
@end

// Derived category arrays from (current, previous) snapshots.
@interface SPKProfileAnalyzerReport : NSObject

@property (nonatomic, strong, nullable) SPKProfileAnalyzerSnapshot *current;
@property (nonatomic, strong, nullable) SPKProfileAnalyzerSnapshot *previous;

@property (nonatomic, copy) NSArray<SPKProfileAnalyzerUser *> *mutualFollowers;
@property (nonatomic, copy) NSArray<SPKProfileAnalyzerUser *> *notFollowingYouBack;
@property (nonatomic, copy) NSArray<SPKProfileAnalyzerUser *> *youDontFollowBack;
// "recent" / "lost" — `new*` is reserved by ARC's Cocoa new-family rule.
@property (nonatomic, copy) NSArray<SPKProfileAnalyzerUser *> *recentFollowers;
@property (nonatomic, copy) NSArray<SPKProfileAnalyzerUser *> *lostFollowers;
@property (nonatomic, copy) NSArray<SPKProfileAnalyzerUser *> *youStartedFollowing;
@property (nonatomic, copy) NSArray<SPKProfileAnalyzerUser *> *youUnfollowed;
@property (nonatomic, copy) NSArray<SPKProfileAnalyzerProfileChange *> *profileUpdates;

+ (SPKProfileAnalyzerReport *)reportFromCurrent:(nullable SPKProfileAnalyzerSnapshot *)current
                                       previous:(nullable SPKProfileAnalyzerSnapshot *)previous;

@end

#pragma mark - Change log

// The five change categories that accumulate across runs. Ordering matches the
// dashboard's "Changes" section rows.
typedef NS_ENUM(NSInteger, SPKPAChangeType) {
    SPKPAChangeTypeNewFollower = 0,
    SPKPAChangeTypeLostFollower,
    SPKPAChangeTypeStartedFollowing,
    SPKPAChangeTypeUnfollowed,
    SPKPAChangeTypeProfileUpdate,
};

// One dated, durable change detected between two consecutive snapshots. Unlike
// the rotating current/previous snapshots, change events are appended to a log
// that is never clobbered, so the full history survives re-runs. Each event
// carries a `seen` flag so the UI can badge what's new since the user last
// opened the category.
@interface SPKProfileAnalyzerChangeEvent : NSObject

@property (nonatomic, assign) SPKPAChangeType type;
@property (nonatomic, strong) SPKProfileAnalyzerUser *user;                   // subject (state at detection)
@property (nonatomic, strong, nullable) SPKProfileAnalyzerUser *previousUser; // ProfileUpdate: prior state
@property (nonatomic, strong) NSDate *date;                                   // scan date it was detected
@property (nonatomic, assign) BOOL seen;

// Stable identity (type + subject pk + date) used to de-dup on import/merge.
@property (nonatomic, readonly) NSString *eventID;
// ProfileUpdate only: rebuilds a change object for the detail row's diff summary.
@property (nonatomic, readonly, nullable) SPKProfileAnalyzerProfileChange *asProfileChange;

+ (nullable instancetype)eventFromJSONDict:(NSDictionary *)dict;
- (NSDictionary *)toJSONDict;

// Mints the (unseen) events implied by a run's delta report, dated `date`.
+ (NSArray<SPKProfileAnalyzerChangeEvent *> *)eventsFromReport:(SPKProfileAnalyzerReport *)report
                                                          date:(NSDate *)date;

@end

NS_ASSUME_NONNULL_END
