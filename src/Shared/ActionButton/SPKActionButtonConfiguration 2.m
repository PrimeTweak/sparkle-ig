#import "SPKActionButtonConfiguration.h"
#import "../../Settings/SPKPreferences.h"
#import "../../Utils.h"
#import "SPKActionDescriptor.h"

static NSArray<NSString *> *SPKFilteredActionArray(NSArray *values, NSArray<NSString *> *supported) {
    NSMutableOrderedSet<NSString *> *filtered = [NSMutableOrderedSet orderedSet];
    for (id value in values) {
        if ([value isKindOfClass:[NSString class]] && [supported containsObject:value]) {
            [filtered addObject:value];
        }
    }
    return filtered.array;
}

static NSArray<NSString *> *SPKFilteredUniqueActionArray(NSArray *values, NSArray<NSString *> *supported) {
    return SPKFilteredActionArray(values, supported);
}

NSString *const kSPKActionMenuTopLevelSectionIdentifier = @"menu";
NSString *const kSPKActionMenuBulkSectionIdentifier = @"bulk";

// Bumped when the stored shape changes so an existing config is migrated once.
// Version 2 is the Configure Menu model: a "menu" section at index 0 holding the
// first level, submenus after it, bulk last.
static NSString *const kSPKActionConfigModelVersionKey = @"model_version";
static const NSInteger kSPKActionConfigModelVersion = 2;

NSString *SPKActionButtonTopicKeyForSource(SPKActionButtonSource source) {
    switch (source) {
    case SPKActionButtonSourceFeed:
        return @"feed";
    case SPKActionButtonSourceReels:
        return @"reels";
    case SPKActionButtonSourceStories:
        return @"stories";
    case SPKActionButtonSourceDirect:
        return @"msgs";
    case SPKActionButtonSourceProfile:
        return @"profile";
    case SPKActionButtonSourceInstants:
        return @"instants";
    }
}

NSString *SPKActionButtonTopicTitleForSource(SPKActionButtonSource source) {
    switch (source) {
    case SPKActionButtonSourceFeed:
        return @"Feed";
    case SPKActionButtonSourceReels:
        return @"Reels";
    case SPKActionButtonSourceStories:
        return @"Stories";
    case SPKActionButtonSourceDirect:
        return @"Messages";
    case SPKActionButtonSourceProfile:
        return @"Profile";
    case SPKActionButtonSourceInstants:
        return @"Instants";
    }
}

NSArray<NSString *> *SPKActionButtonSupportedActionsForSource(SPKActionButtonSource source) {
    switch (source) {
    case SPKActionButtonSourceFeed:
    case SPKActionButtonSourceReels:
        return @[
            kSPKActionDownloadLibrary,
            kSPKActionDownloadShare,
            kSPKActionCopyDownloadLink,
            kSPKActionCopyMedia,
            kSPKActionDownloadGallery,
            kSPKActionTrimSave,
            kSPKActionEditSave,
            kSPKActionDownloadAudio,
            kSPKActionDownloadAudioShare,
            kSPKActionDownloadAudioGallery,
            kSPKActionPlayAudio,
            kSPKActionCopyAudioURL,
            kSPKActionExpand,
            kSPKActionViewThumbnail,
            kSPKActionCopyCaption,
            kSPKActionOpenTopicSettings,
            kSPKActionRepost
        ];
    case SPKActionButtonSourceStories:
        return @[
            kSPKActionDownloadLibrary,
            kSPKActionDownloadShare,
            kSPKActionCopyDownloadLink,
            kSPKActionCopyMedia,
            kSPKActionDownloadGallery,
            kSPKActionTrimSave,
            kSPKActionEditSave,
            kSPKActionDownloadAudio,
            kSPKActionDownloadAudioShare,
            kSPKActionDownloadAudioGallery,
            kSPKActionPlayAudio,
            kSPKActionCopyAudioURL,
            kSPKActionExpand,
            kSPKActionViewThumbnail,
            kSPKActionStoryMentionsSheet,
            kSPKActionToggleStorySeenUserRule,
            kSPKActionToggleStoryAutoSaveUserRule,
            kSPKActionOpenTopicSettings
        ];
    case SPKActionButtonSourceDirect:
        return @[
            kSPKActionDownloadLibrary,
            kSPKActionDownloadShare,
            kSPKActionCopyDownloadLink,
            kSPKActionCopyMedia,
            kSPKActionDownloadGallery,
            kSPKActionTrimSave,
            kSPKActionEditSave,
            kSPKActionDownloadAudio,
            kSPKActionDownloadAudioShare,
            kSPKActionDownloadAudioGallery,
            kSPKActionPlayAudio,
            kSPKActionCopyAudioURL,
            kSPKActionExpand,
            kSPKActionViewThumbnail,
            kSPKActionDeletedMessagesLog,
            kSPKActionToggleDirectAutoSaveThreadRule,
            kSPKActionOpenTopicSettings
        ];
    case SPKActionButtonSourceInstants:
        return @[
            kSPKActionDownloadLibrary,
            kSPKActionDownloadShare,
            kSPKActionCopyDownloadLink,
            kSPKActionCopyMedia,
            kSPKActionDownloadGallery,
            kSPKActionTrimSave,
            kSPKActionEditSave,
            kSPKActionExpand,
            kSPKActionViewThumbnail,
            kSPKActionOpenTopicSettings
        ];
    case SPKActionButtonSourceProfile:
        return @[
            kSPKActionDownloadLibrary,
            kSPKActionDownloadShare,
            kSPKActionCopyDownloadLink,
            kSPKActionCopyMedia,
            kSPKActionDownloadGallery,
            kSPKActionEditSave,
            kSPKActionExpand,
            kSPKActionProfileCopyInfo,
            kSPKActionToggleProfileStorySeenUserRule,
            kSPKActionToggleProfileMessagesSeenUserRule,
            kSPKActionOpenTopicSettings
        ];
    }
}

