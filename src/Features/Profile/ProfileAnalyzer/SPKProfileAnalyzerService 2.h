#import "SPKProfileAnalyzerModels.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, SPKProfileAnalyzerError) {
    SPKProfileAnalyzerErrorNoSession = 1,
    SPKProfileAnalyzerErrorTooManyFollowers,
    SPKProfileAnalyzerErrorNetwork,
    SPKProfileAnalyzerErrorCancelled,
    SPKProfileAnalyzerErrorAlreadyRunning,
};

// Hard cap — refuse to run beyond this connection count to dodge IG rate limits.
extern const NSInteger SPKProfileAnalyzerMaxConnectionCount;

// Posted (main queue) whenever scan progress changes, and on start/finish.
// userInfo: @"fraction" (NSNumber 0–1), @"status" (NSString), @"running" (NSNumber).
// Lets observers (e.g. the dashboard) restore progress UI without owning the run.
extern NSNotificationName const SPKProfileAnalyzerProgressDidChangeNotification;

typedef void (^SPKPAProgress)(NSString *status, double fraction);
typedef void (^SPKPACompletion)(SPKProfileAnalyzerSnapshot *_Nullable snapshot, NSError *_Nullable error);
// Fires once after the self-user-info call so the header can paint immediately.
typedef void (^SPKPAHeaderInfo)(NSDictionary *userInfo);

// Singleton that runs a full followers + following scan for the logged-in
// account. The run is independent of any view controller's lifetime — starting
// a scan and leaving the screen does NOT cancel it. Progress/result are surfaced
// to callers via the blocks below (all delivered on the main queue).
@interface SPKProfileAnalyzerService : NSObject

@property (nonatomic, readonly) BOOL isRunning;
// Snapshot of the last reported progress (0–1) and status, for late observers
// (e.g. a VC that re-appears mid-scan).
@property (nonatomic, readonly) double currentFraction;
@property (nonatomic, readonly, copy, nullable) NSString *currentStatus;

+ (instancetype)sharedService;

- (void)runForSelfWithHeaderInfo:(nullable SPKPAHeaderInfo)headerInfo
                        progress:(nullable SPKPAProgress)progress
                      completion:(nullable SPKPACompletion)completion;
- (void)cancel;

@end

NS_ASSUME_NONNULL_END
