#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class SPKGallerySaveMetadata;

NS_ASSUME_NONNULL_BEGIN

/// Orchestrates the action-button / long-press "Edit & Save" flow for a still
/// photo: fetches the image to a temp file (photos have no DASH quality choice,
/// so it's a plain GET), presents the shared photo editor with a destination
/// menu (Photos / Gallery / Share / Copy), then routes the edited image through
/// `SPKTrimSaveCoordinator`.
@interface SPKPhotoEditEntry : NSObject

+ (void)beginEditAndSaveForMediaObject:(nullable id)mediaObject
                              photoURL:(nullable NSURL *)photoURL
                              metadata:(nullable SPKGallerySaveMetadata *)metadata
                             presenter:(UIViewController *)presenter;

@end

NS_ASSUME_NONNULL_END
