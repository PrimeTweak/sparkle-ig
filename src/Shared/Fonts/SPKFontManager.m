#import "SPKStrings.h"
#import "SPKFontManager.h"

#import <CoreText/CoreText.h>
#import <os/lock.h>

#import "../../Utils.h"
#import "../SPKStoragePaths.h"

NSString *const kSPKPrefInterfaceCustomFont = @"interface_custom_font";

static NSString *const kSPKFontErrorDomain = @"com.sparkle.fonts";

typedef NS_ENUM(NSInteger, SPKFontError) {
    SPKFontErrorUnreadable = 1,
    SPKFontErrorNotAFont,
    SPKFontErrorAlreadyImported,
    SPKFontErrorRegistrationFailed,
    SPKFontErrorCopyFailed,
};

static NSError *SPKFontMakeError(SPKFontError code, NSString *message) {
    return [NSError errorWithDomain:kSPKFontErrorDomain
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey : message ?: SPKL(@"FONT_ERROR_UNKNOWN")}];
}

@implementation SPKFontFile
@end

@implementation SPKFontFace
@end

#pragma mark - Cached state

// The active family is read on every single font lookup once the feature is on,
// so it is held in a static rather than re-read from NSUserDefaults each time.
// `spk_activeFamilyLoaded` distinguishes "no font selected" from "not yet read".
//
// Text lays out on more than the main thread, so every access to this state is
// taken under `spk_stateLock`. It is uncontended in practice and the lookup
// already takes NSCache's own lock, so the cost is nothing next to shaping text.
static os_unfair_lock spk_stateLock = OS_UNFAIR_LOCK_INIT;
static NSString *spk_activeFamily = nil;
static BOOL spk_activeFamilyLoaded = NO;
static NSCache<NSString *, UIFont *> *spk_fontCache = nil;
// Families that are installed right now. Rebuilt on registration and after an
// import or delete, so a stale preference naming a deleted family reads as off.
static NSSet<NSString *> *spk_installedFamilies = nil;
// family -> the faces it ships, with their traits already read out of Core Text.
// Without this every cache miss re-created a CTFont per face just to ask its
// weight, and a miss happens for each new point size the app asks for.
static NSMutableDictionary<NSString *, NSArray<NSDictionary *> *> *spk_faceIndex = nil;

static NSCache<NSString *, UIFont *> *SPKFontCache(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        spk_fontCache = [[NSCache alloc] init];
        spk_fontCache.countLimit = 256;
    });
    return spk_fontCache;
}

static void SPKFontInvalidateCaches(void) {
    [SPKFontCache() removeAllObjects];
    os_unfair_lock_lock(&spk_stateLock);
    spk_activeFamilyLoaded = NO;
    spk_activeFamily = nil;
    [spk_faceIndex removeAllObjects];
    os_unfair_lock_unlock(&spk_stateLock);
}

#pragma mark - Font file inspection

/// Family + PostScript name of the first face in a font file, read without
/// registering it. Nil when the file is not a font Core Text can parse.
static BOOL SPKFontInspectFile(NSURL *url, NSString **outFamily, NSString **outPostScript) {
    NSArray *descriptors = CFBridgingRelease(CTFontManagerCreateFontDescriptorsFromURL((__bridge CFURLRef)url));
    if (descriptors.count == 0)
        return NO;

    CTFontDescriptorRef descriptor = (__bridge CTFontDescriptorRef)descriptors.firstObject;
    NSString *family = CFBridgingRelease(CTFontDescriptorCopyAttribute(descriptor, kCTFontFamilyNameAttribute));
    NSString *postScript = CFBridgingRelease(CTFontDescriptorCopyAttribute(descriptor, kCTFontNameAttribute));
    if (family.length == 0)
        return NO;

    if (outFamily)
        *outFamily = family;
    if (outPostScript)
        *outPostScript = postScript;
    return YES;
}

static BOOL SPKFontPathHasFontExtension(NSString *path) {
    NSString *extension = path.pathExtension.lowercaseString;
    return [extension isEqualToString:@"otf"] || [extension isEqualToString:@"ttf"] ||
           [extension isEqualToString:@"ttc"] || [extension isEqualToString:@"otc"];
}

#pragma mark - Weight matching

