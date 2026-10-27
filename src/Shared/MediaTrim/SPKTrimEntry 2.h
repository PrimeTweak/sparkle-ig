#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class SPKGallerySaveMetadata;

NS_ASSUME_NONNULL_BEGIN

/// Orchestrates the action-button "Trim & Save" flow: resolves the trim source
/// from the media object (honoring the user's quality setting), fetches a
/// preview to a temp file, presents the trim editor, then a destination picker
/// (Photos / Gallery / Share) and renders + finalizes in the background.
@interface SPKTrimEntry : NSObject

+ (void)beginTrimAndSaveForMediaObject:(nullable id)mediaObject
                              photoURL:(nullable NSURL *)photoURL
                              videoURL:(nullable NSURL *)videoURL
                              metadata:(nullable SPKGallerySaveMetadata *)metadata
                             presenter:(UIViewController *)presenter;

@end

NS_ASSUME_NONNULL_END
