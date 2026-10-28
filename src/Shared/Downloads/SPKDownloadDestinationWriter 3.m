#import "SPKDownloadDestinationWriter.h"

#import "../../Utils.h"
#import "../Gallery/SPKGalleryFile.h"
#import "../Gallery/SPKGallerySaveMetadata.h"
#import "../UI/SPKNotificationCenter.h"
#import "SPKDownloadDuplicatePolicy.h"
#import <Photos/Photos.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

@implementation SPKDownloadDestinationWriter

+ (BOOL)isVideoFileAtURL:(NSURL *)fileURL {
    NSString *ext = fileURL.pathExtension.lowercaseString;
    NSSet<NSString *> *videoExtensions = [NSSet setWithArray:@[
        @"mp4", @"mov", @"m4v", @"avi", @"webm", @"mkv", @"3gp"
    ]];
    return [videoExtensions containsObject:ext];
}

+ (BOOL)isAudioFileAtURL:(NSURL *)fileURL {
    NSString *ext = fileURL.pathExtension.lowercaseString;
    NSSet<NSString *> *audioExtensions = [NSSet setWithArray:@[
        @"m4a", @"aac", @"mp3", @"wav", @"caf", @"aiff", @"flac", @"opus", @"ogg"
    ]];
    return [audioExtensions containsObject:ext];
}

+ (void)saveFileURLToPhotos:(NSURL *)fileURL
                   metadata:(SPKGallerySaveMetadata *)metadata
                 completion:(void (^)(BOOL success, NSError *error))completion {
    BOOL isVideo = [self isVideoFileAtURL:fileURL];
    SPKGalleryMediaType mediaType =
        [self isAudioFileAtURL:fileURL]
            ? SPKGalleryMediaTypeAudio
            : (isVideo ? SPKGalleryMediaTypeVideo : SPKGalleryMediaTypeImage);
    __block NSString *assetLocalIdentifier = nil;

    BOOL albumEnabled = [SPKUtils getBoolPref:@"downloads_photos_album_enabled"];
    NSString *albumName = albumEnabled ? [SPKUtils getStringPref:@"downloads_photos_album"] : nil;

    if (albumName.length > 0) {
        PHFetchOptions *fetchOptions = [[PHFetchOptions alloc] init];
        fetchOptions.predicate = [NSPredicate predicateWithFormat:@"title = %@", albumName];
        PHFetchResult *fetchResult = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeAlbum
                                                                              subtype:PHAssetCollectionSubtypeAny
                                                                              options:fetchOptions];
        PHAssetCollection *collection = fetchResult.firstObject;

        [[PHPhotoLibrary sharedPhotoLibrary]
            performChanges:^{
                PHAssetChangeRequest *assetRequest = nil;
                if (isVideo) {
                    assetRequest = [PHAssetChangeRequest
                        creationRequestForAssetFromVideoAtFileURL:fileURL];
                } else {
                    assetRequest = [PHAssetChangeRequest
                        creationRequestForAssetFromImageAtFileURL:fileURL];
                }
                PHObjectPlaceholder *assetPlaceholder = assetRequest.placeholderForCreatedAsset;
                assetLocalIdentifier = assetPlaceholder.localIdentifier;

                PHAssetCollectionChangeRequest *albumChangeRequest = nil;
                if (collection) {
                    albumChangeRequest = [PHAssetCollectionChangeRequest changeRequestForAssetCollection:collection];
                } else {
                    albumChangeRequest = [PHAssetCollectionChangeRequest creationRequestForAssetCollectionWithTitle:albumName];
                }
                [albumChangeRequest addAssets:@[assetPlaceholder]];
            }
            completionHandler:^(BOOL success, NSError *error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (success) {
                        [SPKDownloadDuplicatePolicy
                            recordPhotosSaveWithMetadata:metadata
                                               mediaType:mediaType
                                    assetLocalIdentifier:assetLocalIdentifier];
                    }
                    if (completion)
                        completion(success, error);
                });
            }];
    } else {
        [[PHPhotoLibrary sharedPhotoLibrary]
            performChanges:^{
                PHAssetChangeRequest *request = nil;
                if (isVideo) {
                    request = [PHAssetChangeRequest
                        creationRequestForAssetFromVideoAtFileURL:fileURL];
                } else {
                    request = [PHAssetChangeRequest
                        creationRequestForAssetFromImageAtFileURL:fileURL];
                }
                assetLocalIdentifier =
                    request.placeholderForCreatedAsset.localIdentifier;
            }
            completionHandler:^(BOOL success, NSError *error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (success) {
                        [SPKDownloadDuplicatePolicy
                            recordPhotosSaveWithMetadata:metadata
                                               mediaType:mediaType
                                    assetLocalIdentifier:assetLocalIdentifier];
                    }
                    if (completion)
                        completion(success, error);
                });
            }];
    }
}

