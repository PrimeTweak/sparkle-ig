#import <objc/message.h>
#import <objc/runtime.h>
#import <substrate.h>

#import "../../Shared/ActionButton/ActionButtonLookupUtils.h"
#import "../../Utils.h"
#import "InstantsManualSeen.h"

// MARK: - Constants

/// The session-defaults key Instagram persists `IGQuickSnapStore.seenSnapPks` into, the one
/// `refreshSeenStateFromSharedStorage` reloads from.
static NSString *const kSPKInstantsSeenStateDefaultsKey = @"kIGQuickSnapSeenStateKey";

/// Upper bound on the protected set. Instants expire server-side, so an unbounded set
/// would only accumulate PKs that can never come back.
static const NSUInteger kSPKInstantsManualSeenHeldLimit = 500;

/// Released PKs, per account. Kept across launches: the server never learns of a release,
/// so a relaunch would otherwise hold the snap again and bring it back to the tray.
static NSString *const kSPKInstantsManualSeenReleasedKey = @"instants_manual_seen_released";

/// Bound on the released list, evicting oldest first. Instants expire on Instagram's schedule,
/// so old entries can never resurface and only cost space.
static const NSUInteger kSPKInstantsManualSeenReleasedLimit = 500;

// MARK: - State

/// Media PKs held out of the persisted seen state, newest last.
static NSMutableOrderedSet<NSString *> *sProtectedPKs = nil;
/// PKs the user explicitly marked seen, oldest first, restored from preferences at startup.
/// Never re-protected, and re-asserted into the stored seen state on every pass, so a
/// released Instant stays released across launches and across refetches.
static NSMutableOrderedSet<NSString *> *sReleasedPKs = nil;
/// `refreshSeenStateFromSharedStorage` synchronously re-enters the service listener
/// callback, which is where `SPKInstantsManualSeenHoldUnseen` is called from. Without this
/// guard the feature calls itself forever.
static BOOL sRefreshing = NO;
/// YES while the consumption viewer is on screen. A reload under it would put the consumed
/// snap back in the live list and cycle the viewer, so only the stored value is kept clean.
static BOOL sViewerOpen = NO;

BOOL SPKInstantsManualSeenIsEnabled(void) {
    return [SPKUtils getBoolPref:@"instants_manual_seen"];
}

static void SPKInstantsManualSeenPersistReleased(void) {
    while (sReleasedPKs.count > kSPKInstantsManualSeenReleasedLimit)
        [sReleasedPKs removeObjectAtIndex:0];
    SPKPreferenceSetObject(sReleasedPKs.array, kSPKInstantsManualSeenReleasedKey);
}

static void SPKInstantsManualSeenEnsureState(void) {
    if (!sProtectedPKs)
        sProtectedPKs = [NSMutableOrderedSet orderedSet];
    if (sReleasedPKs)
        return;
    sReleasedPKs = [NSMutableOrderedSet orderedSet];
    id stored = SPKPreferenceObjectForKey(kSPKInstantsManualSeenReleasedKey);
    if (![stored isKindOfClass:NSArray.class])
        return;
    for (id pk in (NSArray *)stored) {
        if ([pk isKindOfClass:NSString.class] && ((NSString *)pk).length > 0)
            [sReleasedPKs addObject:pk];
    }
    if (sReleasedPKs.count > 0)
        SPKLog(@"Instants", @"manual seen: restored %lu released instant(s)",
               (unsigned long)sReleasedPKs.count);
}

// MARK: - Service Lookup

/// The live `IGQuickSnapService`, remembered from the first call that carries it, with the
/// window -> userSession -> sharedQuickSnapService walk of InstantsResolver.xm as fallback.
static __weak id sCachedService = nil;

