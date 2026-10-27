#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Optional context when saving to the gallery (e.g. from the action button).
/// `source` uses the same values as `SPKGallerySource` in SPKGalleryFile.
@interface SPKGallerySaveMetadata : NSObject <NSCopying>

@property (nonatomic, copy, nullable) NSString *sourceUsername;
@property (nonatomic, copy, nullable) NSString *sourceUserPK;
@property (nonatomic, copy, nullable) NSString *sourceProfileURLString;
@property (nonatomic, copy, nullable) NSString *sourceMediaPK;
@property (nonatomic, copy, nullable) NSString *sourceMediaCode;
@property (nonatomic, copy, nullable) NSString *sourceMediaURLString;
@property (nonatomic, assign) int16_t source;

/// Marks the resulting `SPKGalleryFile` as auto-saved (see `SPKGalleryFile.isAutoSave`).
@property (nonatomic, assign) BOOL isAutoSave;

/// If > 0, overrides probed dimensions from the file.
@property (nonatomic, assign) int32_t pixelWidth;
@property (nonatomic, assign) int32_t pixelHeight;

/// If > 0 for video, overrides probed duration (seconds).
@property (nonatomic, assign) double durationSeconds;

/// When set, used as the basename segment for `SPKFileNameForMedia` instead of `sourceUsername` or the picked file’s name.
@property (nonatomic, copy, nullable) NSString *importFileNameStem;

/// Stored on `SPKGalleryFile.customName` for list/grid display.
@property (nonatomic, copy, nullable) NSString *customName;

/// When set, used for `SPKGalleryFile.dateAdded` as the import/save time (e.g. parsed from a leading epoch segment in tweak-style basenames).
@property (nonatomic, strong, nullable) NSDate *importCapturedDate;

/// Optional media posted time parsed from tweak-style trailing compact dates (..._story_yyyyMMddHHmmss). Used for generated filename compact segment when available.
@property (nonatomic, strong, nullable) NSDate *importPostedDate;

/// Transient (never persisted) display/full name of the source user, resolved live for
/// the preview metadata overlay (used as the subtitle for profile pictures, which have
/// no post date). Not written to the gallery.
@property (nonatomic, copy, nullable) NSString *sourceFullName;

/// Plist-safe round-trip for persisting the import queue across screen dismissals / relaunches.
/// The transient `sourceFullName` is intentionally excluded (it is re-resolved live).
- (NSDictionary *)spk_dictionaryRepresentation;
+ (instancetype)spk_metadataFromDictionary:(NSDictionary *)dict;

@end

NS_ASSUME_NONNULL_END
