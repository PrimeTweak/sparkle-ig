#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class SPKGalleryManager;

typedef NS_ENUM(NSInteger, SPKGalleryLockMode) {
    SPKGalleryLockModeUnlock = 0,     // Verify the existing passcode.
    SPKGalleryLockModeSetPasscode,    // Enter + confirm a new passcode.
    SPKGalleryLockModeChangePasscode, // Verify old + enter + confirm a new passcode.
};

/// Modal 4-6 digit passcode keypad used to unlock the gallery or set/change the passcode.
@interface SPKGalleryLockViewController : UIViewController

@property (nonatomic, assign) SPKGalleryLockMode mode;

/// Called with YES when the user successfully completes the flow, NO if cancelled.
@property (nonatomic, copy, nullable) void (^completion)(BOOL success);

/// Presents the unlock flow, trying biometrics first if available, otherwise the passcode keypad.
+ (void)presentUnlockFromViewController:(UIViewController *)presenter
                             completion:(void (^)(BOOL success))completion;

/// Presents the passcode keypad for the given mode.
+ (void)presentMode:(SPKGalleryLockMode)mode
    fromViewController:(UIViewController *)presenter
            completion:(void (^)(BOOL success))completion;

/// Reuses the keypad for another independent passcode manager, such as Settings.
+ (void)presentUnlockForManager:(SPKGalleryManager *)manager
             fromViewController:(UIViewController *)presenter
                     completion:(void (^)(BOOL success))completion;

+ (void)presentMode:(SPKGalleryLockMode)mode
            forManager:(SPKGalleryManager *)manager
    fromViewController:(UIViewController *)presenter
            completion:(void (^)(BOOL success))completion;

@end

NS_ASSUME_NONNULL_END