NSArray<NSString *> *SPKActionButtonBulkDownloadSupportedActionsForSource(SPKActionButtonSource source) {
    switch (source) {
    case SPKActionButtonSourceFeed:
    case SPKActionButtonSourceReels:
    case SPKActionButtonSourceStories:
    case SPKActionButtonSourceInstants:
    case SPKActionButtonSourceDirect:
        return @[
            kSPKActionDownloadAllLibrary,
            kSPKActionDownloadAllShare,
            kSPKActionDownloadAllGallery
        ];
    case SPKActionButtonSourceProfile:
        return @[];
    }
}

NSArray<NSString *> *SPKActionButtonBulkCopySupportedActionsForSource(SPKActionButtonSource source) {
    switch (source) {
    case SPKActionButtonSourceFeed:
    case SPKActionButtonSourceReels:
    case SPKActionButtonSourceStories:
    case SPKActionButtonSourceInstants:
    case SPKActionButtonSourceDirect:
        return @[
            kSPKActionDownloadAllClipboard,
            kSPKActionDownloadAllLinks
        ];
    case SPKActionButtonSourceProfile:
        return @[];
    }
}

// Maps a single-item action identifier to its bulk "all" counterpart, or nil
// when the action has no bulk equivalent.
static NSString *SPKBulkAllIdentifierForBaseAction(NSString *identifier) {
    if ([identifier isEqualToString:kSPKActionDownloadLibrary])
        return kSPKActionDownloadAllLibrary;
    if ([identifier isEqualToString:kSPKActionDownloadShare])
        return kSPKActionDownloadAllShare;
    if ([identifier isEqualToString:kSPKActionDownloadGallery])
        return kSPKActionDownloadAllGallery;
    if ([identifier isEqualToString:kSPKActionCopyMedia])
        return kSPKActionDownloadAllClipboard;
    if ([identifier isEqualToString:kSPKActionCopyDownloadLink])
        return kSPKActionDownloadAllLinks;
    return nil;
}

// Bulk destinations are derived from the user's single-item action config:
// every enabled single-item download/copy action contributes its bulk-all
// counterpart, in the same order. This keeps the "Bulk" menu in lockstep with
// the rest of the action button (no separate bulk store / editor).
static NSArray<NSString *> *SPKDerivedBulkActionsForSource(SPKActionButtonSource source, NSArray<NSString *> *supportedBulk) {
    if (supportedBulk.count == 0)
        return @[];
    SPKActionButtonConfiguration *configuration =
        [SPKActionButtonConfiguration configurationForSource:source
                                                  topicTitle:SPKActionButtonTopicTitleForSource(source)
                                            supportedActions:SPKActionButtonSupportedActionsForSource(source)
                                             defaultSections:SPKActionButtonDefaultSectionsForSource(source)];
    NSMutableOrderedSet<NSString *> *result = [NSMutableOrderedSet orderedSet];
    for (SPKActionMenuSection *section in [configuration visibleSections]) {
        for (NSString *identifier in section.actions) {
            NSString *bulk = SPKBulkAllIdentifierForBaseAction(identifier);
            if (bulk && [supportedBulk containsObject:bulk]) {
                [result addObject:bulk];
            }
        }
    }
    return result.array;
}

NSArray<NSString *> *SPKActionButtonConfiguredBulkDownloadActionsForSource(SPKActionButtonSource source) {
    return SPKDerivedBulkActionsForSource(source, SPKActionButtonBulkDownloadSupportedActionsForSource(source));
}

