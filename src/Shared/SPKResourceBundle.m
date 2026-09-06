#import "SPKResourceBundle.h"
#import <dlfcn.h>

static NSString *SPKDylibDirectory(void) {
    Dl_info info;
    if (dladdr((const void *)SPKResourceBundle, &info) && info.dli_fname) {
        return [[NSString stringWithUTF8String:info.dli_fname] stringByDeletingLastPathComponent];
    }
    return nil;
}

static NSArray<NSString *> *SPKResourceBundleCandidates(void) {
    static NSArray<NSString *> *candidates;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSMutableOrderedSet<NSString *> *paths = [NSMutableOrderedSet orderedSet];
        [paths addObject:@"/var/jb/Library/Application Support/Sparkle.bundle"];
        [paths addObject:@"/Library/Application Support/Sparkle.bundle"];

        NSString *dylibDirectory = SPKDylibDirectory();
        if (dylibDirectory.length > 0) {
            [paths addObject:[dylibDirectory stringByAppendingPathComponent:@"Sparkle.bundle"]];
            [paths addObject:[[dylibDirectory stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"Sparkle.bundle"]];
        }

        NSString *appPath = NSBundle.mainBundle.bundlePath;
        if (appPath.length > 0) {
            [paths addObject:[appPath stringByAppendingPathComponent:@"Sparkle.bundle"]];
            [paths addObject:[appPath stringByAppendingPathComponent:@"Frameworks/Sparkle.bundle"]];
        }
        candidates = paths.array;
    });
    return candidates;
}

// Resolution is per resource, not per bundle. A development install can carry a
// small sibling bundle holding only the localizations while the app-root bundle
// still provides the FFmpeg frameworks, and each resource has to resolve against
// the first bundle that actually contains it.
static NSString *SPKResourceRootContaining(NSString *relativePath) {
    NSFileManager *fileManager = NSFileManager.defaultManager;
    NSString *firstExistingRoot = nil;
    for (NSString *path in SPKResourceBundleCandidates()) {
        BOOL isDirectory = NO;
        if (!([fileManager fileExistsAtPath:path isDirectory:&isDirectory] && isDirectory))
            continue;
        if (!firstExistingRoot)
            firstExistingRoot = path;
        if (relativePath.length == 0)
            return path;
        if ([fileManager fileExistsAtPath:[path stringByAppendingPathComponent:relativePath]])
            return path;
    }
    // No bundle carries the resource, so report it against a bundle that exists.
    return firstExistingRoot;
}

NSBundle *SPKResourceBundle(void) {
    static NSBundle *bundle;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // English always ships, so it identifies the bundle holding the catalogs.
        NSString *root = SPKResourceRootContaining(@"en.lproj");
        if (root.length > 0)
            bundle = [NSBundle bundleWithPath:root];
    });
    return bundle;
}

NSString *SPKResourceBundlePath(void) {
    return SPKResourceBundle().bundlePath;
}

NSString *SPKResourcePath(NSString *relativePath) {
    if (relativePath.length == 0)
        return SPKResourceBundlePath();
    NSString *root = SPKResourceRootContaining(relativePath);
    return root.length > 0 ? [root stringByAppendingPathComponent:relativePath] : nil;
}
