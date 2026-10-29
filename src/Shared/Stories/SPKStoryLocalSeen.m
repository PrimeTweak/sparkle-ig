#import "SPKStoryLocalSeen.h"
#import "SPKStoryContext.h"


#import "../../InstagramHeaders.h"
#import "../../Settings/SPKSetting.h"
#import "../../Utils.h"
#import "../ActionButton/ActionButtonLookupUtils.h"
#import "../Messages/SPKDirectUserResolver.h"
#import "../UI/SPKDialog.h"
#import "../UI/SPKMediaChrome.h"
#import "../UI/SPKUserListViewController.h"

// Writes a story's seen state the way Instagram's own mark does (media seen date,
// reel's seen media ids, reel's latest seen date), which never queues a receipt.
// Each touched reel is recorded per account with its previous date, for reset.

static NSString *const kSPKStoryLocalSeenRecordsKey = @"stories_local_seen_reels";
static NSString *const kSPKStoryLocalSeenPreviousDateKey = @"previousDate";
static NSString *const kSPKStoryLocalSeenMediaIdsKey = @"mediaIds";
static NSString *const kSPKStoryLocalSeenUpdatedKey = @"updatedAt";
static NSString *const kSPKStoryLocalSeenOwnerPKKey = @"ownerPK";
static NSString *const kSPKStoryLocalSeenUsernameKey = @"username";
// A record outlives its stories by a day, so a reel open across the expiry can
// still be reset.
static const NSTimeInterval kSPKStoryLocalSeenRecordLifetime = 48 * 60 * 60;

BOOL SPKStoryLocalSeenEnabled(void) {
    return SPKStoryManualSeenEnabled() && [SPKUtils getBoolPref:@"stories_manual_seen_keep_local"];
}

static id SPKStoryLocalSeenObject(id target, NSString *selectorName) {
    SEL selector = NSSelectorFromString(selectorName);
    if (!target || ![target respondsToSelector:selector])
        return nil;
    return ((id (*)(id, SEL))objc_msgSend)(target, selector);
}

static NSString *SPKStoryLocalSeenMediaID(id item) {
    id mediaID = SPKStoryLocalSeenObject(item, @"mediaId");
    if ([mediaID isKindOfClass:NSString.class] && [mediaID length] > 0)
        return mediaID;
    id pk = SPKStoryLocalSeenObject(item, @"pk");
    if ([pk isKindOfClass:NSNumber.class])
        pk = [pk stringValue];
    if (![pk isKindOfClass:NSString.class] || [pk length] == 0)
        return nil;
    // Story pks read "<media id>_<owner pk>"; the seen state uses the media id.
    return [pk componentsSeparatedByString:@"_"].firstObject;
}

static NSString *SPKStoryLocalSeenReelPK(id viewer, id sectionController) {
    NSString *reelPK = SPKStoryLocalSeenObject(SPKStoryLocalSeenObject(sectionController, @"viewModel"), @"reelPK");
    if (![reelPK isKindOfClass:NSString.class] || reelPK.length == 0)
        reelPK = SPKStoryLocalSeenObject(SPKStoryLocalSeenObject(viewer, @"currentViewModel"), @"reelPK");
    return [reelPK isKindOfClass:NSString.class] && reelPK.length > 0 ? reelPK : nil;
}

static IGStorySeenStateStore *SPKStoryLocalSeenStore(id viewer) {
    id session = SPKStoryLocalSeenObject(viewer, @"userSession") ?: [SPKUtils activeUserSession];
    id store = SPKStoryLocalSeenObject(session, @"storySeenStateStore");
    return [store isKindOfClass:NSClassFromString(@"IGStorySeenStateStore")] ? store : nil;
}

static IGStoryPogSeenStateStore *SPKStoryLocalSeenPogStore(IGStorySeenStateStore *store) {
    id pogStore = store ? [SPKUtils getIvarForObj:store name:"_pogSeenStateStore"] : nil;
    return [pogStore respondsToSelector:@selector(setLatestSeenMediaDateForceUpdate:forReelPK:)] ? pogStore : nil;
}

#pragma mark - Records

// Only a person's own reel, keyed by their numeric pk: highlights ("highlight:<id>")
// always show a grey ring, so there is nothing to keep locally for them.
static BOOL SPKStoryLocalSeenIsUserReel(NSString *reelPK) {
    if (reelPK.length == 0)
        return NO;
    return [reelPK rangeOfCharacterFromSet:NSCharacterSet.decimalDigitCharacterSet.invertedSet].location == NSNotFound;
}