static id SPKInstantsManualSeenLocateService(void) {
    id cached = sCachedService;
    if (cached)
        return cached;
    @try {
        SEL sharedQSSel = NSSelectorFromString(@"sharedQuickSnapService");
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if (![scene isKindOfClass:UIWindowScene.class])
                continue;
            for (UIWindow *window in ((UIWindowScene *)scene).windows) {
                if (![window respondsToSelector:@selector(userSession)])
                    continue;
                id session = SPKObjectForSelector(window, @"userSession");
                if (![session respondsToSelector:sharedQSSel])
                    continue;
                id service = ((id (*)(id, SEL))objc_msgSend)(session, sharedQSSel);
                if (service) {
                    sCachedService = service;
                    return service;
                }
            }
        }
    } @catch (__unused NSException *e) {
    }
    return nil;
}

// MARK: - Session Defaults Access

/// The session `IGUserDefaults` holding the seen state. The service and the store share it,
/// so one write is enough; it is a Swift stored property, read as an ivar rather than by KVC.
static id SPKInstantsManualSeenSessionDefaults(id service) {
    if (!service)
        return nil;
    id defaults = [SPKUtils getIvarForObj:service name:"sessionUserDefaults"];
    if (!defaults) {
        id store = [SPKUtils getIvarForObj:service name:"quickSnapStore"];
        if (store)
            defaults = [SPKUtils getIvarForObj:store name:"sessionUserDefaults"];
    }
    if (![defaults respondsToSelector:@selector(objectForKey:)] ||
        ![defaults respondsToSelector:@selector(setObject:forKey:)]) {
        return nil;
    }
    return defaults;
}

/// The persisted seen list as plain strings. Instagram stores an array; a set is accepted
/// too so a future representation change degrades instead of breaking.
static NSArray<NSString *> *SPKInstantsManualSeenStateList(id defaults) {
    id value = nil;
    @try {
        value = [defaults objectForKey:kSPKInstantsSeenStateDefaultsKey];
    } @catch (__unused NSException *e) {
        return nil;
    }
    if ([value isKindOfClass:NSArray.class])
        return (NSArray *)value;
    if ([value isKindOfClass:NSSet.class])
        return ((NSSet *)value).allObjects;
    if ([value isKindOfClass:NSOrderedSet.class])
        return ((NSOrderedSet *)value).array;
    return nil;
}

static BOOL SPKInstantsManualSeenWriteStateList(id defaults, NSArray<NSString *> *list) {
    @try {
        [defaults setObject:list forKey:kSPKInstantsSeenStateDefaultsKey];
        return YES;
    } @catch (__unused NSException *e) {
        return NO;
    }
}

/// Builds without `refreshSeenStateFromSharedStorage` (448+) get `seenSnapPks` rewritten
/// through Swift to the stored list. Only native `Set<String>` storage is written: any other
/// representation means the property changed, and writing over it would corrupt memory.
static BOOL SPKInstantsManualSeenRewriteMemorySet(id service, NSArray<NSString *> *list) {
    Class bridge = NSClassFromString(@"SPKInstantsSeenStateBridge");
    id store = [SPKUtils getIvarForObj:service name:"quickSnapStore"];
    if (!bridge || !store)
        return NO;
    Ivar ivar = class_getInstanceVariable(object_getClass(store), "seenSnapPks");
    if (!ivar)
        return NO;
    void *address = (uint8_t *)(__bridge void *)store + ivar_getOffset(ivar);

    // Bit 62 marks a non-native (Objective-C) backing, bit 63 a tagged pointer.
    uintptr_t word = *(uintptr_t *)address;
    if (word == 0 || (word >> 62) != 0)
        return NO;
    // `_TtGCs11_SetStorageSS_` is `_SetStorage<String>` (IG 448 reports it with a trailing `$`),
    // so a set of any other element type is refused. The empty singleton is shared by every
    // element type and holds nothing, so replacing it cannot misread existing contents.
    NSString *storageClass = NSStringFromClass(object_getClass((__bridge id)(void *)word));
    if (![storageClass hasPrefix:@"_TtGCs11_SetStorageSS_"] &&
        [storageClass rangeOfString:@"EmptySetSingleton"].location == NSNotFound) {
        SPKLog(@"Instants", @"manual seen: seen set not rewritten, unexpected storage %@", storageClass);
        return NO;
    }

    NSMutableArray<NSString *> *values = [NSMutableArray arrayWithCapacity:list.count];
    for (id pk in list) {
        if ([pk isKindOfClass:NSString.class])
            [values addObject:pk];
    }
    ((void (*)(id, SEL, void *, NSArray *))objc_msgSend)(bridge, @selector(replaceStringSetAtAddress:with:),
                                                           address, values);
    return YES;
}