/// A readable style name for a face whose file declares none, so the picker never
/// shows a blank label. Deliberately coarse: it only has the weight to go on.
/// Called when a face is displayed, never while resolving a font.
static NSString *SPKFontDerivedStyleName(CGFloat weight, BOOL italic) {
    // Regular is tracked separately because its italic form is just "Italic", not
    // "Regular Italic". Comparing the resolved (localized) name would break that.
    BOOL isRegular = NO;
    NSString *name;
    if (weight <= -0.6)
        name = SPKL(@"FONT_STYLE_ULTRA_LIGHT");
    else if (weight <= -0.35)
        name = SPKL(@"FONT_STYLE_THIN");
    else if (weight <= -0.15)
        name = SPKL(@"FONT_STYLE_LIGHT");
    else if (weight <= 0.1) {
        name = SPKL(@"FONT_STYLE_REGULAR");
        isRegular = YES;
    } else if (weight <= 0.25)
        name = SPKL(@"FONT_STYLE_MEDIUM");
    else if (weight <= 0.35)
        name = SPKL(@"FONT_STYLE_SEMIBOLD");
    else if (weight <= 0.5)
        name = SPKL(@"FONT_STYLE_BOLD");
    else if (weight <= 0.6)
        name = SPKL(@"FONT_STYLE_HEAVY");
    else
        name = SPKL(@"FONT_STYLE_BLACK");

    if (!italic)
        return name;
    return isRegular ? SPKL(@"FONT_STYLE_ITALIC") : [NSString stringWithFormat:SPKL(@"FONT_STYLE_ITALIC_VARIANT_FORMAT"), name];
}

/// Normalized weight (-1…1), slant, and declared style name of a registered face,
/// straight from Core Text. UIFontDescriptor's traits dictionary is empty for a
/// font built with `fontWithName:size:`, so it cannot be used here.
static void SPKFontTraitsForName(NSString *postScriptName, CGFloat *outWeight, BOOL *outItalic, NSString **outStyle) {
    CGFloat weight = 0.0;
    BOOL italic = NO;
    NSString *style = nil;

    CTFontRef font = CTFontCreateWithName((__bridge CFStringRef)postScriptName, 12.0, NULL);
    if (font) {
        NSDictionary *traits = CFBridgingRelease(CTFontCopyTraits(font));
        NSNumber *weightValue = traits[(__bridge NSString *)kCTFontWeightTrait];
        if (weightValue)
            weight = weightValue.doubleValue;

        NSNumber *symbolic = traits[(__bridge NSString *)kCTFontSymbolicTrait];
        italic = (symbolic.unsignedIntValue & kCTFontTraitItalic) != 0;
        if (!italic) {
            NSNumber *slant = traits[(__bridge NSString *)kCTFontSlantTrait];
            italic = slant.doubleValue > 0.01;
        }
        style = CFBridgingRelease(CTFontCopyName(font, kCTFontStyleNameKey));
        CFRelease(font);
    }

    if (outWeight)
        *outWeight = weight;
    if (outItalic)
        *outItalic = italic;
    if (outStyle)
        *outStyle = style.length > 0 ? style : nil;
}

/// The faces of `family` with their traits, read from Core Text once and kept.
/// Each entry is @{@"name", @"weight", @"italic", @"style"}, where "style" is the
/// name the file declares or an empty string when it declares none. Nothing here
/// is localized: this index is built from inside the app-wide UIFont hook, so a
/// string lookup on this path would re-enter font resolution, and the cache would
/// otherwise keep whatever language was active when the family was first used.
static NSArray<NSDictionary *> *SPKFontFacesForFamily(NSString *family) {
    os_unfair_lock_lock(&spk_stateLock);
    NSArray<NSDictionary *> *cached = spk_faceIndex[family];
    os_unfair_lock_unlock(&spk_stateLock);
    if (cached)
        return cached;

    NSArray<NSString *> *names = [UIFont fontNamesForFamilyName:family];
    NSMutableArray<NSDictionary *> *faces = [NSMutableArray arrayWithCapacity:names.count];
    for (NSString *name in names) {
        CGFloat faceWeight = 0.0;
        BOOL faceItalic = NO;
        NSString *faceStyle = nil;
        SPKFontTraitsForName(name, &faceWeight, &faceItalic, &faceStyle);
        [faces addObject:@{
            @"name" : name,
            @"weight" : @(faceWeight),
            @"italic" : @(faceItalic),
            @"style" : faceStyle ?: @"",
        }];
    }

    os_unfair_lock_lock(&spk_stateLock);
    if (!spk_faceIndex)
        spk_faceIndex = [NSMutableDictionary dictionary];
    spk_faceIndex[family] = faces;
    os_unfair_lock_unlock(&spk_stateLock);
    return faces;
}

