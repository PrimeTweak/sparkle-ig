#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "SPKDownloadRequest.h"
#import "SPKDownloadTypes.h"

NS_ASSUME_NONNULL_BEGIN

@class SPKGallerySaveMetadata;

typedef NS_ENUM(NSInteger, SPKDownloadDuplicateDestination) {
    SPKDownloadDuplicateDestinationGallery = 1,
    SPKDownloadDuplicateDestinationPhotos = 2,
};

typedef NS_ENUM(NSInteger, SPKDownloadPreflightResult) {
    SPKDownloadPreflightContinue = 0,
    SPKDownloadPreflightSkipSucceeded,
    SPKDownloadPreflightCancelled,
};

typedef void (^SPKDownloadPreflightCompletion)(SPKDownloadPreflightResult result);

@interface SPKDownloadDuplicatePolicy : NSObject

- (BOOL)duplicateDestinationFor:(SPKDownloadDestination)destination
                       outValue:(SPKDownloadDuplicateDestination *)outValue;
- (NSInteger)mediaTypeForKind:(SPKDownloadMediaKind)kind;

- (void)runPreflightForRequest:(SPKDownloadRequest *)request
                     presenter:(nullable UIViewController *)presenter
                    completion:(SPKDownloadPreflightCompletion)completion;

// Low-level duplicate detection and ledger management
+ (BOOL)hasDuplicateForDestination:(SPKDownloadDuplicateDestination)destination
                          metadata:(nullable SPKGallerySaveMetadata *)metadata
                         mediaType:(NSInteger)mediaType;

/// Unconditional "has this media already been saved to `destination`?" check --
/// the Gallery's own records for Gallery, the Photos save ledger for Photos.
/// Any other destination has nothing durable to check and answers NO.
///
/// Unlike `hasDuplicateForDestination:`, this ignores the user-facing
/// detect-duplicates preference. Auto-save needs a guard that holds across
/// launches regardless of that setting, since its session set only dedupes
/// within a single viewer session.
+ (BOOL)destinationContainsMediaForMetadata:(nullable SPKGallerySaveMetadata *)metadata
                                  mediaType:(NSInteger)mediaType
                                destination:(SPKDownloadDestination)destination;

+ (void)recordPhotosSaveWithMetadata:(nullable SPKGallerySaveMetadata *)metadata
                           mediaType:(NSInteger)mediaType
                assetLocalIdentifier:(nullable NSString *)assetLocalIdentifier;

@end

NS_ASSUME_NONNULL_END
