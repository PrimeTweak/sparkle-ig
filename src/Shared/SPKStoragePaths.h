#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SPKStoragePaths : NSObject

+ (NSString *)galleryDirectory;
+ (NSString *)deletedMessagesDirectory;
+ (NSString *)deletedMessagesPendingDirectory;
+ (NSString *)profileAnalyzerDirectory;
+ (NSString *)downloadsDirectory;
// App-wide profile-picture cache shared across features (Profile Analyzer,
// Deleted Messages, ...). Keyed by user PK; regenerable, safe to clear.
+ (NSString *)avatarCacheDirectory;

// Total bytes of regular files under `path` (recursive). 0 if missing.
+ (unsigned long long)sizeOfDirectory:(NSString *)path;
// Labeled byte counts for each Sparkle data store plus a @"total" entry.
+ (NSDictionary<NSString *, NSNumber *> *)storageBreakdown;

+ (NSString *)fontsDirectory;
+ (NSString *)languagePacksDirectory;
@end

NS_ASSUME_NONNULL_END