NSArray<NSString *> *SPKActionButtonConfiguredBulkCopyActionsForSource(SPKActionButtonSource source) {
    return SPKDerivedBulkActionsForSource(source, SPKActionButtonBulkCopySupportedActionsForSource(source));
}

NSArray<SPKActionMenuSection *> *SPKActionButtonDefaultSectionsForSource(SPKActionButtonSource source) {
    NSMutableArray<SPKActionMenuSection *> *sections = [NSMutableArray array];
    NSArray<NSString *> *downloadActions = @[
        kSPKActionDownloadLibrary,
        kSPKActionDownloadShare,
        kSPKActionDownloadGallery,
        kSPKActionEditSave,
        kSPKActionTrimSave
    ];
    NSArray<NSString *> *audioActions = (source == SPKActionButtonSourceFeed ||
                                         source == SPKActionButtonSourceReels ||
                                         source == SPKActionButtonSourceStories ||
                                         source == SPKActionButtonSourceDirect)
                                            ? @[
                                                  kSPKActionDownloadAudio,
                                                  kSPKActionDownloadAudioShare,
                                                  kSPKActionDownloadAudioGallery,
                                                  kSPKActionPlayAudio,
                                                  kSPKActionCopyAudioURL
                                              ]
                                            : @[];
    // Zoom: expand + view thumbnail (profile has no thumbnail).
    NSArray<NSString *> *zoomActions = (source == SPKActionButtonSourceProfile)
                                           ? @[ kSPKActionExpand ]
                                           : @[ kSPKActionExpand, kSPKActionViewThumbnail ];
    NSArray<NSString *> *copyActions = (source == SPKActionButtonSourceProfile)
                                           ? @[ kSPKActionCopyDownloadLink, kSPKActionCopyMedia, kSPKActionProfileCopyInfo ]
                                           : ((source == SPKActionButtonSourceFeed || source == SPKActionButtonSourceReels)
                                                  ? @[ kSPKActionCopyDownloadLink, kSPKActionCopyMedia, kSPKActionCopyCaption ]
                                                  : @[ kSPKActionCopyDownloadLink, kSPKActionCopyMedia ]);
    NSArray<NSString *> *moreActions;
    if (source == SPKActionButtonSourceFeed || source == SPKActionButtonSourceReels) {
        moreActions = @[ kSPKActionRepost, kSPKActionOpenTopicSettings ];
    } else if (source == SPKActionButtonSourceStories) {
        moreActions = @[ kSPKActionStoryMentionsSheet, kSPKActionToggleStorySeenUserRule, kSPKActionToggleStoryAutoSaveUserRule, kSPKActionOpenTopicSettings ];
    } else if (source == SPKActionButtonSourceDirect) {
        moreActions = @[ kSPKActionDeletedMessagesLog, kSPKActionToggleDirectAutoSaveThreadRule, kSPKActionOpenTopicSettings ];
    } else if (source == SPKActionButtonSourceProfile) {
        moreActions = @[ kSPKActionToggleProfileStorySeenUserRule, kSPKActionToggleProfileMessagesSeenUserRule, kSPKActionOpenTopicSettings ];
    } else {
        moreActions = @[ kSPKActionOpenTopicSettings ];
    }

    // Download, Copy, More: what people reach for, in that order. Audio and Zoom
    // follow when the surface has them.
    [sections addObject:[SPKActionMenuSection sectionWithIdentifier:@"download"
                                                              title:@"Download"
                                                           iconName:@"download"
                                                        collapsible:YES
                                                            actions:downloadActions]];
    [sections addObject:[SPKActionMenuSection sectionWithIdentifier:@"copy"
                                                              title:@"Copy"
                                                           iconName:@"copy"
                                                        collapsible:YES
                                                            actions:copyActions]];
    if (moreActions.count > 0) {
        [sections addObject:[SPKActionMenuSection sectionWithIdentifier:@"more"
                                                                  title:@"More"
                                                               iconName:@"more"
                                                            collapsible:YES
                                                                actions:moreActions]];
    }
    if (audioActions.count > 0) {
        [sections addObject:[SPKActionMenuSection sectionWithIdentifier:@"audio"
                                                                  title:@"Audio"
                                                               iconName:@"audio_upload"
                                                            collapsible:YES
                                                                actions:audioActions]];
    }
    if (zoomActions.count > 0) {
        [sections addObject:[SPKActionMenuSection sectionWithIdentifier:@"zoom"
                                                                  title:@"Zoom"
                                                               iconName:@"zoom"
                                                            collapsible:YES
                                                                actions:zoomActions]];
    }
    return sections;
}

