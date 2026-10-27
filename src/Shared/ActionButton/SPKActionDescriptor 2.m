#import "SPKActionDescriptor.h"
#import "ActionButtonCore.h"

@implementation SPKActionDescriptor

+ (instancetype)descriptorWithIdentifier:(NSString *)identifier
                                   title:(NSString *)title
                                iconName:(NSString *)iconName {
    SPKActionDescriptor *descriptor = [[self alloc] init];
    descriptor.identifier = identifier;
    descriptor.title = title;
    descriptor.iconName = iconName;
    return descriptor;
}

+ (NSArray<SPKActionDescriptor *> *)descriptors {
    static NSArray<SPKActionDescriptor *> *descriptors = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        descriptors = @[
            [SPKActionDescriptor descriptorWithIdentifier:kSPKActionDownloadLibrary
                                                    title:@"Save to Photos"
                                                 iconName:@"download"],
            [SPKActionDescriptor descriptorWithIdentifier:kSPKActionDownloadShare
                                                    title:@"Share"
                                                 iconName:@"share"],
            [SPKActionDescriptor descriptorWithIdentifier:kSPKActionCopyDownloadLink
                                                    title:@"Copy Download URL"
                                                 iconName:@"link"],
            [SPKActionDescriptor descriptorWithIdentifier:kSPKActionCopyMedia
                                                    title:@"Copy Media"
                                                 iconName:@"copy"],
            [SPKActionDescriptor descriptorWithIdentifier:kSPKActionDownloadGallery
                                                    title:@"Save to Gallery"
                                                 iconName:@"sparkle_gallery"],
            [SPKActionDescriptor descriptorWithIdentifier:kSPKActionTrimSave
                                                    title:@"Trim & Save"
                                                 iconName:@"trim"],
            [SPKActionDescriptor descriptorWithIdentifier:kSPKActionEditSave
                                                    title:@"Edit & Save"
                                                 iconName:@"crop"],
            [SPKActionDescriptor descriptorWithIdentifier:kSPKActionDownloadAudio
                                                    title:@"Save Audio to Files"
                                                 iconName:@"audio_download"],
            [SPKActionDescriptor descriptorWithIdentifier:kSPKActionDownloadAudioShare
                                                    title:@"Share Audio"
                                                 iconName:@"share"],
            [SPKActionDescriptor descriptorWithIdentifier:kSPKActionDownloadAudioGallery
                                                    title:@"Save Audio to Gallery"
                                                 iconName:@"sparkle_gallery"],
            [SPKActionDescriptor descriptorWithIdentifier:kSPKActionPlayAudio
                                                    title:@"Play Audio"
                                                 iconName:@"play"],
            [SPKActionDescriptor descriptorWithIdentifier:kSPKActionCopyAudioURL
                                                    title:@"Copy audio URL"
                                                 iconName:@"link"],
            [SPKActionDescriptor descriptorWithIdentifier:kSPKActionDownloadAllLibrary
                                                    title:@"Save All to Photos"
                                                 iconName:@"download"],
            [SPKActionDescriptor descriptorWithIdentifier:kSPKActionDownloadAllShare
                                                    title:@"Share All"
                                                 iconName:@"share"],
            [SPKActionDescriptor descriptorWithIdentifier:kSPKActionDownloadAllGallery
                                                    title:@"Save All to Gallery"
                                                 iconName:@"sparkle_gallery"],
            [SPKActionDescriptor descriptorWithIdentifier:kSPKActionDownloadAllClipboard
                                                    title:@"Copy All Media"
                                                 iconName:@"copy"],
            [SPKActionDescriptor descriptorWithIdentifier:kSPKActionDownloadAllLinks
                                                    title:@"Copy Download URLs"
                                                 iconName:@"link"],
            [SPKActionDescriptor descriptorWithIdentifier:kSPKActionDownloadAll
                                                    title:@"Download All"
                                                 iconName:@"more"],
            [SPKActionDescriptor descriptorWithIdentifier:kSPKActionExpand
                                                    title:@"Expand"
                                                 iconName:@"expand"],
            [SPKActionDescriptor descriptorWithIdentifier:kSPKActionViewThumbnail
                                                    title:@"View Thumbnail"
                                                 iconName:@"photo_gallery"],
            [SPKActionDescriptor descriptorWithIdentifier:kSPKActionCopyCaption
                                                    title:@"Copy Caption"
                                                 iconName:@"caption"],
            [SPKActionDescriptor descriptorWithIdentifier:kSPKActionOpenTopicSettings
                                                    title:@"Settings"
                                                 iconName:@"settings"],
            [SPKActionDescriptor descriptorWithIdentifier:kSPKActionDeletedMessagesLog
                                                    title:@"Deleted Messages"
                                                 iconName:@"channels"],
            [SPKActionDescriptor descriptorWithIdentifier:kSPKActionRepost
                                                    title:@"Repost"
                                                 iconName:@"repost"],
            [SPKActionDescriptor descriptorWithIdentifier:kSPKActionToggleStorySeenUserRule
                                                    title:@"Story rule"
                                                 iconName:@"eye"],
            [SPKActionDescriptor descriptorWithIdentifier:kSPKActionToggleStoryAutoSaveUserRule
                                                    title:@"Story auto-save"
                                                 iconName:@"download"],
            [SPKActionDescriptor descriptorWithIdentifier:kSPKActionToggleDirectAutoSaveThreadRule
                                                    title:@"Chat auto-save"
                                                 iconName:@"download"],
            [SPKActionDescriptor descriptorWithIdentifier:kSPKActionToggleProfileStorySeenUserRule
                                                    title:@"Story seen"
                                                 iconName:@"eye"],
            [SPKActionDescriptor descriptorWithIdentifier:kSPKActionToggleProfileMessagesSeenUserRule
                                                    title:@"Messages seen"
                                                 iconName:@"eye"],
            [SPKActionDescriptor descriptorWithIdentifier:kSPKActionStoryMentionsSheet
                                                    title:@"Story Mentions"
                                                 iconName:@"mention"],
            [SPKActionDescriptor descriptorWithIdentifier:kSPKActionProfileCopyInfo
                                                    title:@"Copy Info"
                                                 iconName:@"info"],
            [SPKActionDescriptor descriptorWithIdentifier:kSPKActionProfileCopyID
                                                    title:@"Copy ID"
                                                 iconName:@"key"],
            [SPKActionDescriptor descriptorWithIdentifier:kSPKActionProfileCopyUsername
                                                    title:@"Copy Username"
                                                 iconName:@"username"],
            [SPKActionDescriptor descriptorWithIdentifier:kSPKActionProfileCopyName
                                                    title:@"Copy Name"
                                                 iconName:@"text"],
            [SPKActionDescriptor descriptorWithIdentifier:kSPKActionProfileCopyBio
                                                    title:@"Copy Bio"
                                                 iconName:@"caption"],
            [SPKActionDescriptor descriptorWithIdentifier:kSPKActionProfileCopyLink
                                                    title:@"Copy Profile URL"
                                                 iconName:@"link"],
            [SPKActionDescriptor descriptorWithIdentifier:@"more"
                                                    title:@"More"
                                                 iconName:@"more"],
            [SPKActionDescriptor descriptorWithIdentifier:@"action"
                                                    title:@"Actions"
                                                 iconName:@"action"]
        ];
    });
    return descriptors;
}

