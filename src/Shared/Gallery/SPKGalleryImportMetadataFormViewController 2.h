#import <UIKit/UIKit.h>

#import "SPKGalleryFile.h"  // for SPKGalleryMediaType

@class SPKGallerySaveMetadata;

NS_ASSUME_NONNULL_BEGIN

/// Full editor for `SPKGallerySaveMetadata` (same fields as saves from Instagram). Mutates the passed object.
@interface SPKGalleryImportMetadataFormViewController : UITableViewController

@property (nonatomic, strong) SPKGallerySaveMetadata *metadata;
@property (nonatomic, copy, nullable) NSString *footerStemExplanation;

/// Optional preview header shown above the form so the user knows which file they're editing.
/// Left unset for the shared-defaults editor (which has no single file).
@property (nonatomic, strong, nullable) UIImage *previewThumbnail;
@property (nonatomic, copy, nullable) NSString *previewFilename;
@property (nonatomic, copy, nullable) NSString *previewSubtitle;
/// The queued file's temp URL — lets the header render a crisp hero and open a tap preview.
@property (nonatomic, strong, nullable) NSURL *previewFileURL;
/// The queued file's real media type. Must be supplied by the caller rather than sniffed from the
/// extension: a Regram vault stores audio inside an `.mp4`. Audio gets no hero at all.
@property (nonatomic) SPKGalleryMediaType previewMediaType;

/// YES once the user changed any field (used to pin a queued file so shared-defaults
/// changes stop flowing into it).
@property (nonatomic, readonly) BOOL didModifyMetadata;

@end

NS_ASSUME_NONNULL_END
