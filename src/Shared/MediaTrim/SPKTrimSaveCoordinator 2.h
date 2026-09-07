#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "../Gallery/SPKGalleryFile.h"

@class SPKTrimResult;
@class SPKNotificationPillView;
@class SPKGallerySaveMetadata;

NS_ASSUME_NONNULL_BEGIN

/// Persists a rendered temp file, then reports success + a user-facing message.
typedef void (^SPKTrimStoreCompletion)(BOOL ok, NSString *_Nullable message);
typedef void (^SPKTrimStoreBlock)(NSURL *renderedURL, SPKTrimStoreCompletion done);

/// Routes a confirmed trim result into the Gallery. When `originFile` is non-nil
/// and the `trim_gallery_prompt_replace` setting is on, prompts the user to
/// Replace the original or Save as a Copy; otherwise it silently saves a copy.
/// Always cleans up `result.outputURL` and posts a result notification.
@interface SPKTrimSaveCoordinator : NSObject

+ (void)saveResult:(SPKTrimResult *)result
        originFile:(nullable SPKGalleryFile *)originFile
    fallbackSource:(SPKGallerySource)fallbackSource
        folderPath:(nullable NSString *)folderPath
         presenter:(nullable UIViewController *)presenter
        completion:(nullable void (^)(BOOL didChange))completion;

/// Routes an edited still image (from the photo editor) into the Gallery, using
/// the same `trim_gallery_prompt_replace` Replace / Save-as-Copy flow as trims.
/// The image is encoded to a temporary file and stored; when `originFile` is
/// non-nil it can replace the original in place, otherwise a new copy is saved.
+ (void)saveEditedImage:(UIImage *)image
             originFile:(nullable SPKGalleryFile *)originFile
         fallbackSource:(SPKGallerySource)fallbackSource
             folderPath:(nullable NSString *)folderPath
              presenter:(nullable UIViewController *)presenter
             completion:(nullable void (^)(BOOL didChange))completion;

/// Routes an edited still image (from the photo editor) to one of the save-flow
/// destinations ("photos", "gallery", "share", "clipboard") — the non-gallery
/// counterpart to `saveEditedImage:` (which offers Replace/Copy for a gallery
/// origin). Encodes the image to a temp file and hands it to `routeResult:`.
+ (void)routeEditedImage:(UIImage *)image
           toDestination:(NSString *)destination
                metadata:(nullable SPKGallerySaveMetadata *)metadata
               presenter:(nullable UIViewController *)presenter
              completion:(nullable void (^)(BOOL ok))completion;

/// Renders `result` in the background behind a cancellable progress pill, then
/// hands the rendered temp file to `store`. Used by callers that route the
/// output somewhere other than a Gallery copy/replace (e.g. the save-flow
/// destination picker). `store` runs on the main thread.
///
/// Pass `existingPill` to continue an already-visible progress pill (e.g. one
/// started for a preceding download stage) instead of spawning a new one — the
/// render reuses it and transitions it to success/error. Pass nil to create a
/// fresh pill.
/// `onSuccessTap` (optional) is attached to the pill on success so tapping the
/// completed pill opens the result (e.g. the Gallery).
+ (void)renderResult:(SPKTrimResult *)result
       progressTitle:(nullable NSString *)progressTitle
        existingPill:(nullable SPKNotificationPillView *)existingPill
               store:(SPKTrimStoreBlock)store
        onSuccessTap:(nullable void (^)(void))onSuccessTap
          completion:(nullable void (^)(BOOL ok))completion;

/// Renders `result` and routes the output to one of the save-flow destinations
/// ("photos", "gallery", "share", "clipboard"), carrying `metadata` onto Gallery
/// copies so filenames/attribution match the source (instead of falling back to
/// `media_other_...`). This is the shared routing used by every "pick a
/// destination" trim entry point. `presenter` is required for "share". Pass
/// `existingPill` to continue an in-flight progress pill.
+ (void)routeResult:(SPKTrimResult *)result
      toDestination:(NSString *)destination
           metadata:(nullable SPKGallerySaveMetadata *)metadata
          presenter:(nullable UIViewController *)presenter
       existingPill:(nullable SPKNotificationPillView *)existingPill
         completion:(nullable void (^)(BOOL ok))completion;

/// Presents a "Cancel Trim?" confirmation (mirrors the download cancel) and runs
/// `onConfirm` only if the user confirms. Runs `onConfirm` directly if no
/// presenter is available.
+ (void)confirmCancelThen:(void (^)(void))onConfirm;

@end

NS_ASSUME_NONNULL_END
