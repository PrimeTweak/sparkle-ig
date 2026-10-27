#import "SPKAudioItem.h"

@implementation SPKAudioItem

+ (instancetype)itemWithURL:(NSURL *)url source:(SPKAudioSource)source {
    if (!url.absoluteString.length)
        return nil;
    SPKAudioItem *item = [[self alloc] init];
    item.url = url;
    item.source = source;
    item.sourceURLString = url.absoluteString;
    return item;
}

- (id)copyWithZone:(NSZone *)zone {
    SPKAudioItem *copy = [[[self class] allocWithZone:zone] init];
    copy.url = self.url;
    copy.dashManifest = [self.dashManifest copy];
    copy.title = [self.title copy];
    copy.artist = [self.artist copy];
    copy.mediaIdentifier = [self.mediaIdentifier copy];
    copy.sourceURLString = [self.sourceURLString copy];
    copy.duration = self.duration;
    copy.bitrate = self.bitrate;
    copy.source = self.source;
    return copy;
}

- (SPKGallerySource)gallerySource {
    switch (self.source) {
    case SPKAudioSourceFeed:
        return SPKGallerySourceFeed;
    case SPKAudioSourceReels:
        return SPKGallerySourceReels;
    case SPKAudioSourceStories:
        return SPKGallerySourceStories;
    case SPKAudioSourceDMs:
    case SPKAudioSourceDMNotes:
        return SPKGallerySourceDMs;
    case SPKAudioSourceAudioPage:
        return SPKGallerySourceAudioPage;
    case SPKAudioSourceOther:
    default:
        return SPKGallerySourceOther;
    }
}

- (NSString *)preferredFileExtension {
    NSString *ext = self.url.pathExtension.lowercaseString;
    if (ext.length > 0 && ext.length <= 5)
        return ext;
    return @"m4a";
}

@end