static NSString *SPKStoryLocalSeenAccountPK(void) {
    return [SPKUtils currentUserPK];
}

static NSString *SPKStoryLocalSeenRecordKey(NSString *accountPK, NSString *reelPK) {
    return [NSString stringWithFormat:@"%@|%@", accountPK, reelPK];
}

// Stored outside the per-account preference namespace: the records are data,
// already scoped by account in their keys.
static NSMutableDictionary<NSString *, NSDictionary *> *SPKStoryLocalSeenRecords(void) {
    NSDictionary *stored = [[NSUserDefaults standardUserDefaults] dictionaryForKey:kSPKStoryLocalSeenRecordsKey];
    NSMutableDictionary *records = [NSMutableDictionary dictionary];
    NSDate *cutoff = [NSDate dateWithTimeIntervalSinceNow:-kSPKStoryLocalSeenRecordLifetime];
    [stored enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSDictionary *record, BOOL *stop) {
        if (![key isKindOfClass:NSString.class] || ![record isKindOfClass:NSDictionary.class])
            return;
        // Drops any record that is not a user reel.
        NSRange separator = [key rangeOfString:@"|"];
        if (separator.location == NSNotFound || !SPKStoryLocalSeenIsUserReel([key substringFromIndex:NSMaxRange(separator)]))
            return;
        NSDate *updatedAt = record[kSPKStoryLocalSeenUpdatedKey];
        if ([updatedAt isKindOfClass:NSDate.class] && [updatedAt compare:cutoff] == NSOrderedAscending)
            return;
        records[key] = record;
    }];
    return records;
}

static void SPKStoryLocalSeenSaveRecords(NSDictionary *records) {
    if (records.count > 0)
        [[NSUserDefaults standardUserDefaults] setObject:records forKey:kSPKStoryLocalSeenRecordsKey];
    else
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:kSPKStoryLocalSeenRecordsKey];
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:SPKSettingAccessoryTextDidChangeNotification object:nil];
    });
}

#pragma mark - Marking

void SPKStoryLocalSeenMarkItem(id viewer, id sectionController, id item) {
    NSString *accountPK = SPKStoryLocalSeenAccountPK();
    NSString *reelPK = SPKStoryLocalSeenReelPK(viewer, sectionController);
    if (reelPK && !SPKStoryLocalSeenIsUserReel(reelPK))
        return;
    NSString *mediaID = SPKStoryLocalSeenMediaID(item);
    IGStorySeenStateStore *store = SPKStoryLocalSeenStore(viewer);
    IGStoryPogSeenStateStore *pogStore = SPKStoryLocalSeenPogStore(store);
    id mediaStore = store ? [SPKUtils getIvarForObj:store name:"_mediaSeenStateStore"] : nil;
    NSDate *takenAt = SPKStoryLocalSeenObject(item, @"takenAtDate");
    if (accountPK.length == 0 || !reelPK || !mediaID || !pogStore || ![mediaStore respondsToSelector:@selector(setSeenMediaId:forReelPK:)] ||
        ![takenAt isKindOfClass:NSDate.class]) {
        SPKLog(@"Stories", @"[Sparkle LocalSeen] Unable to mark locally reel=%@ media=%@ store=%@ pog=%@ mediaStore=%@", reelPK, mediaID, store, pogStore, mediaStore);
        return;
    }

    NSMutableDictionary *records = SPKStoryLocalSeenRecords();
    NSString *recordKey = SPKStoryLocalSeenRecordKey(accountPK, reelPK);
    NSMutableDictionary *record = [records[recordKey] mutableCopy];
    if (!record) {
        record = [NSMutableDictionary dictionary];
        NSDate *previousDate = [pogStore latestSeenMediaDateForReelPK:reelPK];
        if ([previousDate isKindOfClass:NSDate.class])
            record[kSPKStoryLocalSeenPreviousDateKey] = previousDate;
    }
    // Who the stories belong to, for the list of locally seen stories.
    NSString *ownerPK = SPKStoryUserPKFromMediaObject(item);
    NSString *username = SPKUsernameFromMediaObject(item);
    if (ownerPK.length > 0)
        record[kSPKStoryLocalSeenOwnerPKKey] = ownerPK;
    if (username.length > 0)
        record[kSPKStoryLocalSeenUsernameKey] = username;
    NSMutableOrderedSet *mediaIDs = [NSMutableOrderedSet orderedSetWithArray:record[kSPKStoryLocalSeenMediaIdsKey] ?: @[]];
    [mediaIDs addObject:mediaID];
    record[kSPKStoryLocalSeenMediaIdsKey] = mediaIDs.array;
    record[kSPKStoryLocalSeenUpdatedKey] = [NSDate date];
    records[recordKey] = record;

    // Same writes, in the same order, as Instagram's own mark; the latest seen
    // date only moves forward, so an older story does not unsee newer ones.
    @try {
        [store addSeenDateForStoryItem:item reelPK:reelPK];
        [pogStore setLatestSeenMediaDate:takenAt forReelPK:reelPK];
        [mediaStore setSeenMediaId:mediaID forReelPK:reelPK];
    } @catch (NSException *exception) {
        SPKLog(@"Stories", @"[Sparkle LocalSeen] Marking reel=%@ media=%@ failed: %@", reelPK, mediaID, exception.reason);
        return;
    }
    SPKStoryLocalSeenSaveRecords(records);
    SPKLog(@"Stories", @"[Sparkle LocalSeen] Marked reel=%@ media=%@ locally", reelPK, mediaID);
}

