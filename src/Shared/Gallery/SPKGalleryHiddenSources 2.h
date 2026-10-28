#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *const kSPKGalleryHiddenSourcesKey;
FOUNDATION_EXPORT NSNotificationName const SPKGalleryHiddenSourcesDidChangeNotification;

NSArray<NSNumber *> *SPKGalleryHiddenSources(void);
/// Combined visibility predicate folded into every gallery fetch: hidden
/// sources AND (when the per-account filter is on) current-account scoping.
NSPredicate *_Nullable SPKGalleryVisibleSourcesPredicate(void);
/// Current-account scope when `gallery_filter_current_account` is on, else nil.
/// Matches files owned by the active account plus legacy/unassigned files.
NSPredicate *_Nullable SPKGalleryAccountScopePredicate(void);
BOOL SPKGallerySourceIsHidden(NSInteger source);
void SPKGallerySetSourceHidden(NSInteger source, BOOL hidden);

NS_ASSUME_NONNULL_END
