#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// One viewer of a story. Field names deliberately mirror the future Core Data
// `SPKStoryViewer` entity so the ephemeral fetch-and-search feature can be
// upgraded to a persistent archive by making this an NSManagedObject with the
// same keys.
//
// `following` / `followedBy` reflect the friendship state at fetch time (they
// come straight from the viewer response when present, or a batched
// friendships/show_many backfill otherwise). `NSNotFound`-style unknowns are
// represented by the *Known flags being NO.
@interface SPKStoryViewerModel : NSObject
@property (nonatomic, copy, nullable) NSString *pk;
@property (nonatomic, copy, nullable) NSString *username;
@property (nonatomic, copy, nullable) NSString *fullName;
@property (nonatomic, copy, nullable) NSString *profilePicURL;
@property (nonatomic, assign) BOOL isVerified;
@property (nonatomic, assign) BOOL following;       // you follow them
@property (nonatomic, assign) BOOL followedBy;      // they follow you
@property (nonatomic, assign) BOOL friendshipKnown; // is following/followedBy populated?
@property (nonatomic, assign) BOOL liked;           // they liked the story (when known)
@property (nonatomic, strong, nullable) NSDate *addedDate;
@end

// Drives Instagram's private `list_reel_media_viewer` REST endpoint to
// completion for a single story media id, accumulating the full viewer list
// client-side. This is NOT the (server-locked) Instagram Plus GraphQL viewer
// search — it is the same endpoint IG's own viewer list uses, so it returns the
// complete list for your own story and works identically on IG 410 and latest.
@interface SPKStoryViewersFetcher : NSObject

// Fetches every viewer for `mediaID` (the numeric media pk, no `_userid`
// suffix). `progress` fires on the main queue after each page with the running
// count. `completion` fires once on the main queue with the full list (sorted
// newest-first, as returned) and the server's reported total; `error` is set if
// the first page failed. Friendship state is backfilled if the response omits
// it. Returns a token; call `-cancel` to stop paging (completion won't fire).
+ (instancetype)fetchAllViewersForMediaID:(NSString *)mediaID
                                 progress:(nullable void (^)(NSInteger fetched))progress
                               completion:(void (^)(NSArray<SPKStoryViewerModel *> *viewers,
                                                    NSInteger totalCount,
                                                    NSError *_Nullable error))completion;

- (void)cancel;

@end

NS_ASSUME_NONNULL_END