/// Rebuilds `seenSnapPks` from the stored value (reload selector up to 447, direct rewrite
/// after) and tells the UI. `announceAsNew` passes `didReceiveNewSnaps`, without which the
/// tray keeps drawing the old list until the inbox is refreshed by hand.
static void SPKInstantsManualSeenReloadState(id service, BOOL announceAsNew) {
    if (sRefreshing)
        return;
    sRefreshing = YES;
    SEL refresh = @selector(refreshSeenStateFromSharedStorage);
    SEL announce = @selector(announceSnapStateUpdateWithDidReceiveNewSnaps:);
    @try {
        if ([service respondsToSelector:refresh]) {
            ((void (*)(id, SEL))objc_msgSend)(service, refresh);
        } else {
            // Without the defaults there is no stored list to mirror, and rewriting the set
            // to empty would release every Instant the user has seen.
            id defaults = SPKInstantsManualSeenSessionDefaults(service);
            NSArray<NSString *> *stored = defaults ? (SPKInstantsManualSeenStateList(defaults) ?: @[]) : nil;
            if (!stored || !SPKInstantsManualSeenRewriteMemorySet(service, stored))
                SPKLog(@"Instants", @"manual seen: in-memory seen set unreachable, held instants return after a relaunch");
        }
        if ([service respondsToSelector:announce])
            ((void (*)(id, SEL, BOOL))objc_msgSend)(service, announce, announceAsNew);
    } @catch (__unused NSException *e) {
    }
    sRefreshing = NO;
}

/// Refetches the snap list, which is what brings the Instants back: Instagram purges consumed
/// media once the viewer closes, and they return unseen since no seen sync left the device.
/// Forced, because the service otherwise throttles on `timeSinceLastFetch`.
static void SPKInstantsManualSeenRefetchSnaps(id service) {
    SEL forced = @selector(fetchQuickSnapsOnSuccess:onFailure:forceRefetch:);
    if ([service respondsToSelector:forced]) {
        @try {
            ((void (*)(id, SEL, id, id, BOOL))objc_msgSend)(service, forced, nil, nil, YES);
            return;
        } @catch (__unused NSException *e) {
        }
    }
    SEL initial = @selector(fetchInitialQuickSnaps);
    if ([service respondsToSelector:initial]) {
        @try {
            ((void (*)(id, SEL))objc_msgSend)(service, initial);
        } @catch (__unused NSException *e) {
        }
        return;
    }
    SPKLog(@"Instants", @"manual seen: refetch unavailable (no fetch selector)");
}

// MARK: - Public

void SPKInstantsManualSeenNoteServiceMedia(NSArray *mediaList) {
    if (mediaList.count == 0 || !SPKInstantsManualSeenIsEnabled())
        return;
    SPKInstantsManualSeenEnsureState();

    for (id media in mediaList) {
        NSString *pk = SPKStringFromValue(SPKObjectForSelector(media, @"pk"));
        if (pk.length == 0)
            pk = SPKStringFromValue(SPKObjectForSelector(media, @"graphQLID"));
        if (pk.length == 0 || [sReleasedPKs containsObject:pk])
            continue;
        // Re-adding moves it to the end, so the bound below evicts the oldest PKs.
        [sProtectedPKs removeObject:pk];
        [sProtectedPKs addObject:pk];
    }

    while (sProtectedPKs.count > kSPKInstantsManualSeenHeldLimit)
        [sProtectedPKs removeObjectAtIndex:0];
}