@implementation SPKActionButtonConfiguration

+ (instancetype)configurationForSource:(SPKActionButtonSource)source
                            topicTitle:(NSString *)topicTitle
                      supportedActions:(NSArray<NSString *> *)supportedActions
                       defaultSections:(NSArray<SPKActionMenuSection *> *)defaultSections {
    SPKActionButtonConfiguration *configuration = [[self alloc] init];
    configuration.source = source;
    configuration.topicTitle = topicTitle.length > 0 ? topicTitle : SPKActionButtonTopicTitleForSource(source);
    configuration.supportedActions = supportedActions.count > 0 ? supportedActions : SPKActionButtonSupportedActionsForSource(source);
    configuration.sections = [NSMutableArray array];
    configuration.disabledActions = [NSMutableArray array];
    configuration.unassignedActions = [NSMutableArray array];
    configuration.excludedBulkActions = [NSMutableArray array];

    id storedValue = SPKPreferenceObjectForKey([configuration configDefaultsKey]);
    NSDictionary *stored = [storedValue isKindOfClass:[NSDictionary class]] ? storedValue : nil;
    if ([stored isKindOfClass:[NSDictionary class]]) {
        NSArray *storedSections = [stored[@"sections"] isKindOfClass:[NSArray class]] ? stored[@"sections"] : @[];
        for (NSDictionary *dictionary in storedSections) {
            SPKActionMenuSection *section = [SPKActionMenuSection sectionFromDictionary:dictionary];
            if (section)
                [configuration.sections addObject:section];
        }
        [configuration.disabledActions addObjectsFromArray:SPKFilteredActionArray(stored[@"disabled_actions"], configuration.supportedActions)];
        [configuration.unassignedActions addObjectsFromArray:SPKFilteredActionArray(stored[@"unassigned_actions"], configuration.supportedActions)];
        for (id value in ([stored[@"excluded_bulk_actions"] isKindOfClass:[NSArray class]] ? stored[@"excluded_bulk_actions"] : @[])) {
            if ([value isKindOfClass:[NSString class]] && ![configuration.excludedBulkActions containsObject:value])
                [configuration.excludedBulkActions addObject:value];
        }
    }

    if (configuration.sections.count == 0) {
        for (SPKActionMenuSection *section in (defaultSections.count > 0 ? defaultSections : SPKActionButtonDefaultSectionsForSource(source))) {
            [configuration.sections addObject:[section copy]];
        }
    }

    // Ensure a reorderable "Bulk" section exists on sources that support bulk
    // downloads. Its contents are derived from the single-item actions, so it has
    // no stored actions of its own; users reorder/rename it like any section.
    // Injected here (not only in the defaults) so existing persisted configs pick
    // it up too. Profile has no bulk support, so it is skipped there.
    if (SPKActionButtonBulkDownloadSupportedActionsForSource(source).count > 0 ||
        SPKActionButtonBulkCopySupportedActionsForSource(source).count > 0) {
        BOOL hasBulkSection = NO;
        for (SPKActionMenuSection *section in configuration.sections) {
            if ([section.identifier isEqualToString:kSPKActionMenuBulkSectionIdentifier]) {
                hasBulkSection = YES;
                break;
            }
        }
        if (!hasBulkSection) {
            SPKActionMenuSection *bulkSection = [SPKActionMenuSection sectionWithIdentifier:kSPKActionMenuBulkSectionIdentifier
                                                                                      title:@"Bulk"
                                                                                   iconName:@"carousel"
                                                                                collapsible:YES
                                                                                    actions:@[]];
            // Appended last so the Bulk section is the bottom-most when available.
            [configuration.sections addObject:bulkSection];
        }
    }

    NSNumber *storedVersion = [stored[kSPKActionConfigModelVersionKey] isKindOfClass:[NSNumber class]] ? stored[kSPKActionConfigModelVersionKey] : nil;
    if (storedVersion.integerValue < kSPKActionConfigModelVersion)
        [configuration migrateToConfigureMenuModel];

    [configuration seedBulkSectionIfNeeded];
    [configuration normalize];
    return configuration;
}