/// Face of `family` closest to `weight`. Faces whose italic-ness matches the
/// request win outright, so a family that ships an italic never has it selected
/// for upright text just because its weight happens to be nearer.
static NSString *SPKFontBestFaceInFamily(NSString *family, CGFloat weight, BOOL italic) {
    NSArray<NSDictionary *> *faces = SPKFontFacesForFamily(family);
    if (faces.count == 0)
        return nil;

    NSString *bestName = nil;
    CGFloat bestScore = CGFLOAT_MAX;
    for (NSDictionary *face in faces) {
        CGFloat faceWeight = [face[@"weight"] doubleValue];
        BOOL faceItalic = [face[@"italic"] boolValue];

        // The italic penalty exceeds the widest possible weight distance (2.0),
        // which makes the slant match strictly dominant over the weight match.
        CGFloat score = fabs(faceWeight - weight) + (faceItalic == italic ? 0.0 : 4.0);
        if (score < bestScore) {
            bestScore = score;
            bestName = face[@"name"];
        }
    }
    return bestName;
}

#pragma mark -

@implementation SPKFontManager

+ (NSString *)fontsDirectory {
    return [SPKStoragePaths fontsDirectory];
}

#pragma mark - Registration

+ (void)registerImportedFonts {
    NSString *directory = [self fontsDirectory];
    NSArray<NSString *> *entries = [NSFileManager.defaultManager contentsOfDirectoryAtPath:directory error:nil];
    NSMutableSet<NSString *> *families = [NSMutableSet set];

    for (NSString *entry in entries) {
        if (!SPKFontPathHasFontExtension(entry))
            continue;

        NSURL *url = [NSURL fileURLWithPath:[directory stringByAppendingPathComponent:entry]];
        NSString *family = nil;
        if (!SPKFontInspectFile(url, &family, NULL)) {
            SPKWarnLog(@"Fonts", @"Skipping unreadable font file %@", entry);
            continue;
        }

        CFErrorRef error = NULL;
        // Already-registered files report kCTFontManagerErrorAlreadyRegistered,
        // which is success as far as callers are concerned -- this method is
        // deliberately idempotent so it can run again after every import.
        if (!CTFontManagerRegisterFontsForURL((__bridge CFURLRef)url, kCTFontManagerScopeProcess, &error)) {
            CFIndex code = error ? CFErrorGetCode(error) : 0;
            if (code != kCTFontManagerErrorAlreadyRegistered)
                SPKWarnLog(@"Fonts", @"Failed to register %@ (code %ld)", entry, (long)code);
        }
        if (error)
            CFRelease(error);

        [families addObject:family];
    }

    spk_installedFamilies = families;
    SPKFontInvalidateCaches();
}

+ (NSSet<NSString *> *)installedFamiliesRegisteringIfNeeded {
    if (!spk_installedFamilies)
        [self registerImportedFonts];
    return spk_installedFamilies ?: [NSSet set];
}

#pragma mark - Listing

+ (NSArray<SPKFontFile *> *)importedFonts {
    [self registerImportedFonts];

    NSString *directory = [self fontsDirectory];
    NSArray<NSString *> *entries = [NSFileManager.defaultManager contentsOfDirectoryAtPath:directory error:nil];
    NSMutableArray<SPKFontFile *> *files = [NSMutableArray array];

    for (NSString *entry in entries) {
        if (!SPKFontPathHasFontExtension(entry))
            continue;

        NSString *path = [directory stringByAppendingPathComponent:entry];
        NSString *family = nil;
        NSString *postScript = nil;
        SPKFontInspectFile([NSURL fileURLWithPath:path], &family, &postScript);

        SPKFontFile *file = [[SPKFontFile alloc] init];
        file.fileName = entry;
        file.familyName = family;
        file.postScriptName = postScript;
        file.byteSize = [NSFileManager.defaultManager attributesOfItemAtPath:path error:nil].fileSize;
        [files addObject:file];
    }

    [files sortUsingComparator:^NSComparisonResult(SPKFontFile *lhs, SPKFontFile *rhs) {
        NSComparisonResult byFamily = [(lhs.familyName ?: @"") localizedCaseInsensitiveCompare:rhs.familyName ?: @""];
        if (byFamily != NSOrderedSame)
            return byFamily;
        return [lhs.fileName localizedCaseInsensitiveCompare:rhs.fileName];
    }];
    return files;
}