void SPKStoryLocalSeenNoteItemSent(id viewer, id sectionController, id item) {
    NSString *accountPK = SPKStoryLocalSeenAccountPK();
    NSString *reelPK = SPKStoryLocalSeenReelPK(viewer, sectionController);
    NSString *mediaID = SPKStoryLocalSeenMediaID(item);
    if (accountPK.length == 0 || !reelPK || !mediaID)
        return;

    NSMutableDictionary *records = SPKStoryLocalSeenRecords();
    NSString *recordKey = SPKStoryLocalSeenRecordKey(accountPK, reelPK);
    NSMutableDictionary *record = [records[recordKey] mutableCopy];
    if (!record)
        return;

    // The owner now knows this story was seen, so a reset must not move the
    // reel's seen date back past it.
    NSMutableArray *mediaIDs = [record[kSPKStoryLocalSeenMediaIdsKey] mutableCopy] ?: [NSMutableArray array];
    [mediaIDs removeObject:mediaID];
    NSDate *takenAt = SPKStoryLocalSeenObject(item, @"takenAtDate");
    NSDate *previousDate = record[kSPKStoryLocalSeenPreviousDateKey];
    if ([takenAt isKindOfClass:NSDate.class] && (!previousDate || [takenAt compare:previousDate] == NSOrderedDescending))
        record[kSPKStoryLocalSeenPreviousDateKey] = takenAt;

    if (mediaIDs.count == 0) {
        [records removeObjectForKey:recordKey];
    } else {
        record[kSPKStoryLocalSeenMediaIdsKey] = mediaIDs;
        record[kSPKStoryLocalSeenUpdatedKey] = [NSDate date];
        records[recordKey] = record;
    }
    SPKStoryLocalSeenSaveRecords(records);
}

#pragma mark - Reset

static NSArray<NSString *> *SPKStoryLocalSeenRecordKeysForAccount(NSDictionary *records, NSString *accountPK) {
    if (accountPK.length == 0)
        return @[];
    NSString *prefix = [accountPK stringByAppendingString:@"|"];
    NSMutableArray *keys = [NSMutableArray array];
    for (NSString *key in records) {
        if ([key hasPrefix:prefix])
            [keys addObject:key];
    }
    return keys;
}

NSUInteger SPKStoryLocalSeenUserCount(void) {
    return SPKStoryLocalSeenRecordKeysForAccount(SPKStoryLocalSeenRecords(), SPKStoryLocalSeenAccountPK()).count;
}

// Puts the reels behind `keys` back as they were before the local marks. Keys of
// another account are skipped: only the current account's store is reachable.
static void SPKStoryLocalSeenResetRecordKeys(NSArray<NSString *> *keys) {
    NSString *accountPK = SPKStoryLocalSeenAccountPK();
    IGStorySeenStateStore *store = SPKStoryLocalSeenStore(nil);
    IGStoryPogSeenStateStore *pogStore = SPKStoryLocalSeenPogStore(store);
    if (accountPK.length == 0 || !pogStore) {
        SPKLog(@"Stories", @"[Sparkle LocalSeen] Unable to reset account=%@ store=%@", accountPK, store);
        return;
    }

    NSString *prefix = [accountPK stringByAppendingString:@"|"];
    NSMutableDictionary *records = SPKStoryLocalSeenRecords();
    NSUInteger resetCount = 0;
    for (NSString *key in keys) {
        NSDictionary *record = records[key];
        if (!record || ![key hasPrefix:prefix])
            continue;
        NSString *reelPK = [key substringFromIndex:prefix.length];
        // A reel never seen before has no date; the distant past reads as unseen.
        NSDate *previousDate = record[kSPKStoryLocalSeenPreviousDateKey] ?: [NSDate distantPast];
        NSArray *mediaIDs = record[kSPKStoryLocalSeenMediaIdsKey] ?: @[];
        @try {
            // The forced update notifies every ring listener itself.
            [pogStore setLatestSeenMediaDateForceUpdate:previousDate forReelPK:reelPK];
            // The store subtracts these as a set; an array throws.
            [store removeSeenMediaIds:[NSSet setWithArray:mediaIDs] forReelPk:reelPK];
        } @catch (NSException *exception) {
            SPKLog(@"Stories", @"[Sparkle LocalSeen] Resetting reel=%@ failed: %@", reelPK, exception.reason);
        }
        [records removeObjectForKey:key];
        resetCount++;
    }
    @try {
        [pogStore archive];
    } @catch (NSException *exception) {
        SPKLog(@"Stories", @"[Sparkle LocalSeen] Saving the reset failed: %@", exception.reason);
    }
    SPKStoryLocalSeenSaveRecords(records);
    SPKLog(@"Stories", @"[Sparkle LocalSeen] Reset %lu reels", (unsigned long)resetCount);
}