static void SPKInstantsManualSeenReloadStateUnlessViewing(id service);

void SPKInstantsManualSeenHoldUnseen(id service) {
    if (sRefreshing || !SPKInstantsManualSeenIsEnabled())
        return;
    SPKInstantsManualSeenEnsureState();
    // Releases alone are reason enough to run: after a relaunch nothing is held yet, and the
    // releases still have to be put back into a seen list Instagram has refetched without them.
    if (sProtectedPKs.count == 0 && sReleasedPKs.count == 0)
        return;

    if (service)
        sCachedService = service;
    id defaults = SPKInstantsManualSeenSessionDefaults(service);
    if (!defaults)
        return;

    NSArray<NSString *> *seen = SPKInstantsManualSeenStateList(defaults) ?: @[];
    if (seen.count == 0 && sReleasedPKs.count == 0)
        return;

    NSMutableArray<NSString *> *kept = [NSMutableArray arrayWithCapacity:seen.count];
    NSUInteger removed = 0;
    for (NSString *pk in seen) {
        if ([pk isKindOfClass:NSString.class] && [sProtectedPKs containsObject:pk]) {
            removed++;
            continue;
        }
        [kept addObject:pk];
    }

    // Re-assert the releases. Instagram refetches the whole list and knows nothing about
    // them, so without this a released Instant returns as unseen on the next fetch.
    NSUInteger reasserted = 0;
    for (NSString *pk in sReleasedPKs) {
        if (![kept containsObject:pk]) {
            [kept addObject:pk];
            reasserted++;
        }
    }
    if (removed == 0 && reasserted == 0)
        return;

    if (!SPKInstantsManualSeenWriteStateList(defaults, kept))
        return;
    SPKLog(@"Instants", @"manual seen: held %lu unseen, re-asserted %lu released "
                        @"(seen list %lu -> %lu, viewer=%@)",
           (unsigned long)removed, (unsigned long)reasserted,
           (unsigned long)seen.count, (unsigned long)kept.count,
           sViewerOpen ? @"open" : @"closed");
    SPKInstantsManualSeenReloadStateUnlessViewing(service);
}

/// Purely diagnostic: what Instagram now believes is available, so a log can show whether
/// the model was restored and only the tray lagged behind. IG 448 no longer exports the
/// accessor, which reads as `n/a`.
static NSString *SPKInstantsManualSeenAvailableSnapCount(id service) {
    SEL available = @selector(availableTimeOrderedSnaps);
    if (![service respondsToSelector:available])
        return @"n/a";
    @try {
        id list = ((id (*)(id, SEL))objc_msgSend)(service, available);
        if ([list respondsToSelector:@selector(count)])
            return [NSString stringWithFormat:@"%lu", (unsigned long)[list count]];
    } @catch (__unused NSException *e) {
    }
    return @"0";
}

/// Reloads the seen state, never while the viewer is on screen: mid-session the reload would
/// release every snap watched so far, not just the marked one. The stored value is written
/// either way, and the end of the session reloads from it.
static void SPKInstantsManualSeenReloadStateUnlessViewing(id service) {
    if (sViewerOpen)
        return;
    SPKInstantsManualSeenReloadState(service, NO);
}

void SPKInstantsManualSeenSetViewerOpen(BOOL open) {
    sViewerOpen = open;
}