+ (nullable instancetype)descriptorForIdentifier:(NSString *)identifier {
    for (SPKActionDescriptor *descriptor in [self descriptors]) {
        if ([descriptor.identifier isEqualToString:identifier]) {
            return descriptor;
        }
    }
    return nil;
}

+ (NSArray<SPKActionDescriptor *> *)availableSectionIconDescriptors {
    return @[
        [SPKActionDescriptor descriptorWithIdentifier:@"action"
                                                title:@"Actions"
                                             iconName:@"action"],
        [SPKActionDescriptor descriptorWithIdentifier:@"copy"
                                                title:@"Copy"
                                             iconName:@"copy"],
        [SPKActionDescriptor descriptorWithIdentifier:@"key"
                                                title:@"Key"
                                             iconName:@"key"],
        [SPKActionDescriptor descriptorWithIdentifier:@"caption"
                                                title:@"Caption"
                                             iconName:@"caption"],
        [SPKActionDescriptor descriptorWithIdentifier:@"download"
                                                title:@"Download"
                                             iconName:@"download"],
        [SPKActionDescriptor descriptorWithIdentifier:@"share"
                                                title:@"Share"
                                             iconName:@"share"],
        [SPKActionDescriptor descriptorWithIdentifier:@"link"
                                                title:@"Link"
                                             iconName:@"link"],
        [SPKActionDescriptor descriptorWithIdentifier:@"media"
                                                title:@"Gallery"
                                             iconName:@"sparkle_gallery"],
        [SPKActionDescriptor descriptorWithIdentifier:@"expand"
                                                title:@"Expand"
                                             iconName:@"expand"],
        [SPKActionDescriptor descriptorWithIdentifier:@"photo_gallery"
                                                title:@"Thumbnail"
                                             iconName:@"photo_gallery"],
        [SPKActionDescriptor descriptorWithIdentifier:@"repost"
                                                title:@"Repost"
                                             iconName:@"repost"],
        [SPKActionDescriptor descriptorWithIdentifier:@"mention"
                                                title:@"Mentions"
                                             iconName:@"mention"],
        [SPKActionDescriptor descriptorWithIdentifier:@"feed"
                                                title:@"Feed"
                                             iconName:@"feed"],
        [SPKActionDescriptor descriptorWithIdentifier:@"reels"
                                                title:@"Reels"
                                             iconName:@"reels"],
        [SPKActionDescriptor descriptorWithIdentifier:@"story"
                                                title:@"Stories"
                                             iconName:@"story"],
        [SPKActionDescriptor descriptorWithIdentifier:@"messages"
                                                title:@"Messages"
                                             iconName:@"messages"],
        [SPKActionDescriptor descriptorWithIdentifier:@"profile"
                                                title:@"Profile"
                                             iconName:@"user_circle"],
        [SPKActionDescriptor descriptorWithIdentifier:@"settings"
                                                title:@"Settings"
                                             iconName:@"settings"],
        [SPKActionDescriptor descriptorWithIdentifier:@"more"
                                                title:@"More"
                                             iconName:@"more"]
    ];
}

@end

NSString *SPKActionDescriptorDisplayTitle(NSString *identifier, NSString *topicTitle) {
    if ([identifier isEqualToString:kSPKActionOpenTopicSettings] && topicTitle.length > 0) {
        return [NSString stringWithFormat:@"%@ Settings", topicTitle];
    }
    SPKActionDescriptor *descriptor = [SPKActionDescriptor descriptorForIdentifier:identifier];
    return descriptor.title ?: @"Action";
}

NSString *SPKActionDescriptorIconName(NSString *identifier) {
    SPKActionDescriptor *descriptor = [SPKActionDescriptor descriptorForIdentifier:identifier];
    return descriptor.iconName ?: @"action";
}
