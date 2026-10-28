#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class SPKMediaItem;

NS_ASSUME_NONNULL_BEGIN

@interface SPKMediaCacheManager : NSObject

+ (instancetype)sharedManager;

- (nullable NSURL *)bestAvailableFileURLForItem:(SPKMediaItem *)item;
- (nullable NSURL *)cachedFileURLForRemoteURL:(NSURL *)url;

- (void)fetchLocalFileURLForItem:(SPKMediaItem *)item
                      completion:(void (^)(NSURL *_Nullable localURL, NSError *_Nullable error))completion;

- (void)loadImageForItem:(SPKMediaItem *)item
              completion:(void (^)(UIImage *_Nullable image, NSError *_Nullable error))completion;

- (void)loadThumbnailForVideoItem:(SPKMediaItem *)item
                       completion:(void (^)(UIImage *_Nullable image))completion;

- (void)prefetchItem:(SPKMediaItem *)item;

@end

NS_ASSUME_NONNULL_END
