#import "SPKLanguagePack.h"
#import "SPKStrings.h"
#import "../SPKResourceBundle.h"
#import "../SPKStoragePaths.h"
#import "../../Settings/SPKSettingsTransferManager.h"
#import "../../Utils.h"

NSString *const SPKLanguagePackErrorDomain = @"com.sparkle.languagepacks";
static NSString *const kSPKCatalogFileName = @"Localizable.strings";
static NSString *const kSPKPluralFileName = @"Localizable.stringsdict";

static NSError *SPKLanguagePackMakeError(SPKLanguagePackErrorCode code, NSString *message) {
    return [NSError errorWithDomain:SPKLanguagePackErrorDomain
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey : message ?: @""}];
}

// A code becomes a path component, so anything but a plain locale identifier is
// rejected outright rather than sanitized.
BOOL SPKLanguageCodeIsWellFormed(NSString *code) {
    if (code.length == 0 || code.length > 20)
        return NO;
    static NSCharacterSet *disallowed;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSMutableCharacterSet *allowed = [NSMutableCharacterSet alphanumericCharacterSet];
        [allowed addCharactersInString:@"-_"];
        disallowed = [allowed invertedSet];
    });
    if ([code rangeOfCharacterFromSet:disallowed].location != NSNotFound)
        return NO;
    // "-Hans" or "de-" is a typo, not a locale, and "en" needs a letter first.
    return [[NSCharacterSet letterCharacterSet] characterIsMember:[code characterAtIndex:0]];
}

NSString *SPKLanguagePacksDirectory(void) {
    return [SPKStoragePaths languagePacksDirectory];
}

// Reads resolve the path without creating it. String lookup runs before the first
// view exists and asks which languages are installed, so the read path must not
// touch the file system beyond the question it was asked.
static NSString *SPKLanguagePacksRoot(void) {
    NSString *documents = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    return [documents stringByAppendingPathComponent:@"Sparkle/Languages"];
}

NSString *SPKLanguagePackPathForCode(NSString *code) {
    if (!SPKLanguageCodeIsWellFormed(code))
        return nil;
    NSString *path = [SPKLanguagePacksRoot() stringByAppendingPathComponent:
                                                      [code stringByAppendingPathExtension:@"lproj"]];
    BOOL isDirectory = NO;
    if (![NSFileManager.defaultManager fileExistsAtPath:path isDirectory:&isDirectory] || !isDirectory)
        return nil;
    return [NSFileManager.defaultManager fileExistsAtPath:[path stringByAppendingPathComponent:kSPKCatalogFileName]]
               ? path
               : nil;
}

NSArray<NSString *> *SPKInstalledLanguagePackCodes(void) {
    NSArray<NSString *> *entries = [NSFileManager.defaultManager contentsOfDirectoryAtPath:SPKLanguagePacksRoot()
                                                                                     error:nil];
    NSMutableArray<NSString *> *codes = [NSMutableArray array];
    for (NSString *entry in entries) {
        if (![entry.pathExtension isEqualToString:@"lproj"])
            continue;
        NSString *code = entry.stringByDeletingPathExtension;
        if (SPKLanguagePackPathForCode(code))
            [codes addObject:code];
    }
    [codes sortUsingSelector:@selector(caseInsensitiveCompare:)];
    return codes;
}

// A .strings file is an old-style property list, so the system parser reads it
// without a hand-written lexer and rejects a malformed one for us.
static NSDictionary<NSString *, NSString *> *SPKCatalogAtPath(NSString *path) {
    if (path.length == 0)
        return nil;
    NSDictionary *catalog = [NSDictionary dictionaryWithContentsOfURL:[NSURL fileURLWithPath:path] error:nil];
    return [catalog isKindOfClass:[NSDictionary class]] ? catalog : nil;
}

