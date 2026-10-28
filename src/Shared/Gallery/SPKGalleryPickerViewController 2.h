#import <UIKit/UIKit.h>

@class SPKGalleryFile;

NS_ASSUME_NONNULL_BEGIN

typedef void (^SPKGalleryPickerCompletion)(NSArray<SPKGalleryFile *> *selectedFiles);

/// Posted on the main queue once a presented picker has been dismissed for good.
/// Surfaces that put the picker on top of live content (the story editor, which
/// stays mounted because IG presents its tray overFullScreen) use this to undo
/// whatever they did to quiet that content on the way in.
FOUNDATION_EXPORT NSNotificationName const SPKGalleryPickerDidDismissNotification;

@interface SPKGalleryPickerViewController : UIViewController

+ (BOOL)hasSelectableFilesForAllowedMediaTypes:(nullable NSSet<NSNumber *> *)allowedMediaTypes;

+ (void)presentFromViewController:(UIViewController *)presenter
                            title:(nullable NSString *)title
                allowedMediaTypes:(nullable NSSet<NSNumber *> *)allowedMediaTypes
          allowsMultipleSelection:(BOOL)allowsMultipleSelection
                       completion:(SPKGalleryPickerCompletion)completion;

- (instancetype)initWithTitle:(nullable NSString *)title
            allowedMediaTypes:(nullable NSSet<NSNumber *> *)allowedMediaTypes
      allowsMultipleSelection:(BOOL)allowsMultipleSelection
                   completion:(SPKGalleryPickerCompletion)completion;

- (instancetype)initWithFolderPath:(nullable NSString *)folderPath
                             title:(nullable NSString *)title
                 allowedMediaTypes:(nullable NSSet<NSNumber *> *)allowedMediaTypes
           allowsMultipleSelection:(BOOL)allowsMultipleSelection
                        completion:(SPKGalleryPickerCompletion)completion;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
