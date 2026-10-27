#import "SPKGalleryGridDensity.h"

NSString *const kSPKGalleryGridColumnsKey = @"gallery_grid_columns";
NSString *const kSPKGalleryGridPinchDisabledKey = @"gallery_grid_pinch_disabled";
NSString *const kSPKGalleryGridShowSourceUsernameDisabledKey = @"gallery_grid_show_source_username_disabled";
NSString *const kSPKGalleryFolderBarPinDisabledKey = @"gallery_folder_bar_pin_disabled";
NSString *const kSPKGalleryFlatBrowsingKey = @"gallery_flat_browsing";
NSString *const kSPKGalleryGridControlsChangedNotification = @"SPKGalleryGridControlsPreferenceChanged";
NSString *const kSPKGalleryBrowsingScopeChangedNotification = @"SPKGalleryBrowsingScopePreferenceChanged";

BOOL SPKGalleryFolderBarPinned(void) {
    return ![[NSUserDefaults standardUserDefaults] boolForKey:kSPKGalleryFolderBarPinDisabledKey];
}

NSInteger const kSPKGalleryGridColumnsDefault = 3;
NSInteger const kSPKGalleryGridColumnsMin = 2;
NSInteger const kSPKGalleryGridColumnsMax = 5;

// Allowed densities, clamped from pinch.
static NSInteger const kColumnChoices[] = {2, 3, 5};
static NSUInteger const kColumnChoicesCount = sizeof(kColumnChoices) / sizeof(kColumnChoices[0]);

static NSInteger SPKClampColumns(NSInteger columns) {
    return MAX(kSPKGalleryGridColumnsMin, MIN(kSPKGalleryGridColumnsMax, columns));
}

NSInteger SPKGalleryGridColumns(void) {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    NSInteger stored = [d objectForKey:kSPKGalleryGridColumnsKey] ? [d integerForKey:kSPKGalleryGridColumnsKey] : kSPKGalleryGridColumnsDefault;
    return SPKClampColumns(stored);
}

void SPKGalleryGridSetColumns(NSInteger columns) {
    [[NSUserDefaults standardUserDefaults] setInteger:SPKClampColumns(columns) forKey:kSPKGalleryGridColumnsKey];
}

static NSUInteger SPKColumnChoiceIndex(NSInteger columns) {
    for (NSUInteger i = 0; i < kColumnChoicesCount; i++) {
        if (kColumnChoices[i] == columns)
            return i;
    }
    return 1; // default to the index of "3"
}

NSInteger SPKGalleryGridColumnsAdjacent(NSInteger columns, BOOL largerCells) {
    NSUInteger index = SPKColumnChoiceIndex(columns);
    if (largerCells) {
        // Fewer columns -> larger cells.
        return index > 0 ? kColumnChoices[index - 1] : columns;
    }
    return index + 1 < kColumnChoicesCount ? kColumnChoices[index + 1] : columns;
}
