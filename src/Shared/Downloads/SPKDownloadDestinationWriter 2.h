#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "SPKDownloadRequest.h"
#import "SPKDownloadTypes.h"

@class SPKGallerySaveMetadata;
@class SPKGalleryFile;

NS_ASSUME_NONNULL_BEGIN

typedef void (^SPKDownloadDestinationCompletion)(
    NSString *_Nullable finalPath, NSString *_Nullable photosAssetID,
    NSError *_Nullable error);

@interface SPKDownloadDestinationWriter : NSObject

+ (BOOL)isVideoFileAtURL:(NSURL *)fileURL;
+ (BOOL)isAudioFileAtURL:(NSURL *)fileURL;
+ (void)saveFileURLToPhotos:(NSURL *)fileURL
                   metadata:(nullable SPKGallerySaveMetadata *)metadata
                 completion:(void (^)(BOOL success,
                                      NSError *_Nullable error))completion;
+ (nullable SPKGalleryFile *)
    saveFileURLToGallery:(NSURL *)fileURL
                metadata:(nullable SPKGallerySaveMetadata *)metadata
                   error:(NSError **)error;

- (void)finalizeFileAtPath:(NSString *)stagedPath
                   request:(SPKDownloadRequest *)request
               itemRequest:(SPKDownloadItemRequest *)itemRequest
                 presenter:(nullable UIViewController *)presenter
                anchorView:(nullable UIView *)anchorView
                completion:(SPKDownloadDestinationCompletion)completion;

@end

NS_ASSUME_NONNULL_END
