#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "../MediaPreview/SPKFullScreenMediaPlayer.h"
#import "SPKAudioItem.h"

@class SPKGallerySaveMetadata;

NS_ASSUME_NONNULL_BEGIN

@interface SPKAudioDownloadCoordinator : NSObject

+ (void)performAction:(SPKAudioAction)action
                      item:(SPKAudioItem *)item
                 presenter:(nullable UIViewController *)presenter
                sourceView:(nullable UIView *)sourceView
                  metadata:(nullable SPKGallerySaveMetadata *)metadata
    notificationIdentifier:(nullable NSString *)notificationIdentifier;

+ (void)performAction:(SPKAudioAction)action
                      item:(SPKAudioItem *)item
                 presenter:(nullable UIViewController *)presenter
                sourceView:(nullable UIView *)sourceView
                  metadata:(nullable SPKGallerySaveMetadata *)metadata
    notificationIdentifier:(nullable NSString *)notificationIdentifier
            playbackSource:(SPKFullScreenPlaybackSource)playbackSource
             pausePlayback:(nullable SPKMediaPreviewPlaybackBlock)pausePlayback
            resumePlayback:(nullable SPKMediaPreviewPlaybackBlock)resumePlayback;

+ (nullable SPKAudioItem *)audioItemFromMediaObject:(nullable id)mediaObject
                                             source:(SPKAudioSource)source;

+ (nullable SPKAudioItem *)audioItemFromMediaObject:(nullable id)mediaObject
                                             source:(SPKAudioSource)source
                                 allowVideoFallback:(BOOL)allowVideoFallback;

+ (nullable NSURL *)bestAudioURLFromMediaObject:(nullable id)mediaObject;

+ (nullable NSURL *)bestAudioDownloadURLFromMediaObject:(nullable id)mediaObject;

+ (NSString *)processingBasenameForAudioItem:(SPKAudioItem *)item;
+ (void)convertAudioAtURL:(NSURL *)sourceURL
                 basename:(NSString *)basename
                 progress:(void (^)(float progress, NSString *_Nullable title))progress
               completion:(void (^)(NSURL *_Nullable outputURL, NSError *_Nullable error))completion;

@end

NS_ASSUME_NONNULL_END
