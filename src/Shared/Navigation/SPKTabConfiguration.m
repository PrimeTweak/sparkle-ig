#import "SPKTabConfiguration.h"

#import "../../Utils.h"

NSString *const SPKTabLayoutDefault = @"default";
NSString *const SPKTabLayoutCustom = @"custom";
NSString *const SPKTabLayoutClassic = @"classic";

NSString *const SPKTabIdentifierFeed = @"feed";
NSString *const SPKTabIdentifierClips = @"clips";
NSString *const SPKTabIdentifierDirect = @"direct";
NSString *const SPKTabIdentifierSearch = @"search";
NSString *const SPKTabIdentifierProfile = @"profile";
NSString *const SPKTabIdentifierCreate = @"create";
NSString *const SPKTabIdentifierSaved = @"saved";

NSString *const SPKTabSavedCarrierNone = @"none";

NSString *const SPKPrefTabLayout = @"interface_nav_order";
NSString *const SPKPrefCustomTabOrder = @"interface_custom_tab_order";
NSString *const SPKPrefSavedTabCarrier = @"interface_saved_tab_carrier";
NSString *const SPKPrefLaunchTab = @"interface_launch_tab";
NSString *const SPKPrefSwipeTabs = @"interface_swipe_tabs";
NSString *const SPKPrefHideTabBarWhenSingle = @"interface_hide_tab_bar_in_messages_only";

NSArray<NSString *> *SPKCanonicalTabIdentifiers(void) {
    static NSArray<NSString *> *identifiers;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        identifiers = @[ SPKTabIdentifierFeed, SPKTabIdentifierClips, SPKTabIdentifierDirect,
                         SPKTabIdentifierSearch, SPKTabIdentifierProfile ];
    });
    return identifiers;
}

NSArray<NSString *> *SPKTabEditableIdentifiers(void) {
    static NSArray<NSString *> *identifiers;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        identifiers = [SPKCanonicalTabIdentifiers() arrayByAddingObject:SPKTabIdentifierCreate];
    });
    return identifiers;
}

NSArray<NSString *> *SPKTabOrderableIdentifiers(void) {
    static NSArray<NSString *> *identifiers;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        identifiers = [SPKCanonicalTabIdentifiers() arrayByAddingObject:SPKTabIdentifierSaved];
    });
    return identifiers;
}

// Reels first: it is the slot Saved has always used.
static NSArray<NSString *> *SPKTabSavedCarrierCandidates(void) {
    static NSArray<NSString *> *identifiers;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        identifiers = @[ SPKTabIdentifierClips, SPKTabIdentifierSearch, SPKTabIdentifierProfile,
                         SPKTabIdentifierDirect, SPKTabIdentifierFeed ];
    });
    return identifiers;
}

// Default and Classic are Instagram's own arrangements, which change between
// releases, so a borrowed slot is only trusted in Custom.
NSArray<NSString *> *SPKTabSavedCarrierPreferenceForLayout(NSString *layout) {
    if (![SPKNormalizedTabLayout(layout) isEqualToString:SPKTabLayoutCustom])
        return @[];
    return SPKTabSavedCarrierCandidates();
}

BOOL SPKTabOccupiesBarSlot(NSString *identifier, NSString *layout) {
    BOOL classic = [SPKNormalizedTabLayout(layout) isEqualToString:SPKTabLayoutClassic];
    if ([identifier isEqualToString:SPKTabIdentifierCreate])
        return classic;
    if ([identifier isEqualToString:SPKTabIdentifierDirect])
        return !classic;
    return [SPKCanonicalTabIdentifiers() containsObject:identifier] ||
           [identifier isEqualToString:SPKTabIdentifierSaved];
}

NSArray<NSString *> *SPKNormalizeTabOrder(id value) {
    NSArray *input = [value isKindOfClass:[NSArray class]] ? value : @[];
    NSSet *known = [NSSet setWithArray:SPKTabOrderableIdentifiers()];
    NSMutableOrderedSet<NSString *> *normalized = [NSMutableOrderedSet orderedSet];
    for (id candidate in input) {
        if ([candidate isKindOfClass:[NSString class]] && [known containsObject:candidate])
            [normalized addObject:candidate];
    }
    for (NSString *identifier in SPKTabOrderableIdentifiers())
        [normalized addObject:identifier];
    return normalized.array;
}

NSString *SPKNormalizedTabLayout(id value) {
    if ([value isEqual:SPKTabLayoutCustom] || [value isEqual:SPKTabLayoutClassic])
        return value;
    return SPKTabLayoutDefault;
}

