#import <Foundation/Foundation.h>

#import "SPKDownloadTypes.h"

NS_ASSUME_NONNULL_BEGIN

/// Keeps Instagram alive while Sparkle downloads run after the user leaves: a
/// background task first, then a silent looping audio session that mixes with
/// others and stops as soon as the queue drains or the app comes back.
@interface SPKDownloadBackgroundKeeper : NSObject

@property (class, nonatomic, readonly) SPKDownloadBackgroundKeeper *shared;

/// Called by the scheduler whenever the set of in-flight items changes.
- (void)setHasActiveWork:(BOOL)hasActiveWork;

/// Called by the scheduler as each item reaches a terminal state. Only tallied
/// while the keepalive is armed, so the finish notification reports the work the
/// user was away for and nothing else.
- (void)noteItemFinishedWithSuccess:(BOOL)success destination:(SPKDownloadDestination)destination;

/// Requested from the settings toggle, never implicitly: posting silently skips
/// itself when Instagram has no notification authorization.
+ (void)requestNotificationAuthorization;

@end

NS_ASSUME_NONNULL_END
