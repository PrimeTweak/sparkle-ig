#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Full-screen, searchable, multi-select picker for the gallery's username filter.
/// Replaces the cramped horizontal chip row so picking several users out of many
/// is practical: a search bar, A–Z sections with a fast-scroll index, and
/// checkmark multi-select. Pushed onto the filter sheet's navigation controller;
/// `selectionChanged` fires live as users are toggled.
@interface SPKGalleryUserPickerViewController : UITableViewController

- (instancetype)initWithUsernames:(NSArray<NSString *> *)usernames
                         selected:(nullable NSSet<NSString *> *)selected;

/// The currently selected usernames (case-insensitive de-duplicated).
@property (nonatomic, readonly) NSSet<NSString *> *selectedUsernames;

/// Invoked whenever the selection changes (toggle or clear-all).
@property (nonatomic, copy, nullable) void (^selectionChanged)(NSSet<NSString *> *selected);

@end

NS_ASSUME_NONNULL_END
