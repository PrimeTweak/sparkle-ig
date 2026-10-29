#import "../Gallery/SPKGalleryManager.h"

NS_ASSUME_NONNULL_BEGIN

/// Passcode or biometric lock over revealing hidden chats, with its own keychain record.
/// Device wide rather than per account, since the account switcher cannot scope a reveal.
@interface SPKDirectHiddenChatsLockManager : SPKGalleryManager

+ (instancetype)sharedManager;

/// YES when a reveal has to pass authentication first.
- (BOOL)requiresAuthentication;

@end

NS_ASSUME_NONNULL_END
