#import "SPKGalleryHiddenSources.h"

#import "../../Utils.h"
#import "../Account/SPKAccountManager.h"

NSString *const kSPKGalleryHiddenSourcesKey = @"gallery_hidden_sources";
NSNotificationName const SPKGalleryHiddenSourcesDidChangeNotification = @"SPKGalleryHiddenSourcesDidChangeNotification";

NSArray<NSNumber *> *SPKGalleryHiddenSources(void) {
    NSArray *stored = [[NSUserDefaults standardUserDefaults] arrayForKey:kSPKGalleryHiddenSourcesKey];
    NSMutableArray<NSNumber *> *sources = [NSMutableArray array];
    for (id value in stored ?: @[]) {
        if ([value isKindOfClass:NSNumber.class])
            [sources addObject:value];
    }
    return [sources copy];
}

NSPredicate *SPKGalleryAccountScopePredicate(void) {
    if (![SPKUtils getBoolPref:@"gallery_filter_current_account"])
        return nil; // "All accounts"
    NSString *pk = [SPKAccountManager currentAccountPK];
    if (pk.length == 0)
        return nil; // logged out / unresolved — don't hide anything
    // Strictly the current account's files. Pre-existing/unassigned files are
    // not shown here; the settings toggle offers to claim them on enable, and
    // any file can be (re)assigned from its edit-details sheet.
    return [NSPredicate predicateWithFormat:@"ownerAccountPK == %@", pk];
}

NSPredicate *SPKGalleryVisibleSourcesPredicate(void) {
    NSMutableArray<NSPredicate *> *parts = [NSMutableArray array];

    NSArray<NSNumber *> *hidden = SPKGalleryHiddenSources();
    if (hidden.count > 0)
        [parts addObject:[NSPredicate predicateWithFormat:@"NOT (source IN %@)", hidden]];

    NSPredicate *accountScope = SPKGalleryAccountScopePredicate();
    if (accountScope)
        [parts addObject:accountScope];

    if (parts.count == 0)
        return nil;
    if (parts.count == 1)
        return parts.firstObject;
    return [NSCompoundPredicate andPredicateWithSubpredicates:parts];
}

BOOL SPKGallerySourceIsHidden(NSInteger source) {
    return [SPKGalleryHiddenSources() containsObject:@(source)];
}

void SPKGallerySetSourceHidden(NSInteger source, BOOL hidden) {
    NSMutableSet<NSNumber *> *sources = [NSMutableSet setWithArray:SPKGalleryHiddenSources()];
    if (hidden)
        [sources addObject:@(source)];
    else
        [sources removeObject:@(source)];
    NSArray *sorted = [sources.allObjects sortedArrayUsingSelector:@selector(compare:)];
    [[NSUserDefaults standardUserDefaults] setObject:sorted forKey:kSPKGalleryHiddenSourcesKey];
    [[NSNotificationCenter defaultCenter] postNotificationName:SPKGalleryHiddenSourcesDidChangeNotification object:nil];
}