void SPKInstantsManualSeenEndViewerSession(id service) {
    sViewerOpen = NO;
    if (!SPKInstantsManualSeenIsEnabled())
        return;
    SPKInstantsManualSeenEnsureState();
    if (sProtectedPKs.count == 0)
        return;

    // Strips what Instagram wrote while the viewer closed, then always reloads: only the
    // reload replaces the in-memory seen set, which still holds every snap of the session.
    SPKInstantsManualSeenHoldUnseen(service);

    // Deferred past the dismissal. Announcing while the viewer is still tearing down left
    // the inbox drawing the tray from the list it already held, which is why the Instants
    // only came back after a manual refresh.
    __weak id weakService = service ?: SPKInstantsManualSeenLocateService();
    NSUInteger restored = sProtectedPKs.count;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        id liveService = weakService ?: SPKInstantsManualSeenLocateService();
        if (!liveService)
            return;
        if (sViewerOpen) {
            // A new viewing session started inside the delay. Reloading now would push this
            // session's consumed snaps back into the live list underneath it, which is the
            // cycling this feature exists to avoid; that session's own end will restore them.
            SPKLog(@"Instants", @"manual seen: session end skipped, a new viewer opened");
            return;
        }
        SPKInstantsManualSeenReloadState(liveService, YES);
        SPKInstantsManualSeenRefetchSnaps(liveService);
        SPKLog(@"Instants", @"manual seen: session ended, %lu instant(s) held unseen, refetching "
                            @"(available=%@ before the response)",
               (unsigned long)restored,
               SPKInstantsManualSeenAvailableSnapCount(liveService));

        // The fetch is asynchronous, so the count above is always the pre-response one. This
        // second reading says whether the refetch actually restored the tray.
        __weak id weakLive = liveService;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            id afterService = weakLive;
            if (!afterService)
                return;
            SPKLog(@"Instants", @"manual seen: refetch settled (available=%@)",
                   SPKInstantsManualSeenAvailableSnapCount(afterService));
        });
    });
}

void SPKInstantsManualSeenMarkMediaPK(NSString *mediaPK) {
    if (mediaPK.length == 0)
        return;
    SPKInstantsManualSeenEnsureState();

    // Stop protecting it first, so the next service update does not undo this write.
    [sProtectedPKs removeObject:mediaPK];
    [sReleasedPKs removeObject:mediaPK];
    [sReleasedPKs addObject:mediaPK];
    SPKInstantsManualSeenPersistReleased();

    id service = SPKInstantsManualSeenLocateService();
    id defaults = SPKInstantsManualSeenSessionDefaults(service);
    if (!defaults) {
        SPKLog(@"Instants", @"manual seen: mark %@ failed, session defaults unreachable", mediaPK);
        return;
    }

    NSArray<NSString *> *seen = SPKInstantsManualSeenStateList(defaults) ?: @[];
    if ([seen containsObject:mediaPK]) {
        // It had not been stripped yet, so dropping the hold above is enough.
        SPKInstantsManualSeenReloadStateUnlessViewing(service);
        return;
    }
    NSMutableArray<NSString *> *next = [seen mutableCopy];
    [next addObject:mediaPK];
    if (!SPKInstantsManualSeenWriteStateList(defaults, next))
        return;
    SPKLog(@"Instants", @"manual seen: released %@ (seen list now %lu, viewer=%@)",
           mediaPK, (unsigned long)next.count, sViewerOpen ? @"open" : @"closed");
    SPKInstantsManualSeenReloadStateUnlessViewing(service);
}

// MARK: - Seen Sync Block

/// Instagram pushes its local seen state to the server, and a later tray fetch trusts that
/// server state. Without this, an Instant held locally unseen still disappears the
/// next time the tray is refetched, because the server already considers it seen.
typedef void (*SPKInstantsSyncSeenIMP)(id, SEL, id, id, id);
static SPKInstantsSyncSeenIMP orig_instantsSyncSeenSnaps = NULL;

static void replaced_instantsSyncSeenSnaps(id self, SEL _cmd, id sessionId, id onSuccess, id onFailure) {
    if (SPKInstantsManualSeenIsEnabled()) {
        sCachedService = self;
        // Neither completion is invoked. Their argument lists are not declared in the
        // interface, so calling one blind would be a guess; leaving the request pending only
        // defers Instagram's own retry, which this feature suppresses again anyway.
        SPKLog(@"Instants", @"manual seen: suppressed seen sync to the server");
        return;
    }
    if (orig_instantsSyncSeenSnaps)
        orig_instantsSyncSeenSnaps(self, _cmd, sessionId, onSuccess, onFailure);
}

