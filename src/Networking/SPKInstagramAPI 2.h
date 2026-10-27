// Reusable wrapper for Instagram private API calls.

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^SPKAPICompletion)(NSDictionary *_Nullable response, NSError *_Nullable error);
typedef void (^SPKAPIStatusesCompletion)(NSDictionary *_Nullable statuses, NSError *_Nullable error);

@interface SPKInstagramAPI : NSObject

// `path` is the part after /api/v1/, e.g. "friendships/show/123/".
// `body` is form-encoded if non-nil. `completion` runs on the main queue.
+ (void)sendRequestWithMethod:(NSString *)method
                         path:(NSString *)path
                         body:(nullable NSDictionary *)body
                   completion:(nullable SPKAPICompletion)completion;

+ (void)followUserPK:(NSString *)pk completion:(nullable SPKAPICompletion)completion;
+ (void)unfollowUserPK:(NSString *)pk completion:(nullable SPKAPICompletion)completion;

+ (void)fetchFriendshipStatusesForPKs:(NSArray<NSString *> *)pks
                           completion:(nullable SPKAPIStatusesCompletion)completion;

// Resolves the current (short-lived) profile-pic CDN URL for a user PK via
// users/<pk>/info/. `completion` runs on the main queue; url is nil on failure.
+ (void)resolveProfilePicURLForPK:(NSString *)pk
                       completion:(void (^)(NSString *_Nullable url, NSError *_Nullable error))completion;

+ (void)fetchWebMediaInfoForPK:(NSString *)mediaPK
                    completion:(nullable SPKAPICompletion)completion;

+ (void)resolveUserForUsername:(NSString *)username
                    completion:(void (^)(NSDictionary *_Nullable userDict, NSError *_Nullable error))completion;

@end

NS_ASSUME_NONNULL_END