+ (NSArray<NSString *> *)importedFamilyNames {
    NSMutableOrderedSet<NSString *> *families = [NSMutableOrderedSet orderedSet];
    for (SPKFontFile *file in [self importedFonts]) {
        if (file.familyName.length > 0)
            [families addObject:file.familyName];
    }
    [families sortUsingComparator:^NSComparisonResult(NSString *lhs, NSString *rhs) {
        return [lhs localizedCaseInsensitiveCompare:rhs];
    }];
    return families.array;
}

+ (NSArray<SPKFontFace *> *)facesInFamily:(NSString *)familyName {
    if (familyName.length == 0)
        return @[];
    [self installedFamiliesRegisteringIfNeeded];

    NSMutableArray<SPKFontFace *> *faces = [NSMutableArray array];
    for (NSDictionary *entry in SPKFontFacesForFamily(familyName)) {
        SPKFontFace *face = [[SPKFontFace alloc] init];
        face.postScriptName = entry[@"name"];
        face.weight = [entry[@"weight"] doubleValue];
        face.italic = [entry[@"italic"] boolValue];
        NSString *declaredStyle = entry[@"style"];
        face.styleName = declaredStyle.length > 0 ? declaredStyle : SPKFontDerivedStyleName(face.weight, face.italic);
        [faces addObject:face];
    }

    [faces sortUsingComparator:^NSComparisonResult(SPKFontFace *lhs, SPKFontFace *rhs) {
        if (lhs.italic != rhs.italic)
            return lhs.italic ? NSOrderedDescending : NSOrderedAscending;
        if (lhs.weight != rhs.weight)
            return lhs.weight < rhs.weight ? NSOrderedAscending : NSOrderedDescending;
        return [lhs.postScriptName localizedCaseInsensitiveCompare:rhs.postScriptName];
    }];
    return faces;
}

#pragma mark - Import & delete

+ (SPKFontFile *)importFontAtURL:(NSURL *)url error:(NSError **)error {
    // Files handed over by the document picker live outside the sandbox until
    // they are copied, so the security scope has to be held for the whole read.
    BOOL scoped = [url startAccessingSecurityScopedResource];
    @try {
        if (!SPKFontPathHasFontExtension(url.path)) {
            if (error)
                *error = SPKFontMakeError(SPKFontErrorNotAFont, SPKL(@"FONT_ERROR_NOT_A_FONT"));
            return nil;
        }

        NSString *family = nil;
        NSString *postScript = nil;
        if (!SPKFontInspectFile(url, &family, &postScript)) {
            if (error)
                *error = SPKFontMakeError(SPKFontErrorNotAFont, SPKL(@"FONT_ERROR_UNPARSEABLE"));
            return nil;
        }

        NSString *directory = [self fontsDirectory];
        NSString *fileName = url.lastPathComponent;
        NSString *destination = [directory stringByAppendingPathComponent:fileName];
        if ([NSFileManager.defaultManager fileExistsAtPath:destination]) {
            if (error)
                *error = SPKFontMakeError(SPKFontErrorAlreadyImported,
                                          [NSString stringWithFormat:SPKL(@"FONT_ERROR_ALREADY_IMPORTED_FORMAT"), fileName]);
            return nil;
        }

        NSError *copyError = nil;
        if (![NSFileManager.defaultManager copyItemAtPath:url.path toPath:destination error:&copyError]) {
            if (error)
                *error = SPKFontMakeError(SPKFontErrorCopyFailed, copyError.localizedDescription);
            return nil;
        }

        CFErrorRef registerError = NULL;
        NSURL *destinationURL = [NSURL fileURLWithPath:destination];
        BOOL registered = CTFontManagerRegisterFontsForURL((__bridge CFURLRef)destinationURL,
                                                           kCTFontManagerScopeProcess, &registerError);
        CFIndex code = registerError ? CFErrorGetCode(registerError) : 0;
        if (registerError)
            CFRelease(registerError);

        if (!registered && code != kCTFontManagerErrorAlreadyRegistered) {
            // Leaving an unusable file behind would keep failing on every
            // launch, so back the copy out.
            [NSFileManager.defaultManager removeItemAtPath:destination error:nil];
            if (error)
                *error = SPKFontMakeError(SPKFontErrorRegistrationFailed,
                                          SPKL(@"FONT_ERROR_REGISTRATION_FAILED"));
            return nil;
        }

        SPKFontFile *file = [[SPKFontFile alloc] init];
        file.fileName = fileName;
        file.familyName = family;
        file.postScriptName = postScript;
        file.byteSize = [NSFileManager.defaultManager attributesOfItemAtPath:destination error:nil].fileSize;

        spk_installedFamilies = nil;
        SPKFontInvalidateCaches();
        SPKLog(@"Fonts", @"Imported %@ (family %@)", fileName, family);
        return file;
    } @finally {
        if (scoped)
            [url stopAccessingSecurityScopedResource];
    }
}