NSString *SPKNormalizedSavedCarrier(id value) {
    if ([value isKindOfClass:[NSString class]] && [SPKTabSavedCarrierCandidates() containsObject:value])
        return value;
    return SPKTabSavedCarrierNone;
}

// Resolved once and reused until a preference changes: tab bar buttons ask on
// every layout pass.
static NSString *spk_cachedSavedCarrier = nil;

static void SPKInvalidateSavedCarrierCache(void) {
    @synchronized (SPKTabSavedCarrierNone) {
        spk_cachedSavedCarrier = nil;
    }
}

static NSString *SPKResolveSavedCarrier(void) {
    NSString *carrier = SPKNormalizedSavedCarrier(SPKPreferenceObjectForKey(SPKPrefSavedTabCarrier));
    if ([carrier isEqualToString:SPKTabSavedCarrierNone])
        return carrier;
    NSString *layout = SPKNormalizedTabLayout([SPKUtils getStringPref:SPKPrefTabLayout]);
    if (![layout isEqualToString:SPKTabLayoutCustom] || !SPKTabOccupiesBarSlot(carrier, layout))
        return SPKTabSavedCarrierNone;
    // A carrier whose tab is visible again would paint Saved over a visible tab.
    NSString *hideKey = SPKTabHidePreferenceKey(carrier);
    if (hideKey.length == 0 || ![SPKUtils getBoolPref:hideKey])
        return SPKTabSavedCarrierNone;
    return carrier;
}

NSString *SPKEffectiveSavedCarrier(void) {
    static dispatch_once_t observerOnce;
    dispatch_once(&observerOnce, ^{
        [NSNotificationCenter.defaultCenter addObserverForName:NSUserDefaultsDidChangeNotification
                                                        object:nil
                                                         queue:nil
                                                    usingBlock:^(__unused NSNotification *note) {
                                                        SPKInvalidateSavedCarrierCache();
                                                    }];
    });

    @synchronized (SPKTabSavedCarrierNone) {
        if (spk_cachedSavedCarrier)
            return spk_cachedSavedCarrier;
    }
    NSString *resolved = SPKResolveSavedCarrier();
    @synchronized (SPKTabSavedCarrierNone) {
        spk_cachedSavedCarrier = resolved;
    }
    return resolved;
}

NSString *SPKSingleVisibleTabIdentifier(NSString *layout, NSSet<NSString *> *hidden, NSString *savedCarrier) {
    NSString *carrier = SPKNormalizedSavedCarrier(savedCarrier);
    BOOL savedEnabled = ![carrier isEqualToString:SPKTabSavedCarrierNone] &&
                        [SPKNormalizedTabLayout(layout) isEqualToString:SPKTabLayoutCustom] &&
                        SPKTabOccupiesBarSlot(carrier, layout) && [hidden containsObject:carrier];

    // Create is not a destination, but while it shows the bar still has a second button.
    if (SPKTabOccupiesBarSlot(SPKTabIdentifierCreate, layout) &&
        ![hidden containsObject:SPKTabIdentifierCreate])
        return nil;

    NSString *single = savedEnabled ? SPKTabIdentifierSaved : nil;
    for (NSString *identifier in SPKCanonicalTabIdentifiers()) {
        if (![hidden containsObject:identifier] && SPKTabOccupiesBarSlot(identifier, layout)) {
            if (single)
                return nil;
            single = identifier;
        }
    }
    return single;
}

NSString *SPKSingleVisibleTabIdentifierFromPreferences(void) {
    NSMutableSet<NSString *> *hidden = [NSMutableSet set];
    for (NSString *identifier in SPKTabEditableIdentifiers()) {
        if ([SPKUtils getBoolPref:SPKTabHidePreferenceKey(identifier)])
            [hidden addObject:identifier];
    }
    return SPKSingleVisibleTabIdentifier(SPKNormalizedTabLayout([SPKUtils getStringPref:SPKPrefTabLayout]),
                                         hidden,
                                         SPKNormalizedSavedCarrier(SPKPreferenceObjectForKey(SPKPrefSavedTabCarrier)));
}

BOOL SPKTabConfigurationIsMessagesOnly(void) {
    return [SPKSingleVisibleTabIdentifierFromPreferences() isEqualToString:SPKTabIdentifierDirect];
}

