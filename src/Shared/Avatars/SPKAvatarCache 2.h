#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

// App-wide, two-tier profile-picture cache shared across every Sparkle surface
// (Profile Analyzer lists, Deleted Messages, ...). A user's avatar is the same
// regardless of where it's shown, so a single store is keyed by user PK.
//
// • In-memory NSCache keyed by PK for instant cell reuse.
// • On-disk store under Documents/Sparkle/Avatars/, keyed by PK, refreshed at
//   most once per TTL window (default 24h) so we never hammer the CDN on every
//   scroll. A stale-but-present blob is served immediately while a refresh runs
//   in the background.
//
// All callbacks are delivered on the main queue.
@interface SPKAvatarCache : NSObject

+ (instancetype)shared;

// Returns an in-memory image immediately when warm, otherwise nil.
- (nullable UIImage *)cachedImageForPK:(NSString *)pk;

// Resolves an avatar for `pk`, loading from disk / network as needed. The
// completion fires with the best available image (may be nil). `urlString` is
// the last-known profile-pic URL; it is only hit when the on-disk copy is
// missing or older than the TTL.
- (void)avatarForPK:(NSString *)pk
          urlString:(nullable NSString *)urlString
         completion:(nullable void (^)(UIImage *_Nullable image))completion;

// As above, but when `forceRefresh` is YES the TTL/disk short-circuit is
// bypassed and the network is always hit (used by manual retry). On success the
// memory + disk copies are replaced and the completion fires with the fresh
// image; on failure the completion is not called with a fallback.
- (void)avatarForPK:(NSString *)pk
          urlString:(nullable NSString *)urlString
       forceRefresh:(BOOL)forceRefresh
         completion:(nullable void (^)(UIImage *_Nullable image))completion;

// Drops a single PK from the memory cache and deletes its disk JPEG so the next
// fetch re-downloads. Used by per-avatar tap-to-retry.
- (void)invalidatePK:(NSString *)pk;

// Drops all cached avatars (memory + disk).
- (void)purge;

// Total size (bytes) of the on-disk avatar cache — surfaced in Storage.
- (unsigned long long)diskSizeBytes;

@end

NS_ASSUME_NONNULL_END