/// A value no translation would change: a single technical token or brand name
/// ("Instagram", "VideoToolbox", "GIF", "1:1"), or a string made only of
/// placeholders and punctuation ("%@ - %@"). Counting these as untranslated made
/// a fully translated pack report in the nineties, which reads as a warning about
/// a catalog that has nothing wrong with it.
static BOOL SPKValueIsLanguageNeutral(NSString *value) {
    if (value.length == 0)
        return YES;
    if ([value rangeOfCharacterFromSet:NSCharacterSet.whitespaceCharacterSet].location == NSNotFound)
        return YES;
    return [value rangeOfCharacterFromSet:NSCharacterSet.letterCharacterSet].location == NSNotFound;
}

static NSUInteger SPKEnglishStringCount(void) {
    static NSUInteger count = 0;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        count = SPKCatalogAtPath(SPKResourcePath([@"en.lproj" stringByAppendingPathComponent:kSPKCatalogFileName])).count;
    });
    return count;
}

@implementation SPKLanguagePack
@end

@implementation SPKLanguagePackManager

+ (SPKLanguagePack *)packAtPath:(NSString *)lprojPath code:(NSString *)code {
    NSDictionary<NSString *, NSString *> *catalog =
        SPKCatalogAtPath([lprojPath stringByAppendingPathComponent:kSPKCatalogFileName]);
    if (catalog.count == 0)
        return nil;

    SPKLanguagePack *pack = [SPKLanguagePack new];
    pack.code = code;
    pack.stringCount = catalog.count;
    pack.hasPlurals = [NSFileManager.defaultManager
        fileExistsAtPath:[lprojPath stringByAppendingPathComponent:kSPKPluralFileName]];
    pack.byteSize = [SPKStoragePaths sizeOfDirectory:lprojPath];

    NSUInteger englishCount = SPKEnglishStringCount();
    if (englishCount > 0) {
        NSDictionary<NSString *, NSString *> *english =
            SPKCatalogAtPath(SPKResourcePath([@"en.lproj" stringByAppendingPathComponent:kSPKCatalogFileName]));
        // A string left verbatim in English is not translated, so a pack seeded
        // from the English template reports what it really is rather than 100%.
        NSUInteger translated = 0;
        for (NSString *key in english) {
            NSString *value = catalog[key];
            if (value.length == 0)
                continue;
            if (![value isEqualToString:english[key]] || SPKValueIsLanguageNeutral(english[key]))
                translated++;
        }
        // Floor, so an all-but-one catalog never advertises itself as complete.
        pack.coveragePercent = (100 * translated) / englishCount;
    }
    return pack;
}

+ (NSArray<SPKLanguagePack *> *)installedPacks {
    NSMutableArray<SPKLanguagePack *> *packs = [NSMutableArray array];
    for (NSString *code in SPKInstalledLanguagePackCodes()) {
        SPKLanguagePack *pack = [self packAtPath:SPKLanguagePackPathForCode(code) code:code];
        if (pack)
            [packs addObject:pack];
    }
    return packs;
}

+ (unsigned long long)installedPacksByteSize {
    return [SPKStoragePaths sizeOfDirectory:SPKLanguagePacksRoot()];
}

#pragma mark - Import

/// First `<code>.lproj` holding a catalog anywhere under `root`, so an archive
/// zipped from a parent folder, or with the Finder's __MACOSX sidecar, still
/// resolves to the one directory that matters.
+ (nullable NSString *)firstCatalogDirectoryUnder:(NSString *)root {
    NSDirectoryEnumerator<NSString *> *enumerator =
        [NSFileManager.defaultManager enumeratorAtPath:root];
    NSMutableArray<NSString *> *candidates = [NSMutableArray array];
    for (NSString *relative in enumerator) {
        if ([relative.pathComponents containsObject:@"__MACOSX"])
            continue;
        if (![relative.pathExtension isEqualToString:@"lproj"])
            continue;
        NSString *absolute = [root stringByAppendingPathComponent:relative];
        if ([NSFileManager.defaultManager fileExistsAtPath:[absolute stringByAppendingPathComponent:kSPKCatalogFileName]])
            [candidates addObject:absolute];
    }
    [candidates sortUsingSelector:@selector(compare:)];
    return candidates.firstObject;
}

