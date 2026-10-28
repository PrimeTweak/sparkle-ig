#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, SPKGalleryBiometryType) {
    SPKGalleryBiometryTypeNone = 0,
    SPKGalleryBiometryTypeTouchID,
    SPKGalleryBiometryTypeFaceID,
    SPKGalleryBiometryTypeOther
};

/// Manages the gallery passcode lock and biometric unlock.
///
/// Passcode hashes are stored in the keychain under service
/// `com.sparkle.sparkle.gallery.passcode`, using PBKDF2-HMAC-SHA256 with per-passcode random salt.
/// The lock flag is stored in NSUserDefaults under `gallery_lock`.
@interface SPKGalleryManager : NSObject

+ (instancetype)sharedManager;

/// Whether the gallery lock is enabled. Setting to NO removes the passcode and unlocks the gallery.
@property (nonatomic, assign) BOOL isLockEnabled;

/// Whether the gallery is currently unlocked for this app session.
@property (nonatomic, assign) BOOL isUnlocked;

/// YES if a passcode hash is currently stored in the keychain.
- (BOOL)hasPasscode;

/// Convenience — sets `isUnlocked = NO`.
- (void)lockGallery;

/// Subclass customization points for independent passcode-protected surfaces.
- (NSString *)lockEnabledDefaultsKey;
- (NSString *)keychainService;
- (NSString *)protectedContentName;
- (void)lockContent;

// MARK: - Passcode

/// Stores a new passcode. Passcode length must be between 4 and 6 characters.
/// Also enables the lock.
- (BOOL)setPasscode:(NSString *)passcode;

/// Replaces the stored passcode with a new one, after verifying the old one.
- (BOOL)changePasscodeFromOld:(NSString *)oldPasscode toNew:(NSString *)newPasscode;

/// Returns YES if the passcode matches the stored hash. Sets `isUnlocked = YES` on success.
- (BOOL)verifyPasscode:(NSString *)passcode;

/// Removes the stored passcode hash and disables the lock.
- (void)removePasscode;

// MARK: - Biometrics

- (BOOL)isBiometricsAvailable;
- (SPKGalleryBiometryType)biometryType;

/// Authenticates with biometrics. Calls `completion` on the main queue with success + optional error.
- (void)authenticateWithBiometricsWithCompletion:(void (^)(BOOL success, NSError *_Nullable error))completion;

/// Cancels the active biometric prompt, if any.
- (void)cancelBiometricAuthentication;

@end

NS_ASSUME_NONNULL_END
