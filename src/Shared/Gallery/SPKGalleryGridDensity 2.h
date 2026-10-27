#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

// Shared grid-density configuration used by the gallery, the gallery picker
// (instants / audio upload sheets), and the gallery settings screen so all of
// them stay in sync.

// NSUserDefaults keys.
FOUNDATION_EXPORT NSString *const kSPKGalleryGridColumnsKey;                    // NSInteger, persisted column count
FOUNDATION_EXPORT NSString *const kSPKGalleryGridPinchDisabledKey;              // BOOL, YES disables pinch-to-zoom
FOUNDATION_EXPORT NSString *const kSPKGalleryGridShowSourceUsernameDisabledKey; // BOOL, YES hides source icon + username overlays
FOUNDATION_EXPORT NSString *const kSPKGalleryFolderBarPinDisabledKey;           // BOOL, YES unpins the folder bar (lets it scroll away)
// BOOL, YES lists the files inside subfolders alongside the current folder's own,
// so the whole gallery can be browsed from the root without entering folders.
// Read it through [SPKUtils getBoolPref:] — it is per-account like other prefs.
FOUNDATION_EXPORT NSString *const kSPKGalleryFlatBrowsingKey;
FOUNDATION_EXPORT NSString *const kSPKGalleryGridControlsChangedNotification;
// Posted when a pref that changes *which* files a gallery screen lists (as opposed
// to how they look) is toggled, so open screens can refetch.
FOUNDATION_EXPORT NSString *const kSPKGalleryBrowsingScopeChangedNotification;

/// Whether the folder bar (subfolder chips) stays pinned to the top while
/// scrolling. Defaults to YES; the backing pref stores the disabled state.
FOUNDATION_EXPORT BOOL SPKGalleryFolderBarPinned(void);

// Allowed densities and bounds.
FOUNDATION_EXPORT NSInteger const kSPKGalleryGridColumnsDefault;
FOUNDATION_EXPORT NSInteger const kSPKGalleryGridColumnsMin;
FOUNDATION_EXPORT NSInteger const kSPKGalleryGridColumnsMax;

/// The persisted, clamped column count (falls back to the default when unset).
FOUNDATION_EXPORT NSInteger SPKGalleryGridColumns(void);
/// Persists a clamped column count.
FOUNDATION_EXPORT void SPKGalleryGridSetColumns(NSInteger columns);
/// Next density toward larger cells (fewer columns) or smaller cells (more).
FOUNDATION_EXPORT NSInteger SPKGalleryGridColumnsAdjacent(NSInteger columns, BOOL largerCells);

NS_ASSUME_NONNULL_END