+ (BOOL)removeFontFile:(SPKFontFile *)file error:(NSError **)error {
    NSString *path = [[self fontsDirectory] stringByAppendingPathComponent:file.fileName];
    NSURL *url = [NSURL fileURLWithPath:path];

    CFErrorRef unregisterError = NULL;
    CTFontManagerUnregisterFontsForURL((__bridge CFURLRef)url, kCTFontManagerScopeProcess, &unregisterError);
    if (unregisterError)
        CFRelease(unregisterError);

    NSError *removeError = nil;
    if (![NSFileManager.defaultManager removeItemAtPath:path error:&removeError]) {
        if (error)
            *error = removeError;
        return NO;
    }

    spk_installedFamilies = nil;
    SPKFontInvalidateCaches();

    // Another file may still provide the same family (a family is usually split
    // across one file per weight), so only drop the selection once the family
    // has genuinely gone.
    NSString *selected = SPKPreferenceObjectForKey(kSPKPrefInterfaceCustomFont);
    if ([selected isKindOfClass:[NSString class]] && selected.length > 0) {
        if (![[self installedFamiliesRegisteringIfNeeded] containsObject:selected])
            [self setSelectedFamilyName:nil];
    }

    SPKLog(@"Fonts", @"Removed font file %@", file.fileName);
    return YES;
}

#pragma mark - Selection

+ (NSString *)selectedFamilyName {
    os_unfair_lock_lock(&spk_stateLock);
    BOOL loaded = spk_activeFamilyLoaded;
    NSString *family = spk_activeFamily;
    os_unfair_lock_unlock(&spk_stateLock);
    if (loaded)
        return family;

    // Resolved outside the lock: registration touches the file system, and it
    // re-enters SPKFontInvalidateCaches, which takes the same lock.
    NSString *resolved = nil;
    NSString *stored = SPKPreferenceObjectForKey(kSPKPrefInterfaceCustomFont);
    if ([stored isKindOfClass:[NSString class]] && stored.length > 0) {
        if ([[self installedFamiliesRegisteringIfNeeded] containsObject:stored]) {
            resolved = stored;
        } else {
            // The file backing the preference is gone (deleted outside Sparkle,
            // or the import was rolled back). Fall back rather than resolving
            // every lookup against a family that no longer exists.
            SPKWarnLog(@"Fonts", @"Selected family %@ is not installed, using the default font", stored);
        }
    }

    os_unfair_lock_lock(&spk_stateLock);
    spk_activeFamily = resolved;
    spk_activeFamilyLoaded = YES;
    os_unfair_lock_unlock(&spk_stateLock);
    return resolved;
}

+ (void)setSelectedFamilyName:(NSString *)familyName {
    SPKPreferenceSetObject(familyName.length > 0 ? familyName : @"", kSPKPrefInterfaceCustomFont);
    SPKFontInvalidateCaches();
}

+ (BOOL)isActive {
    return [self selectedFamilyName].length > 0;
}

#pragma mark - Resolution

+ (UIFont *)fontOfSize:(CGFloat)size weight:(UIFontWeight)weight italic:(BOOL)italic {
    NSString *family = [self selectedFamilyName];
    if (family.length == 0)
        return nil;
    return [self fontInFamily:family size:size weight:weight italic:italic];
}

+ (UIFont *)fontInFamily:(NSString *)family size:(CGFloat)size weight:(UIFontWeight)weight italic:(BOOL)italic {
    if (family.length == 0)
        return nil;
    // Sizes arrive from layout code and can carry fractional noise, which would
    // make the cache miss constantly. Rounding to a tenth of a point keys the
    // cache tightly without any visible difference.
    CGFloat roundedSize = round(size * 10.0) / 10.0;
    NSString *key = [NSString stringWithFormat:@"%@|%.1f|%.2f|%d", family, roundedSize, (double)weight, italic];

    UIFont *cached = [SPKFontCache() objectForKey:key];
    if (cached)
        return cached;

    NSString *faceName = SPKFontBestFaceInFamily(family, weight, italic);
    if (faceName.length == 0)
        return nil;

    UIFont *font = [UIFont fontWithName:faceName size:roundedSize];
    if (!font)
        return nil;

    [SPKFontCache() setObject:font forKey:key];
    return font;
}

@end