// Runs once per surface, on the first load of the Configure Menu model.
// Nothing is dropped: every action either stays where it was, rises to the first
// level, or lands in "Not in the Menu".
- (void)migrateToConfigureMenuModel {
    NSMutableArray<NSString *> *risingActions = [NSMutableArray array];
    NSMutableArray<SPKActionMenuSection *> *submenus = [NSMutableArray array];
    SPKActionMenuSection *bulk = nil;
    SPKActionMenuSection *existingTop = nil;

    for (SPKActionMenuSection *section in self.sections) {
        if ([section.identifier isEqualToString:kSPKActionMenuBulkSectionIdentifier])
            bulk = section;
        else if ([section.identifier isEqualToString:kSPKActionMenuTopLevelSectionIdentifier])
            existingTop = section;
        else if (section.collapsible)
            [submenus addObject:section];
        else
            [risingActions addObjectsFromArray:section.actions];   // an unfolded group is the first level
    }

    SPKActionMenuSection *top = existingTop;
    if (!top) {
        top = [SPKActionMenuSection sectionWithIdentifier:kSPKActionMenuTopLevelSectionIdentifier
                                                    title:@"Menu"
                                                 iconName:@"action"
                                              collapsible:NO
                                                  actions:@[]];
    }
    top.collapsible = NO;
    for (NSString *identifier in risingActions) {
        if (![top.actions containsObject:identifier])
            [top.actions addObject:identifier];
    }

    NSMutableArray<SPKActionMenuSection *> *ordered = [NSMutableArray arrayWithObject:top];
    [ordered addObjectsFromArray:submenus];
    if (bulk)
        [ordered addObject:bulk];
    self.sections = ordered;

    // "Disabled" is no longer a state of its own: those actions are the rows of
    // "Not in the Menu", so they leave their section for that list.
    for (NSString *identifier in [self.disabledActions copy]) {
        for (SPKActionMenuSection *section in self.sections)
            [section.actions removeObject:identifier];
        if (![self.unassignedActions containsObject:identifier])
            [self.unassignedActions addObject:identifier];
    }
    [self.disabledActions removeAllObjects];
}

- (NSString *)configDefaultsKey {
    return SPKPrefActionButtonConfigKey(SPKActionButtonTopicKeyForSource(self.source));
}

- (NSDictionary *)dictionaryRepresentation {
    NSMutableArray *sectionDictionaries = [NSMutableArray array];
    for (SPKActionMenuSection *section in self.sections) {
        [sectionDictionaries addObject:[section dictionaryRepresentation]];
    }
    return @{
        @"sections" : sectionDictionaries,
        @"disabled_actions" : [self.disabledActions copy] ?: @[],
        @"unassigned_actions" : [self.unassignedActions copy] ?: @[],
        @"excluded_bulk_actions" : [self.excludedBulkActions copy] ?: @[],
        kSPKActionConfigModelVersionKey : @(kSPKActionConfigModelVersion)
    };
}

- (void)save {
    [self normalize];
    SPKPreferenceSetObject([self dictionaryRepresentation], [self configDefaultsKey]);
    [[NSNotificationCenter defaultCenter] postNotificationName:SPKActionButtonConfigurationDidChangeNotification object:nil];
}

- (NSArray<NSString *> *)assignedActions {
    NSMutableOrderedSet<NSString *> *assigned = [NSMutableOrderedSet orderedSet];
    for (SPKActionMenuSection *section in self.sections) {
        for (NSString *identifier in section.actions) {
            if ([self.supportedActions containsObject:identifier]) {
                [assigned addObject:identifier];
            }
        }
    }
    return assigned.array;
}

- (void)normalize {
    NSArray<NSString *> *supported = self.supportedActions ?: @[];
    NSMutableOrderedSet<NSString *> *seen = [NSMutableOrderedSet orderedSet];
    NSMutableArray<SPKActionMenuSection *> *normalizedSections = [NSMutableArray array];

    for (SPKActionMenuSection *section in self.sections ?: @[]) {
        if (![section isKindOfClass:[SPKActionMenuSection class]])
            continue;
        if (section.identifier.length == 0)
            section.identifier = NSUUID.UUID.UUIDString;
        if (section.title.length == 0)
            section.title = @"Section";
        if (section.iconName.length == 0)
            section.iconName = @"more";

        // Bulk holds bulk identifiers, which are not in supportedActions — it is
        // filtered against its own supported list, and its entries never join
        // the `seen` set that de-duplicates the single-item zones.
        if ([section.identifier isEqualToString:kSPKActionMenuBulkSectionIdentifier]) {
            NSMutableArray<NSString *> *supportedBulk = [NSMutableArray array];
            [supportedBulk addObjectsFromArray:SPKActionButtonBulkDownloadSupportedActionsForSource(self.source)];
            [supportedBulk addObjectsFromArray:SPKActionButtonBulkCopySupportedActionsForSource(self.source)];
            NSMutableArray<NSString *> *keptBulk = [NSMutableArray array];
            for (NSString *identifier in section.actions) {
                if ([supportedBulk containsObject:identifier] && ![keptBulk containsObject:identifier])
                    [keptBulk addObject:identifier];
            }
            section.actions = keptBulk;
            [normalizedSections addObject:section];
            continue;
        }

        NSArray<NSString *> *filteredActions = SPKFilteredActionArray(section.actions, supported);
        NSMutableArray<NSString *> *uniqueActions = [NSMutableArray array];
        for (NSString *identifier in filteredActions) {
            if ([seen containsObject:identifier])
                continue;
            [seen addObject:identifier];
            [uniqueActions addObject:identifier];
        }
        section.actions = uniqueActions;
        [normalizedSections addObject:section];
    }

    self.sections = normalizedSections;
    self.disabledActions = [SPKFilteredActionArray(self.disabledActions, supported) mutableCopy];

    // "Not in the Menu" is an explicit list now, not the complement: an action
    // that is in no section and not on this list is catalogue stock, reachable
    // from the "+". Anything filed in a section leaves the list.
    NSMutableOrderedSet<NSString *> *unassigned = [NSMutableOrderedSet orderedSetWithArray:SPKFilteredActionArray(self.unassignedActions, supported)];
    for (NSString *identifier in seen.array) {
        [unassigned removeObject:identifier];
    }
    self.unassignedActions = unassigned.array.mutableCopy;
}

