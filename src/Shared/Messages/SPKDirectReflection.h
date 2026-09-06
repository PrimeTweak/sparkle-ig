#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Guarded reflection helpers for reading values off IG's Direct model objects.
///
/// Direct's models are heavily obfuscated and reshuffle between IG versions, so
/// everything here returns nil rather than throwing when a name is missing.

/// Reads an ivar by name, walking up the superclass chain.
FOUNDATION_EXPORT id _Nullable SPKDirectIvarValue(id _Nullable object, const char *name);

/// Sends a zero-argument selector looked up by name.
FOUNDATION_EXPORT id _Nullable SPKDirectValueForSelectorNamed(id _Nullable object, NSString *selectorName);

/// `valueForKey:`, with the KVC exception swallowed.
FOUNDATION_EXPORT id _Nullable SPKDirectValueForKey(id _Nullable object, NSString *key);

/// Coerces a value to a non-empty string, or nil.
FOUNDATION_EXPORT NSString *_Nullable SPKDirectStringValue(id _Nullable value);

NS_ASSUME_NONNULL_END