// MARK: - Seen Request Filter

/// Every seen mutation is built from this input, including batches the sync hook never sees,
/// so its id list is emptied here. The request still goes out with nothing to mark, and no
/// caller waits on a missing reply.
typedef id (*SPKInstantsSeenRequestInitIMP)(id, SEL, id);
typedef void (*SPKInstantsSeenRequestSetIMP)(id, SEL, id);
static SPKInstantsSeenRequestInitIMP orig_seenRequestInitWithMediaIds = NULL;
static SPKInstantsSeenRequestSetIMP orig_seenRequestSetMediaIds = NULL;

static id SPKInstantsManualSeenFilteredMediaIds(id ids) {
    if (!SPKInstantsManualSeenIsEnabled() || ![ids isKindOfClass:NSArray.class] || [(NSArray *)ids count] == 0)
        return ids;
    SPKLog(@"Instants", @"manual seen: stripped %lu id(s) from a seen request",
           (unsigned long)[(NSArray *)ids count]);
    return @[];
}

static id replaced_seenRequestInitWithMediaIds(id self, SEL _cmd, id ids) {
    return orig_seenRequestInitWithMediaIds(self, _cmd, SPKInstantsManualSeenFilteredMediaIds(ids));
}

static void replaced_seenRequestSetMediaIds(id self, SEL _cmd, id ids) {
    orig_seenRequestSetMediaIds(self, _cmd, SPKInstantsManualSeenFilteredMediaIds(ids));
}

static void SPKInstallInstantsSeenRequestFilter(void) {
    Class requestClass = objc_getClass("IGXDTMarkQuickSnapSeenRequest");
    if (!requestClass) {
        SPKLog(@"Instants", @"manual seen: seen-request filter skipped, class unavailable");
        return;
    }
    if (class_getInstanceMethod(requestClass, @selector(initWithMediaIds:)))
        MSHookMessageEx(requestClass, @selector(initWithMediaIds:), (IMP)replaced_seenRequestInitWithMediaIds,
                        (IMP *)&orig_seenRequestInitWithMediaIds);
    if (class_getInstanceMethod(requestClass, @selector(setMediaIds:)))
        MSHookMessageEx(requestClass, @selector(setMediaIds:), (IMP)replaced_seenRequestSetMediaIds,
                        (IMP *)&orig_seenRequestSetMediaIds);
    SPKLog(@"Instants", @"manual seen: seen-request filter installed (init=%@ set=%@)",
           orig_seenRequestInitWithMediaIds ? @"YES" : @"NO", orig_seenRequestSetMediaIds ? @"YES" : @"NO");
}

void SPKInstallInstantsManualSeenHooksIfEnabled(void) {
    static BOOL sInstalled = NO;
    if (sInstalled)
        return;
    sInstalled = YES;

    // Installed regardless of the pref: the hooks re-read it at call time, so the toggle
    // works without a restart.
    SPKInstallInstantsSeenRequestFilter();
    Class serviceClass = objc_getClass("_TtC18IGQuickSnapService18IGQuickSnapService");
    SEL sel = @selector(syncSeenSnapsWithServerWithDirectSessionId:onSuccess:onFailure:);
    if (!serviceClass || !class_getInstanceMethod(serviceClass, sel)) {
        SPKLog(@"Instants", @"manual seen: seen-sync hook skipped, selector unavailable");
        return;
    }
    MSHookMessageEx(serviceClass, sel, (IMP)replaced_instantsSyncSeenSnaps,
                    (IMP *)&orig_instantsSyncSeenSnaps);
    SPKLog(@"Instants", @"manual seen: seen-sync hook installed");
}
