// Shared PK → IGUser resolver. The active IGDirectCacheUpdatesApplicator is
// captured by KeepDeletedMessages's `_applyThreadUpdates:` hook (always
// installed regardless of the keep-deleted pref), so lookups work for any
// feature that lands a senderId.

#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

void spkDirectUserResolverSetActiveApplicator(id applicator);

id _Nullable spkDirectUserResolverUserForPK(NSString *_Nullable pk);
NSString *_Nullable spkDirectUserResolverUsernameForPK(NSString *_Nullable pk);
NSString *_Nullable spkDirectUserResolverProfilePicURLStringForPK(NSString *_Nullable pk);

// IGUser field extraction — KVC-based, exception-safe.
NSString *_Nullable spkDirectUserResolverPKFromUser(id _Nullable user);
NSString *_Nullable spkDirectUserResolverUsernameFromUser(id _Nullable user);
NSString *_Nullable spkDirectUserResolverProfilePicURLStringFromUser(id _Nullable user);

#ifdef __cplusplus
}
#endif
