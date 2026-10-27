#import <CoreData/CoreData.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// How to resolve an imported file that already exists on the device under a
/// *different* account (only possible during a "this account" re-map import).
typedef NS_ENUM(NSInteger, SPKGalleryImportConflictStrategy) {
    SPKGalleryImportConflictStrategySkip = 0,      ///< Leave the existing file untouched.
    SPKGalleryImportConflictStrategyClaim = 1,     ///< Re-assign it to the importing account (moves it).
    SPKGalleryImportConflictStrategyDuplicate = 2, ///< Add a separate copy owned by the importing account.
};

@interface SPKGalleryCoreDataStack : NSObject

+ (instancetype)shared;

@property (nonatomic, strong, readonly) NSPersistentContainer *persistentContainer;
@property (nonatomic, strong, readonly) NSManagedObjectContext *viewContext;

- (void)saveContext;
- (void)unloadPersistentStores;
- (void)reloadPersistentContainer;

/// Non-destructive import: inserts every SPKGalleryFile from an exported bundle's
/// Gallery directory (containing gallery.sqlite + Files/ + Thumbnails/) that isn't
/// already present (dedup by `identifier`), copying its media + thumbnail into the
/// live store. Existing files are never deleted. When `remapOwnerAccountPK` is
/// non-nil, imported files are re-assigned to that account (used to land a
/// "this account" backup onto the importing device's active account). Returns the
/// number of files added, or -1 on a hard failure (with `error` set). Returns 0 if
/// the bundle has no store.
- (NSInteger)mergeGalleryFilesFromBundleDirectory:(NSString *)bundleGalleryDirectory
                              remapOwnerAccountPK:(nullable NSString *)remapOwnerAccountPK
                                    ownerUsername:(nullable NSString *)ownerUsername
                                 conflictStrategy:(SPKGalleryImportConflictStrategy)conflictStrategy
                                  progressHandler:(nullable void (^)(NSInteger done, NSInteger total))progressHandler
                                            error:(NSError *_Nullable *_Nullable)error;

/// Number of files in the bundle that already exist on the device but are owned by an
/// account other than `ownerAccountPK` (i.e. the conflicts a "this account" import must
/// resolve). Returns 0 when `ownerAccountPK` is nil. Used to decide whether to prompt.
- (NSInteger)galleryImportConflictCountForBundleDirectory:(NSString *)bundleGalleryDirectory
                                           ownerAccountPK:(nullable NSString *)ownerAccountPK;

/// Writes a bundle Gallery directory (gallery.sqlite + Files/ + Thumbnails/) holding
/// only the files owned by `ownerAccountPK` (pass nil to include all files). Used for
/// per-account ("this account") exports. Returns NO on failure (with `error` set).
- (BOOL)exportGalleryFilesToBundleDirectory:(NSString *)bundleGalleryDirectory
                             ownerAccountPK:(nullable NSString *)ownerAccountPK
                            progressHandler:(nullable void (^)(NSInteger done, NSInteger total))progressHandler
                                      error:(NSError *_Nullable *_Nullable)error;

@end

NS_ASSUME_NONNULL_END