NSString *SPKTabTitle(NSString *identifier) {
    if ([identifier isEqualToString:SPKTabIdentifierFeed]) return @"Feed";
    if ([identifier isEqualToString:SPKTabIdentifierClips]) return @"Reels";
    if ([identifier isEqualToString:SPKTabIdentifierDirect]) return @"Messages";
    if ([identifier isEqualToString:SPKTabIdentifierSearch]) return @"Explore";
    if ([identifier isEqualToString:SPKTabIdentifierProfile]) return @"Profile";
    if ([identifier isEqualToString:SPKTabIdentifierCreate]) return @"Create";
    if ([identifier isEqualToString:SPKTabIdentifierSaved]) return @"Saved";
    return identifier ?: @"Tab";
}

NSString *SPKTabIconName(NSString *identifier) {
    if ([identifier isEqualToString:SPKTabIdentifierFeed]) return @"home";
    if ([identifier isEqualToString:SPKTabIdentifierClips]) return @"reels";
    if ([identifier isEqualToString:SPKTabIdentifierDirect]) return @"messages";
    if ([identifier isEqualToString:SPKTabIdentifierSearch]) return @"search";
    if ([identifier isEqualToString:SPKTabIdentifierProfile]) return @"user_circle";
    if ([identifier isEqualToString:SPKTabIdentifierCreate]) return @"plus";
    if ([identifier isEqualToString:SPKTabIdentifierSaved]) return @"save";
    return @"circle";
}

NSString *SPKTabHidePreferenceKey(NSString *identifier) {
    if ([identifier isEqualToString:SPKTabIdentifierFeed]) return @"interface_hide_feed_tab";
    if ([identifier isEqualToString:SPKTabIdentifierClips]) return @"interface_hide_reels_tab";
    if ([identifier isEqualToString:SPKTabIdentifierDirect]) return @"interface_hide_msgs_tab";
    if ([identifier isEqualToString:SPKTabIdentifierSearch]) return @"interface_hide_explore_tab";
    if ([identifier isEqualToString:SPKTabIdentifierProfile]) return @"interface_hide_profile_tab";
    if ([identifier isEqualToString:SPKTabIdentifierCreate]) return @"interface_hide_create_tab";
    return @"";
}

NSString *SPKTabLaunchPreferenceValue(NSString *identifier) {
    if ([identifier isEqualToString:SPKTabIdentifierClips]) return @"reels";
    if ([identifier isEqualToString:SPKTabIdentifierDirect]) return @"inbox";
    if ([identifier isEqualToString:SPKTabIdentifierSearch]) return @"explore";
    return identifier ?: @"default";
}

NSString *SPKTabIdentifierForLaunchPreference(NSString *value) {
    if ([value isEqualToString:@"feed"]) return SPKTabIdentifierFeed;
    if ([value isEqualToString:@"reels"]) return SPKTabIdentifierClips;
    if ([value isEqualToString:@"inbox"]) return SPKTabIdentifierDirect;
    if ([value isEqualToString:@"explore"]) return SPKTabIdentifierSearch;
    if ([value isEqualToString:@"profile"]) return SPKTabIdentifierProfile;
    return nil;
}

void SPKMigrateTabConfigurationIfNeeded(void) {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    id storedLayout = [defaults objectForKey:SPKPrefTabLayout];
    NSArray *legacyOrder = nil;
    if ([storedLayout isEqual:@"standard"]) {
        legacyOrder = SPKCanonicalTabIdentifiers();
    } else if ([storedLayout isEqual:@"alternate"]) {
        legacyOrder = @[ SPKTabIdentifierClips, SPKTabIdentifierFeed, SPKTabIdentifierDirect,
                         SPKTabIdentifierSearch, SPKTabIdentifierProfile ];
    }
    if (legacyOrder) {
        [defaults setObject:legacyOrder forKey:SPKPrefCustomTabOrder];
        [defaults setObject:SPKTabLayoutCustom forKey:SPKPrefTabLayout];
    } else {
        NSString *layout = SPKNormalizedTabLayout(storedLayout);
        if (storedLayout && ![storedLayout isEqual:layout])
            [defaults setObject:layout forKey:SPKPrefTabLayout];
    }

    id storedOrder = [defaults objectForKey:SPKPrefCustomTabOrder];
    NSArray *normalized = SPKNormalizeTabOrder(storedOrder);
    if (![storedOrder isKindOfClass:[NSArray class]] || ![(NSArray *)storedOrder isEqualToArray:normalized])
        [defaults setObject:normalized forKey:SPKPrefCustomTabOrder];
}
