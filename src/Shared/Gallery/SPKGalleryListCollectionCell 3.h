#import <UIKit/UIKit.h>

@class SPKGalleryFile;

NS_ASSUME_NONNULL_BEGIN

/// List-style row for use inside a collection view (do not use UITableViewCell here).
@interface SPKGalleryListCollectionCell : UICollectionViewCell

- (void)configureWithGalleryFile:(SPKGalleryFile *)file
                   selectionMode:(BOOL)selectionMode
                        selected:(BOOL)selected;

- (void)setSelectionMode:(BOOL)selectionMode selected:(BOOL)selected animated:(BOOL)animated;

/// Appends the file's folder name to the technical line when searching across all
/// folders, so a result's location is visible. Pass `nil` to show the plain line.
- (void)setFolderContextName:(nullable NSString *)folderName;

/// Same actions as long-press context menu on the row. Pass `nil` to clear (e.g. in `prepareForReuse`).
- (void)setMoreActionsMenu:(nullable UIMenu *)menu;

@end

NS_ASSUME_NONNULL_END
