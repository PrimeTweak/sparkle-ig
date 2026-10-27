#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Title/author for a Giphy GIF, resolved from its `gifMediaId`.
@interface SPKGiphyMetadata : NSObject

/// Human-readable GIF name, with Giphy's "- Find & Share on GIPHY" suffix and
/// the redundant trailing "GIF by <author>" stripped. Never empty.
@property (nonatomic, copy, readonly) NSString *title;
/// Uploading channel, when Giphy reports one.
@property (nonatomic, copy, readonly, nullable) NSString *author;

/// For callers that already hold the title locally and never need a lookup —
/// Direct GIFs carry both fields on `IGGiphyGIFModel`. Returns nil for an empty
/// title.
+ (nullable instancetype)metadataWithTitle:(NSString *)title author:(nullable NSString *)author;

@end

/// Resolves Giphy metadata over Giphy's public oEmbed endpoint (no API key).
///
/// Lookups are on-demand only: nothing here should be called while merely
/// rendering a GIF, since every miss is a request to giphy.com that leaks which
/// GIFs the user is looking at. Callers gate on an explicit user action.
@interface SPKGiphyMetadataResolver : NSObject

/// Cached result, or nil if this id has not been resolved yet. Non-blocking.
+ (nullable SPKGiphyMetadata *)cachedMetadataForGifMediaId:(NSString *)gifMediaId;

/// Resolves `gifMediaId`, serving the cache when warm. Concurrent requests for
/// the same id are coalesced into one network call. `completion` is always
/// invoked, on the main thread, with nil on any failure.
+ (void)resolveMetadataForGifMediaId:(NSString *)gifMediaId
                          completion:(void (^)(SPKGiphyMetadata *_Nullable metadata))completion;

@end

NS_ASSUME_NONNULL_END
