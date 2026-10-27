#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SPKGalleryViewController : UIViewController

+ (void)presentGallery;

/// A gallery with a filter already applied, ready to be pushed. Pass empty/nil sets to
/// leave that dimension unfiltered. The filter is seeded before the first fetch, so the
/// gallery opens straight into it and the user can still change it from the filter sheet.
/// Pushed rather than presented, the leading bar button becomes a back chevron.
/// @param title Replaces the usual "Gallery" title (pass nil to keep it), so a filtered
/// screen can say what it is filtered to.
+ (instancetype)galleryFilteredToSources:(nullable NSSet<NSNumber *> *)sources
                               usernames:(nullable NSSet<NSString *> *)usernames
                                   title:(nullable NSString *)title;

/// Initializes the gallery for browsing the given folder path. Pass nil for root.
- (instancetype)initWithFolderPath:(nullable NSString *)folderPath;

@end

NS_ASSUME_NONNULL_END
