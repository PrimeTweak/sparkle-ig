#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Sparkle's resource bundle in rootless, rootful, sideloaded, and development
/// layouts. The result is cached after the first successful lookup.
FOUNDATION_EXPORT NSBundle *_Nullable SPKResourceBundle(void);
FOUNDATION_EXPORT NSString *_Nullable SPKResourceBundlePath(void);
FOUNDATION_EXPORT NSString *_Nullable SPKResourcePath(NSString *relativePath);

NS_ASSUME_NONNULL_END
