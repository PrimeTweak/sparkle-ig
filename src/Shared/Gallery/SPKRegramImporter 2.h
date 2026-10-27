#import <UIKit/UIKit.h>

#import "SPKGalleryFile.h"
#import "SPKGallerySaveMetadata.h"

NS_ASSUME_NONNULL_BEGIN

/// Reads a Regram "export settings & data" *media vault* so it can be fed into the standard Gallery
/// import queue (editable metadata + the usual save pipeline).
///
/// Regram ships its vault as `MediaVault/` — a Core Data `MediaVault.sqlite` (entities `ZRGVFILE` +
/// `ZRGVUSER`) alongside a `Files/<userPK>/...` media tree — either as a plain folder, a
/// `MediaVault.zip` (DEFLATE/ZIP64), or nested inside a full `Regram-Data.zip` export. This reader
/// auto-detects any of those, and maps each row onto `SPKGallerySaveMetadata`.
@interface SPKRegramImporter : NSObject

/// Resolves a picked folder/zip and returns one opaque row dictionary per importable vault item
/// (keys are consumed via the helpers below), or nil if the picked item isn't a Regram vault.
/// Heavy (unzip + SQLite) — call off the main thread.
+ (nullable NSArray<NSDictionary *> *)vaultRowsFromPickedURL:(NSURL *)url;

/// Absolute path to the row's media file (already extracted to a local temp dir).
+ (nullable NSString *)filePathForRow:(NSDictionary *)row;

/// Save metadata (source, username/PK/full-name, media code/PK, dimensions, duration, dates) for a row.
+ (SPKGallerySaveMetadata *)metadataForRow:(NSDictionary *)row;

/// Media type for a row (from Regram's `ZTYPE`, falling back to the file extension).
+ (SPKGalleryMediaType)mediaTypeForRow:(NSDictionary *)row;

/// Whether the row was favorited in Regram.
+ (BOOL)isFavoriteRow:(NSDictionary *)row;

@end

NS_ASSUME_NONNULL_END