// ── The four zones ───────────────────────────────────────────────────────────

- (SPKActionMenuSection *)topLevelSection {
    SPKActionMenuSection *top = [self sectionWithIdentifier:kSPKActionMenuTopLevelSectionIdentifier];
    if (!top) {
        top = [SPKActionMenuSection sectionWithIdentifier:kSPKActionMenuTopLevelSectionIdentifier
                                                    title:@"Menu"
                                                 iconName:@"action"
                                              collapsible:NO
                                                  actions:@[]];
        [self.sections insertObject:top atIndex:0];
    }
    return top;
}

- (NSArray<SPKActionMenuSection *> *)submenuSections {
    NSMutableArray<SPKActionMenuSection *> *submenus = [NSMutableArray array];
    for (SPKActionMenuSection *section in self.sections) {
        if ([section.identifier isEqualToString:kSPKActionMenuTopLevelSectionIdentifier])
            continue;
        if ([section.identifier isEqualToString:kSPKActionMenuBulkSectionIdentifier])
            continue;
        [submenus addObject:section];
    }
    return submenus;
}

- (nullable SPKActionMenuSection *)bulkSection {
    return [self sectionWithIdentifier:kSPKActionMenuBulkSectionIdentifier];
}

// Supported by the surface, in no section, and not on the "Not in the Menu"
// list: this is what the "+" offers.
- (NSArray<NSString *> *)catalogActions {
    NSMutableArray<NSString *> *catalog = [NSMutableArray array];
    for (NSString *identifier in self.supportedActions) {
        if ([self sectionIdentifierForAction:identifier])
            continue;
        if ([self.unassignedActions containsObject:identifier])
            continue;
        [catalog addObject:identifier];
    }
    NSArray<NSString *> *inBulk = [self bulkActionsInOrder];
    for (NSString *identifier in SPKActionButtonBulkDownloadSupportedActionsForSource(self.source)) {
        if (![inBulk containsObject:identifier])
            [catalog addObject:identifier];
    }
    for (NSString *identifier in SPKActionButtonBulkCopySupportedActionsForSource(self.source)) {
        if (![inBulk containsObject:identifier])
            [catalog addObject:identifier];
    }
    return catalog;
}

- (BOOL)isBulkActionIdentifier:(NSString *)identifier {
    if (identifier.length == 0)
        return NO;
    return [SPKActionButtonBulkDownloadSupportedActionsForSource(self.source) containsObject:identifier] ||
           [SPKActionButtonBulkCopySupportedActionsForSource(self.source) containsObject:identifier];
}

// Bulk is now an ordered list the user owns, exactly like the other zones: what
// is in it, in the order it is in, is what the menu shows. Seeded once from the
// old derived order so nothing changes under him on the first launch.
- (NSArray<NSString *> *)bulkActionsInOrder {
    SPKActionMenuSection *bulk = [self bulkSection];
    return bulk ? [bulk.actions copy] : @[];
}

