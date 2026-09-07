/// Modal grid picker that lets the user choose a subset of a carousel's media
/// before running a bulk action (Download All / Copy All). Decoupled from the
/// action-button internals: callers pass lightweight item + destination models
/// and receive back the selected indexes plus the chosen destination.

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// One selectable thumbnail in the grid. Provide either a `thumbnailImage`
/// (preferred when already in memory, e.g. the preview screen) or a
/// `thumbnailURL` (loaded lazily; remote or local file URL).
@interface SPKBulkSelectionItem : NSObject
@property (nonatomic, strong, nullable) NSURL *thumbnailURL;
@property (nonatomic, strong, nullable) UIImage *thumbnailImage;
@property (nonatomic, assign) BOOL isVideo;
+ (instancetype)itemWithThumbnailURL:(nullable NSURL *)thumbnailURL isVideo:(BOOL)isVideo;
+ (instancetype)itemWithThumbnailImage:(nullable UIImage *)thumbnailImage isVideo:(BOOL)isVideo;
@end

/// A bulk destination the user can run the selection through (Photos, Gallery,
/// Share, Clipboard, Copy Links, ...). `identifier` is opaque to this controller
/// and handed straight back through the completion block. `iconName` is a custom
/// asset name, rendered by the picker at its native bottom-bar size.
@interface SPKBulkSelectionDestination : NSObject
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy, nullable) NSString *iconName;
+ (instancetype)destinationWithIdentifier:(NSString *)identifier
                                    title:(NSString *)title
                                 iconName:(nullable NSString *)iconName;
@end

typedef void (^SPKBulkSelectionCompletion)(NSIndexSet *selectedIndexes,
                                           NSString *destinationIdentifier);

@interface SPKBulkMediaSelectionViewController : UIViewController

- (instancetype)initWithItems:(NSArray<SPKBulkSelectionItem *> *)items
                 destinations:(NSArray<SPKBulkSelectionDestination *> *)destinations
                   completion:(SPKBulkSelectionCompletion)completion;

/// Wraps the controller in a styled navigation controller and presents it.
+ (void)presentFromViewController:(nullable UIViewController *)presenter
                            items:(NSArray<SPKBulkSelectionItem *> *)items
                     destinations:(NSArray<SPKBulkSelectionDestination *> *)destinations
                       completion:(SPKBulkSelectionCompletion)completion;

@end

NS_ASSUME_NONNULL_END
