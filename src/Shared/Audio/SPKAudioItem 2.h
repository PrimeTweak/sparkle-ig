#import <Foundation/Foundation.h>

#import "../Gallery/SPKGalleryFile.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, SPKAudioSource) {
    SPKAudioSourceAudioPage = 1,
    SPKAudioSourceFeed,
    SPKAudioSourceReels,
    SPKAudioSourceStories,
    SPKAudioSourceDMs,
    SPKAudioSourceDMNotes,
    SPKAudioSourceOther
};

typedef NS_ENUM(NSInteger, SPKAudioAction) {
    SPKAudioActionShare = 1,
    SPKAudioActionSaveToGallery,
    SPKAudioActionSaveToFiles,
    SPKAudioActionCopyURL,
    SPKAudioActionPlay,
    SPKAudioActionConvertAndShare,
    SPKAudioActionConvertAndSaveToGallery
};

@interface SPKAudioItem : NSObject <NSCopying>

@property (nonatomic, strong, nullable) NSURL *url;
@property (nonatomic, copy, nullable) NSString *dashManifest;
@property (nonatomic, copy, nullable) NSString *title;
@property (nonatomic, copy, nullable) NSString *artist;
@property (nonatomic, copy, nullable) NSString *mediaIdentifier;
@property (nonatomic, copy, nullable) NSString *sourceURLString;
@property (nonatomic) NSTimeInterval duration;
@property (nonatomic) NSInteger bitrate;
@property (nonatomic) SPKAudioSource source;

+ (nullable instancetype)itemWithURL:(NSURL *)url source:(SPKAudioSource)source;
- (SPKGallerySource)gallerySource;
- (NSString *)preferredFileExtension;

@end

NS_ASSUME_NONNULL_END