+ (SPKGalleryFile *)saveFileURLToGallery:(NSURL *)fileURL
                                metadata:(SPKGallerySaveMetadata *)metadata
                                   error:(NSError **)error {
    SPKGalleryMediaType galleryType =
        [self isAudioFileAtURL:fileURL]
            ? SPKGalleryMediaTypeAudio
            : ([self isVideoFileAtURL:fileURL] ? SPKGalleryMediaTypeVideo
                                               : SPKGalleryMediaTypeImage);
    return [SPKGalleryFile saveFileToGallery:fileURL
                                      source:SPKGallerySourceOther
                                   mediaType:galleryType
                                  folderPath:nil
                                    metadata:metadata
                                       error:error];
}

- (void)finalizeFileAtPath:(NSString *)stagedPath
                   request:(SPKDownloadRequest *)request
               itemRequest:(SPKDownloadItemRequest *)itemRequest
                 presenter:(UIViewController *)presenter
                anchorView:(UIView *)anchorView
                completion:(SPKDownloadDestinationCompletion)completion {
    NSURL *fileURL = [NSURL fileURLWithPath:stagedPath];
    SPKGallerySaveMetadata *metadata = itemRequest.metadata ?: request.metadata;
    switch (request.destination) {
    case SPKDownloadDestinationPhotos:
        [self saveToPhotos:fileURL
                  metadata:metadata
               itemRequest:itemRequest
                completion:completion];
        break;
    case SPKDownloadDestinationGallery:
        [self saveToGallery:fileURL metadata:metadata completion:completion];
        break;
    case SPKDownloadDestinationShare:
        [self presentShare:fileURL
                   request:request
                 presenter:presenter
                anchorView:anchorView
                completion:completion];
        break;
    case SPKDownloadDestinationClipboard:
        [self copyToClipboard:fileURL
                  itemRequest:itemRequest
                   completion:completion];
        break;
    case SPKDownloadDestinationCacheOnly:
        if (completion)
            completion(stagedPath, nil, nil);
        break;
    }
}

- (void)saveToPhotos:(NSURL *)fileURL
            metadata:(SPKGallerySaveMetadata *)metadata
         itemRequest:(SPKDownloadItemRequest *)itemRequest
          completion:(SPKDownloadDestinationCompletion)completion {
    if (itemRequest.mediaKind == SPKDownloadMediaKindAudio ||
        [[self class] isAudioFileAtURL:fileURL]) {
        if (completion) {
            completion(nil, nil,
                       SPKDownloadError(SPKDownloadErrorAudioPhotosUnsupported,
                                        @"Audio cannot be saved to Photos.",
                                        @"Use Gallery or Share instead."));
        }
        return;
    }
    [[self class]
        saveFileURLToPhotos:fileURL
                   metadata:metadata
                 completion:^(BOOL success, NSError *error) {
                     if (!success) {
                         NSString *desc = error.localizedDescription
                                              ?: @"Could not save to Photos. Check "
                                                 @"photo library permission.";
                         if (completion)
                             completion(
                                 nil, nil,
                                 SPKDownloadError(SPKDownloadErrorPhotosSaveFailed,
                                                  desc, nil));
                         return;
                     }
                     if (completion)
                         completion(fileURL.path, nil, nil);
                 }];
}