/// Resolves whatever the user picked to the `.lproj` directory to install.
+ (nullable NSString *)catalogDirectoryForPickedPath:(NSString *)path error:(NSError **)error {
    NSFileManager *fm = NSFileManager.defaultManager;
    BOOL isDirectory = NO;
    if (![fm fileExistsAtPath:path isDirectory:&isDirectory]) {
        if (error)
            *error = SPKLanguagePackMakeError(SPKLanguagePackErrorUnreadable, SPKL(@"LANGUAGE_PACK_ERROR_UNREADABLE"));
        return nil;
    }

    if (isDirectory) {
        if ([path.pathExtension isEqualToString:@"lproj"] &&
            [fm fileExistsAtPath:[path stringByAppendingPathComponent:kSPKCatalogFileName]])
            return path;
        return [self firstCatalogDirectoryUnder:path];
    }

    if ([path.pathExtension caseInsensitiveCompare:@"zip"] == NSOrderedSame) {
        NSError *expandError = nil;
        NSString *expanded = [SPKSettingsTransferManager expandZipArchiveAtURL:[NSURL fileURLWithPath:path]
                                                                         error:&expandError];
        if (expanded.length == 0) {
            if (error)
                *error = expandError ?: SPKLanguagePackMakeError(SPKLanguagePackErrorUnreadable,
                                                                 SPKL(@"LANGUAGE_PACK_ERROR_UNREADABLE"));
            return nil;
        }
        return [self firstCatalogDirectoryUnder:expanded];
    }

    return nil;
}

+ (SPKLanguagePack *)importPackAtURL:(NSURL *)url error:(NSError **)error {
    // The picker hands over a file outside the sandbox, so the security scope
    // has to be held for the whole read.
    BOOL scoped = [url startAccessingSecurityScopedResource];
    @try {
        NSError *resolveError = nil;
        NSString *source = [self catalogDirectoryForPickedPath:url.path error:&resolveError];
        if (source.length == 0) {
            if (error)
                *error = resolveError ?: SPKLanguagePackMakeError(SPKLanguagePackErrorNoCatalog,
                                                                  SPKL(@"LANGUAGE_PACK_ERROR_NO_CATALOG"));
            return nil;
        }

        NSString *code = source.lastPathComponent.stringByDeletingPathExtension;
        if (!SPKLanguageCodeIsWellFormed(code)) {
            if (error)
                *error = SPKLanguagePackMakeError(SPKLanguagePackErrorBadCode,
                                                  [NSString stringWithFormat:SPKL(@"LANGUAGE_PACK_ERROR_BAD_CODE_FORMAT"), code]);
            return nil;
        }
        if (SPKCatalogAtPath([source stringByAppendingPathComponent:kSPKCatalogFileName]).count == 0) {
            if (error)
                *error = SPKLanguagePackMakeError(SPKLanguagePackErrorEmptyCatalog,
                                                  SPKL(@"LANGUAGE_PACK_ERROR_EMPTY_CATALOG"));
            return nil;
        }

        NSFileManager *fm = NSFileManager.defaultManager;
        NSString *destination = [SPKLanguagePacksDirectory()
            stringByAppendingPathComponent:[code stringByAppendingPathExtension:@"lproj"]];
        // Re-importing a corrected archive is the normal way a translator
        // iterates, so a pack for the same language is replaced, not refused.
        [fm removeItemAtPath:destination error:nil];

        NSError *copyError = nil;
        if (![fm copyItemAtPath:source toPath:destination error:&copyError]) {
            if (error)
                *error = SPKLanguagePackMakeError(SPKLanguagePackErrorCopyFailed, copyError.localizedDescription);
            return nil;
        }

        [SPKStrings languagePacksDidChange];
        SPKLanguagePack *pack = [self packAtPath:destination code:code];
        SPKLog(@"i18n", @"Imported language pack %@ (%lu strings)", code, (unsigned long)pack.stringCount);
        return pack;
    } @finally {
        if (scoped)
            [url stopAccessingSecurityScopedResource];
    }
}

