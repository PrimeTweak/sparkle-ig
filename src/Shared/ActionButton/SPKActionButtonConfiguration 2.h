#pragma once

#import "ActionButtonCore.h"
#import "SPKActionMenuSection.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SPKActionButtonConfiguration : NSObject

@property (nonatomic) SPKActionButtonSource source;
@property (nonatomic, copy) NSString *topicTitle;
@property (nonatomic, copy) NSArray<NSString *> *supportedActions;
@property (nonatomic, strong) NSMutableArray<SPKActionMenuSection *> *sections;
@property (nonatomic, strong) NSMutableArray<NSString *> *disabledActions;
@property (nonatomic, strong) NSMutableArray<NSString *> *unassignedActions;
// Bulk rows the user took out. Bulk itself stays derived from the single-item
// actions; this is the one thing about it that is stored.
@property (nonatomic, strong) NSMutableArray<NSString *> *excludedBulkActions;

+ (instancetype)configurationForSource:(SPKActionButtonSource)source
                            topicTitle:(NSString *)topicTitle
                      supportedActions:(NSArray<NSString *> *)supportedActions
                       defaultSections:(NSArray<SPKActionMenuSection *> *)defaultSections;

- (NSString *)configDefaultsKey;
- (SPKActionMenuSection *)topLevelSection;
- (NSArray<SPKActionMenuSection *> *)submenuSections;
- (nullable SPKActionMenuSection *)bulkSection;
- (NSArray<NSString *> *)catalogActions;
- (BOOL)isBulkActionIdentifier:(NSString *)identifier;
- (NSArray<NSString *> *)bulkActionsInOrder;
- (void)setBulkActionIdentifier:(NSString *)identifier included:(BOOL)included;
- (void)moveBulkActionFromIndex:(NSInteger)sourceIndex toIndex:(NSInteger)destinationIndex;
- (SPKActionMenuSection *)addSubmenu;
- (void)moveSubmenuFromIndex:(NSInteger)sourceIndex toIndex:(NSInteger)destinationIndex;
- (NSDictionary *)dictionaryRepresentation;
- (void)save;
- (void)normalize;
- (nullable SPKActionMenuSection *)sectionWithIdentifier:(NSString *)identifier;
- (NSArray<SPKActionMenuSection *> *)visibleSections;
- (NSArray<NSString *> *)assignedActions;
- (nullable NSString *)sectionIdentifierForAction:(NSString *)identifier;
- (void)setAction:(NSString *)identifier assignedToSectionIdentifier:(nullable NSString *)sectionIdentifier;
- (void)moveSectionFromIndex:(NSInteger)sourceIndex toIndex:(NSInteger)destinationIndex;
- (void)moveActionInSectionIdentifier:(NSString *)sectionIdentifier fromIndex:(NSInteger)sourceIndex toIndex:(NSInteger)destinationIndex;

@end

// The four zones of Configure Menu. "menu" is the first level of the runtime
// menu (collapsible NO), every other non-bulk section is a submenu, "bulk" is
// derived from the single-item actions, and whatever is in neither a section
// nor unassignedActions is catalogue stock reachable from the "+".
FOUNDATION_EXPORT NSString *const kSPKActionMenuTopLevelSectionIdentifier;
FOUNDATION_EXPORT NSString *const kSPKActionMenuBulkSectionIdentifier;

FOUNDATION_EXPORT NSString *SPKActionButtonTopicKeyForSource(SPKActionButtonSource source);
FOUNDATION_EXPORT NSString *SPKActionButtonTopicTitleForSource(SPKActionButtonSource source);
FOUNDATION_EXPORT NSArray<NSString *> *SPKActionButtonSupportedActionsForSource(SPKActionButtonSource source);
FOUNDATION_EXPORT NSArray<SPKActionMenuSection *> *SPKActionButtonDefaultSectionsForSource(SPKActionButtonSource source);
FOUNDATION_EXPORT NSArray<NSString *> *SPKActionButtonBulkDownloadSupportedActionsForSource(SPKActionButtonSource source);
FOUNDATION_EXPORT NSArray<NSString *> *SPKActionButtonBulkCopySupportedActionsForSource(SPKActionButtonSource source);
// Bulk destinations are derived from the configured single-item actions (see
// implementation); there is no separate bulk store to set.
FOUNDATION_EXPORT NSArray<NSString *> *SPKActionButtonConfiguredBulkDownloadActionsForSource(SPKActionButtonSource source);
FOUNDATION_EXPORT NSArray<NSString *> *SPKActionButtonConfiguredBulkCopyActionsForSource(SPKActionButtonSource source);

FOUNDATION_EXPORT NSArray<NSString *> *SPKProfileCopyInfoSupportedActions(void);
FOUNDATION_EXPORT NSArray<NSString *> *SPKProfileConfiguredCopyInfoActions(void);
FOUNDATION_EXPORT void SPKProfileSetConfiguredCopyInfoActions(NSArray<NSString *> *actions);

NS_ASSUME_NONNULL_END