- (void)saveToGallery:(NSURL *)fileURL
             metadata:(SPKGallerySaveMetadata *)metadata
           completion:(SPKDownloadDestinationCompletion)completion {
    NSError *error = nil;
    SPKGalleryFile *file = [[self class] saveFileURLToGallery:fileURL
                                                     metadata:metadata
                                                        error:&error];
    if (!file) {
        if (completion)
            completion(nil, nil,
                       SPKDownloadError(SPKDownloadErrorGallerySaveFailed,
                                        error.localizedDescription
                                            ?: @"Could not save to Gallery.",
                                        nil));
        return;
    }
    if (completion)
        completion(file.filePath, nil, nil);
}

- (void)presentShare:(NSURL *)fileURL
             request:(SPKDownloadRequest *)request
           presenter:(UIViewController *)presenter
          anchorView:(UIView *)anchorView
          completion:(SPKDownloadDestinationCompletion)completion {
    UIViewController *host = presenter ?: topMostController();
    if (!host) {
        if (completion)
            completion(nil, nil,
                       SPKDownloadError(SPKDownloadErrorSharePresentationFailed,
                                        @"Could not present share sheet.", nil));
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        if (request.items.count > 1) {
            UIActivityViewController *vc =
                [[UIActivityViewController alloc] initWithActivityItems:@[ fileURL ]
                                                  applicationActivities:nil];
            if (anchorView && UIDevice.currentDevice.userInterfaceIdiom ==
                                  UIUserInterfaceIdiomPad) {
                vc.popoverPresentationController.sourceView = anchorView;
                vc.popoverPresentationController.sourceRect = anchorView.bounds;
            }
            [host presentViewController:vc animated:YES completion:nil];
        } else {
            [SPKUtils showShareVC:fileURL];
        }
        if (completion)
            completion(fileURL.path, nil, nil);
    });
}

- (void)copyToClipboard:(NSURL *)fileURL
            itemRequest:(SPKDownloadItemRequest *)itemRequest
             completion:(SPKDownloadDestinationCompletion)completion {
    if (itemRequest.linkString.length > 0 && !fileURL.isFileURL) {
        UIPasteboard.generalPasteboard.string = itemRequest.linkString;
        if (completion)
            completion(nil, nil, nil);
        return;
    }
    NSDictionary *attrs =
        [[NSFileManager defaultManager] attributesOfItemAtPath:fileURL.path
                                                         error:nil];
    int64_t size = [attrs[NSFileSize] longLongValue];
    if (size > 80 * 1024 * 1024) {
        if (completion)
            completion(nil, nil,
                       SPKDownloadError(
                           SPKDownloadErrorClipboardTooLarge,
                           @"File is too large to copy to the clipboard.", nil));
        return;
    }
    NSString *ext = fileURL.pathExtension.lowercaseString;
    NSString *uti = @"public.data";
    if ([ext isEqualToString:@"jpg"] || [ext isEqualToString:@"jpeg"])
        uti = UTTypeJPEG.identifier;
    else if ([ext isEqualToString:@"png"])
        uti = UTTypePNG.identifier;
    else if ([ext isEqualToString:@"gif"])
        uti = UTTypeGIF.identifier;
    else if ([ext isEqualToString:@"webp"])
        uti = UTTypeWebP.identifier;
    else if ([ext isEqualToString:@"mp4"] || [ext isEqualToString:@"mov"])
        uti = UTTypeMovie.identifier;
    else if ([ext isEqualToString:@"m4a"] || [ext isEqualToString:@"mp3"])
        uti = UTTypeAudio.identifier;
    NSData *data = [NSData dataWithContentsOfURL:fileURL
                                         options:NSDataReadingMappedIfSafe
                                           error:nil];
    if (!data) {
        if (completion)
            completion(nil, nil,
                       SPKDownloadError(SPKDownloadErrorFileMoveFailed,
                                        @"Could not read file for clipboard.", nil));
        return;
    }
    [UIPasteboard generalPasteboard].items = @[ @{uti : data} ];
    if (completion)
        completion(fileURL.path, nil, nil);
}

@end