// Derived from THIS configuration and nothing else.
//
// The first version called SPKDerivedBulkActionsForSource, which builds a fresh
// configuration, which seeds again, which derives again: configurationForSource
// -> seedBulkSectionIfNeeded -> SPKDerivedBulkActionsForSource -> back to the
// top. Unbounded recursion, stack guard hit, Instagram down. Nothing in this
// method may load a configuration.
- (void)seedBulkSectionIfNeeded {
    SPKActionMenuSection *bulk = [self bulkSection];
    if (!bulk || bulk.actions.count > 0)
        return;

    NSArray<NSString *> *supportedDownload = SPKActionButtonBulkDownloadSupportedActionsForSource(self.source);
    NSArray<NSString *> *supportedCopy = SPKActionButtonBulkCopySupportedActionsForSource(self.source);

    // Walk the zones already parsed into self, in their own order.
    NSMutableOrderedSet<NSString *> *derived = [NSMutableOrderedSet orderedSet];
    for (SPKActionMenuSection *section in self.sections) {
        if ([section.identifier isEqualToString:kSPKActionMenuBulkSectionIdentifier])
            continue;
        for (NSString *identifier in section.actions) {
            if ([self.disabledActions containsObject:identifier] ||
                [self.unassignedActions containsObject:identifier])
                continue;
            NSString *bulkIdentifier = SPKBulkAllIdentifierForBaseAction(identifier);
            if (bulkIdentifier.length == 0)
                continue;
            if ([self.excludedBulkActions containsObject:bulkIdentifier])
                continue;   // taken out before this model existed: it stays out
            if ([supportedDownload containsObject:bulkIdentifier] || [supportedCopy containsObject:bulkIdentifier])
                [derived addObject:bulkIdentifier];
        }
    }

    // Same shape as the list he sees today: the download family first, then the
    // copy family, each in menu order.
    NSMutableArray<NSString *> *seed = [NSMutableArray array];
    for (NSString *identifier in derived.array) {
        if ([supportedDownload containsObject:identifier])
            [seed addObject:identifier];
    }
    for (NSString *identifier in derived.array) {
        if (![supportedDownload containsObject:identifier] && [supportedCopy containsObject:identifier])
            [seed addObject:identifier];
    }
    bulk.actions = seed;
}

- (void)setBulkActionIdentifier:(NSString *)identifier included:(BOOL)included {
    SPKActionMenuSection *bulk = [self bulkSection];
    if (!bulk || ![self isBulkActionIdentifier:identifier])
        return;
    if (included) {
        if (![bulk.actions containsObject:identifier])
            [bulk.actions addObject:identifier];
    } else {
        [bulk.actions removeObject:identifier];
    }
}

- (void)moveBulkActionFromIndex:(NSInteger)sourceIndex toIndex:(NSInteger)destinationIndex {
    SPKActionMenuSection *bulk = [self bulkSection];
    if (!bulk || sourceIndex < 0 || destinationIndex < 0 ||
        sourceIndex >= (NSInteger)bulk.actions.count || destinationIndex >= (NSInteger)bulk.actions.count)
        return;
    NSString *moved = bulk.actions[(NSUInteger)sourceIndex];
    [bulk.actions removeObjectAtIndex:(NSUInteger)sourceIndex];
    [bulk.actions insertObject:moved atIndex:(NSUInteger)destinationIndex];
}

- (SPKActionMenuSection *)addSubmenu {
    SPKActionMenuSection *submenu = [SPKActionMenuSection sectionWithIdentifier:NSUUID.UUID.UUIDString
                                                                          title:@"New Submenu"
                                                                       iconName:@"more"
                                                                    collapsible:YES
                                                                        actions:@[]];
    SPKActionMenuSection *bulk = [self bulkSection];
    NSInteger insertionIndex = bulk ? (NSInteger)[self.sections indexOfObject:bulk] : (NSInteger)self.sections.count;
    [self.sections insertObject:submenu atIndex:(NSUInteger)MAX(0, insertionIndex)];
    return submenu;
}

// Submenu order is expressed in the zone, not in the whole sections array: the
// first level opens the menu and bulk closes it, whatever happens in between.
- (void)moveSubmenuFromIndex:(NSInteger)sourceIndex toIndex:(NSInteger)destinationIndex {
    NSArray<SPKActionMenuSection *> *submenus = [self submenuSections];
    if (sourceIndex < 0 || destinationIndex < 0 ||
        sourceIndex >= (NSInteger)submenus.count || destinationIndex >= (NSInteger)submenus.count)
        return;

    NSMutableArray<SPKActionMenuSection *> *reordered = [submenus mutableCopy];
    SPKActionMenuSection *moved = reordered[(NSUInteger)sourceIndex];
    [reordered removeObjectAtIndex:(NSUInteger)sourceIndex];
    [reordered insertObject:moved atIndex:(NSUInteger)destinationIndex];

    NSMutableArray<SPKActionMenuSection *> *ordered = [NSMutableArray arrayWithObject:[self topLevelSection]];
    [ordered addObjectsFromArray:reordered];
    SPKActionMenuSection *bulk = [self bulkSection];
    if (bulk)
        [ordered addObject:bulk];
    self.sections = ordered;
}