#pragma mark - Removal and export

+ (BOOL)removePack:(SPKLanguagePack *)pack error:(NSError **)error {
    NSString *path = SPKLanguagePackPathForCode(pack.code);
    if (path.length == 0)
        return YES;

    NSError *removeError = nil;
    if (![NSFileManager.defaultManager removeItemAtPath:path error:&removeError]) {
        if (error)
            *error = removeError;
        return NO;
    }

    [SPKStrings languagePacksDidChange];
    // The selected language just stopped existing, so fall back to following the
    // system rather than leaving a dangling override behind.
    NSString *selected = [SPKStrings languageOverride];
    if ([selected isEqualToString:pack.code])
        [SPKStrings setLanguageOverride:nil];

    SPKLog(@"i18n", @"Removed language pack %@", pack.code);
    return YES;
}

+ (NSString *)exportArchiveForLanguage:(NSString *)code error:(NSError **)error {
    if (!SPKLanguageCodeIsWellFormed(code)) {
        if (error)
            *error = SPKLanguagePackMakeError(SPKLanguagePackErrorBadCode,
                                              [NSString stringWithFormat:SPKL(@"LANGUAGE_PACK_ERROR_BAD_CODE_FORMAT"), code]);
        return nil;
    }

    NSString *lprojName = [code stringByAppendingPathExtension:@"lproj"];
    NSString *source = SPKLanguagePackPathForCode(code)
                           ?: SPKResourcePath([lprojName stringByAppendingPathComponent:kSPKCatalogFileName])
                                  .stringByDeletingLastPathComponent;
    if (source.length == 0 || ![NSFileManager.defaultManager fileExistsAtPath:source]) {
        if (error)
            *error = SPKLanguagePackMakeError(SPKLanguagePackErrorNoCatalog, SPKL(@"LANGUAGE_PACK_ERROR_NO_CATALOG"));
        return nil;
    }

    NSFileManager *fm = NSFileManager.defaultManager;
    NSString *staging = [NSTemporaryDirectory()
        stringByAppendingPathComponent:[NSString stringWithFormat:@"SparkleLanguage-%@", NSUUID.UUID.UUIDString]];
    // The archive must not sit inside the directory being zipped.
    NSString *payload = [staging stringByAppendingPathComponent:@"Payload"];
    NSString *stagedCatalog = [payload stringByAppendingPathComponent:lprojName];
    if (![fm createDirectoryAtPath:stagedCatalog withIntermediateDirectories:YES attributes:nil error:nil]) {
        if (error)
            *error = SPKLanguagePackMakeError(SPKLanguagePackErrorCopyFailed, SPKL(@"LANGUAGE_PACK_ERROR_EXPORT_FAILED"));
        return nil;
    }
    for (NSString *fileName in @[ kSPKCatalogFileName, kSPKPluralFileName ]) {
        NSString *file = [source stringByAppendingPathComponent:fileName];
        if ([fm fileExistsAtPath:file])
            [fm copyItemAtPath:file toPath:[stagedCatalog stringByAppendingPathComponent:fileName] error:nil];
    }

    NSString *archive = [staging stringByAppendingPathComponent:
                                     [NSString stringWithFormat:@"Sparkle-%@.zip", code]];
    NSError *zipError = nil;
    if (![SPKSettingsTransferManager writeZipArchiveFromDirectory:payload toPath:archive error:&zipError]) {
        if (error)
            *error = zipError ?: SPKLanguagePackMakeError(SPKLanguagePackErrorCopyFailed,
                                                          SPKL(@"LANGUAGE_PACK_ERROR_EXPORT_FAILED"));
        return nil;
    }
    return archive;
}

@end
