#pragma once

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Preference holding the family name of the app-wide font, or an empty string
/// for Instagram's default. Global (never per-account): fonts are resolved from
/// the first view Instagram builds, long before an account session exists, so a
/// per-account key would read the global default on every cold launch.
FOUNDATION_EXPORT NSString *const kSPKPrefInterfaceCustomFont;

/// One imported font file on disk.
@interface SPKFontFile : NSObject
/// File name inside the fonts directory, e.g. "Inter-Regular.ttf".
@property (nonatomic, copy) NSString *fileName;
/// Family the file registers, e.g. "Inter". Nil if the file failed to register.
@property (nonatomic, copy, nullable) NSString *familyName;
/// PostScript name of the first face in the file, e.g. "Inter-Regular".
@property (nonatomic, copy, nullable) NSString *postScriptName;
@property (nonatomic, assign) unsigned long long byteSize;
@end

/// One face of a family, as Core Text reports it.
@interface SPKFontFace : NSObject
/// PostScript name, e.g. "SpaceMono-BoldItalic".
@property (nonatomic, copy) NSString *postScriptName;
/// The style the file declares, e.g. "Bold Italic". Derived from the traits when
/// the file declares none.
@property (nonatomic, copy) NSString *styleName;
/// UIFontWeight scale (-0.8 ultra light … 0.8 black).
@property (nonatomic, assign) CGFloat weight;
@property (nonatomic, assign) BOOL italic;
@end

/// Imports, registers, and resolves user-supplied .otf/.ttf/.ttc fonts.
///
/// Registration is process-local (CTFontManagerRegisterFontsForURL with a
/// .process scope), so nothing leaks outside Instagram and nothing needs to be
/// unregistered on uninstall beyond deleting the files.
@interface SPKFontManager : NSObject

/// Registers every imported file with Core Text. Idempotent and cheap to call
/// again; re-registering an already-registered URL is treated as success.
+ (void)registerImportedFonts;

/// Files currently in the fonts directory, sorted by family then file name.
/// Registers first, so `familyName` is populated for anything usable.
+ (NSArray<SPKFontFile *> *)importedFonts;

/// Distinct family names across every imported file, alphabetically.
+ (NSArray<NSString *> *)importedFamilyNames;

/// The faces `familyName` actually ships, upright before italic and lightest
/// first. What a family contains is entirely up to whoever made it: previewing a
/// fixed Regular/Medium/Bold set renders the same face three times for a family
/// that only ships two, and never reveals that every face in it is italic.
+ (NSArray<SPKFontFace *> *)facesInFamily:(NSString *)familyName;

/// Copies `url` into the fonts directory and registers it. Returns the resulting
/// file, or nil with `error` set when the file is not a font, is already
/// imported, or cannot be registered.
+ (nullable SPKFontFile *)importFontAtURL:(NSURL *)url error:(NSError **)error;

/// Deletes the file and unregisters it. If it was the only file providing the
/// selected family, the selection falls back to the default font.
+ (BOOL)removeFontFile:(SPKFontFile *)file error:(NSError **)error;

/// The family the user picked, or nil when Instagram's default font is in use.
/// Returns nil if the stored family is no longer installed.
+ (nullable NSString *)selectedFamilyName;
+ (void)setSelectedFamilyName:(nullable NSString *)familyName;

/// YES when a usable custom family is selected. Fast enough to gate a hook that
/// runs on every font lookup: the answer is cached and invalidated on change.
+ (BOOL)isActive;

/// The face of the selected family closest to `weight`, or nil when no custom
/// font is active. Results are cached, so this is safe to call from a hot hook.
///
/// `weight` uses the UIFontWeight scale (-0.8 ultra light … 0.8 black). Italic
/// requests fall back to the upright face when the family has no italic.
+ (nullable UIFont *)fontOfSize:(CGFloat)size weight:(UIFontWeight)weight italic:(BOOL)italic;

/// A face from any installed family, whether or not it is the selected one. Used by
/// the settings screen to preview a font before it is applied.
+ (nullable UIFont *)fontInFamily:(NSString *)familyName
                             size:(CGFloat)size
                           weight:(UIFontWeight)weight
                           italic:(BOOL)italic;

/// Directory holding the imported files.
+ (NSString *)fontsDirectory;

@end

NS_ASSUME_NONNULL_END