- (nullable SPKActionMenuSection *)sectionWithIdentifier:(NSString *)identifier {
    for (SPKActionMenuSection *section in self.sections) {
        if ([section.identifier isEqualToString:identifier])
            return section;
    }
    return nil;
}

- (NSArray<SPKActionMenuSection *> *)visibleSections {
    NSMutableArray<SPKActionMenuSection *> *visible = [NSMutableArray array];
    for (SPKActionMenuSection *section in self.sections) {
        NSMutableArray<NSString *> *actions = [NSMutableArray array];
        BOOL isBulk = [section.identifier isEqualToString:kSPKActionMenuBulkSectionIdentifier];
        for (NSString *identifier in section.actions) {
            if (isBulk || (![self.disabledActions containsObject:identifier] && ![self.unassignedActions containsObject:identifier])) {
                [actions addObject:identifier];
            }
        }
        if (actions.count == 0)
            continue;
        [visible addObject:[SPKActionMenuSection sectionWithIdentifier:section.identifier
                                                                 title:section.title
                                                              iconName:section.iconName
                                                           collapsible:section.collapsible
                                                               actions:actions]];
    }
    return visible;
}

- (nullable NSString *)sectionIdentifierForAction:(NSString *)identifier {
    for (SPKActionMenuSection *section in self.sections) {
        if ([section.actions containsObject:identifier]) {
            return section.identifier;
        }
    }
    return nil;
}

- (void)setAction:(NSString *)identifier assignedToSectionIdentifier:(NSString *)sectionIdentifier {
    if (![self.supportedActions containsObject:identifier])
        return;

    for (SPKActionMenuSection *section in self.sections) {
        [section.actions removeObject:identifier];
    }
    [self.unassignedActions removeObject:identifier];

    if (sectionIdentifier.length > 0) {
        SPKActionMenuSection *section = [self sectionWithIdentifier:sectionIdentifier];
        if (section && ![section.actions containsObject:identifier]) {
            [section.actions addObject:identifier];
        }
    } else {
        if (![self.unassignedActions containsObject:identifier]) {
            [self.unassignedActions addObject:identifier];
        }
    }
    [self normalize];
}

- (void)moveSectionFromIndex:(NSInteger)sourceIndex toIndex:(NSInteger)destinationIndex {
    if (sourceIndex < 0 || destinationIndex < 0 || sourceIndex >= self.sections.count || destinationIndex >= self.sections.count)
        return;
    SPKActionMenuSection *section = self.sections[sourceIndex];
    [self.sections removeObjectAtIndex:sourceIndex];
    [self.sections insertObject:section atIndex:destinationIndex];
}

- (void)moveActionInSectionIdentifier:(NSString *)sectionIdentifier fromIndex:(NSInteger)sourceIndex toIndex:(NSInteger)destinationIndex {
    SPKActionMenuSection *section = [self sectionWithIdentifier:sectionIdentifier];
    if (!section)
        return;
    if (sourceIndex < 0 || destinationIndex < 0 || sourceIndex >= section.actions.count || destinationIndex >= section.actions.count)
        return;
    NSString *identifier = section.actions[sourceIndex];
    [section.actions removeObjectAtIndex:sourceIndex];
    [section.actions insertObject:identifier atIndex:destinationIndex];
}

@end

NSArray<NSString *> *SPKProfileCopyInfoSupportedActions(void) {
    return @[
        kSPKActionProfileCopyID,
        kSPKActionProfileCopyUsername,
        kSPKActionProfileCopyName,
        kSPKActionProfileCopyBio,
        kSPKActionProfileCopyLink
    ];
}

NSArray<NSString *> *SPKProfileConfiguredCopyInfoActions(void) {
    NSArray<NSString *> *supported = SPKProfileCopyInfoSupportedActions();
    id storedValue = SPKPreferenceObjectForKey(@"profile_action_btn_copy_info_submenu_actions");
    NSArray *stored = [storedValue isKindOfClass:[NSArray class]] ? storedValue : nil;
    NSArray<NSString *> *filtered = SPKFilteredUniqueActionArray(stored, supported);
    return filtered.count > 0 ? filtered : supported;
}

void SPKProfileSetConfiguredCopyInfoActions(NSArray<NSString *> *actions) {
    SPKPreferenceSetObject(SPKFilteredUniqueActionArray(actions, SPKProfileCopyInfoSupportedActions()),
                           @"profile_action_btn_copy_info_submenu_actions");
    [[NSNotificationCenter defaultCenter] postNotificationName:SPKActionButtonConfigurationDidChangeNotification object:nil];
}