#pragma mark - List

@interface SPKStoryLocalSeenUsersViewController : SPKUserListViewController
@property (nonatomic, strong) UIBarButtonItem *resetAllItem;
@end

@implementation SPKStoryLocalSeenUsersViewController

- (instancetype)init {
    if ((self = [super init])) {
        self.title = @"Seen locally";
        self.emptyTitle = @"No stories yet";
        self.emptySubtitle = @"Stories you watch with Keep seen locally show up here.";
        self.emptyIconName = @"empty";
    }
    return self;
}

- (NSArray<UIBarButtonItem *> *)additionalTrailingBarItems {
    self.resetAllItem = SPKMediaChromeTopBarButtonItemWithTint(@"trash", self, @selector(spk_resetAllTapped), [SPKUtils SPKColor_InstagramDestructive],
                                                               @"Reset local seen");
    return @[ self.resetAllItem ];
}

- (NSArray<SPKUserListItem *> *)buildItems {
    NSDictionary *records = SPKStoryLocalSeenRecords();
    NSMutableArray<SPKUserListItem *> *items = [NSMutableArray array];
    for (NSString *key in SPKStoryLocalSeenRecordKeysForAccount(records, SPKStoryLocalSeenAccountPK())) {
        NSDictionary *record = records[key];
        NSString *ownerPK = record[kSPKStoryLocalSeenOwnerPKKey];
        NSString *username = record[kSPKStoryLocalSeenUsernameKey];
        NSUInteger storyCount = [record[kSPKStoryLocalSeenMediaIdsKey] count];

        SPKUserListItem *item = [SPKUserListItem new];
        item.pk = ownerPK;
        item.title = username.length ? [@"@" stringByAppendingString:username] : @"Unknown user";
        item.subtitle = [NSString stringWithFormat:(storyCount == 1 ? @"%lu story" : @"%lu stories"), (unsigned long)storyCount];
        item.avatarURLString = spkDirectUserResolverProfilePicURLStringForPK(ownerPK);
        item.representedObject = key;
        [items addObject:item];
    }
    return items;
}

- (void)listDidUpdateItemCount:(NSUInteger)count {
    self.resetAllItem.enabled = count > 0;
}

// Swiping a person away makes just their stories unseen again.
- (void)didDeleteItem:(SPKUserListItem *)item {
    if ([item.representedObject isKindOfClass:NSString.class])
        SPKStoryLocalSeenResetRecordKeys(@[ item.representedObject ]);
    [self reloadItems];
}

- (void)spk_resetAllTapped {
    __weak typeof(self) weakSelf = self;
    [SPKDialog presentFromController:self
                               title:@"Reset local seen"
                             message:@"All stories you've seen locally will appear unseen again. This can't be undone."
                             actions:@[
                                 [SPKDialogAction actionWithTitle:@"Cancel" style:SPKDialogActionStyleCancel handler:nil],
                                 [SPKDialogAction actionWithTitle:@"Reset"
                                                            style:SPKDialogActionStyleDestructive
                                                          handler:^{
                                                              SPKStoryLocalSeenResetRecordKeys(SPKStoryLocalSeenRecordKeysForAccount(SPKStoryLocalSeenRecords(), SPKStoryLocalSeenAccountPK()));
                                                              [weakSelf reloadItems];
                                                          }],
                             ]];
}

@end

UIViewController *SPKStoryLocalSeenListViewController(void) {
    return [[SPKStoryLocalSeenUsersViewController alloc] init];
}
