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

/// Same flow when the media is already on disk: `localFileURL`, a copy of the remote
/// `localSourceURL`, is scrubbed instead of downloading again, and is the final source
/// only when the chosen quality is that same file.
+ (void)beginTrimAndSaveForMediaObject:(nullable id)mediaObject
                              photoURL:(nullable NSURL *)photoURL
                              videoURL:(nullable NSURL *)videoURL
                          localFileURL:(nullable NSURL *)localFileURL
                        localSourceURL:(nullable NSURL *)localSourceURL
                              metadata:(nullable SPKGallerySaveMetadata *)metadata
                             presenter:(UIViewController *)presenter;

@end

NS_ASSUME_NONNULL_END
