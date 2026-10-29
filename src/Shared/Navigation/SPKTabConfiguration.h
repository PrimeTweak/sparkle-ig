#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *const SPKTabLayoutDefault;
FOUNDATION_EXPORT NSString *const SPKTabLayoutCustom;
FOUNDATION_EXPORT NSString *const SPKTabLayoutClassic;

FOUNDATION_EXPORT NSString *const SPKTabIdentifierFeed;
FOUNDATION_EXPORT NSString *const SPKTabIdentifierClips;
FOUNDATION_EXPORT NSString *const SPKTabIdentifierDirect;
FOUNDATION_EXPORT NSString *const SPKTabIdentifierSearch;
FOUNDATION_EXPORT NSString *const SPKTabIdentifierProfile;
/// The Create launcher: a tab only in the Classic layout and never a destination,
/// so it stays outside the canonical order.
FOUNDATION_EXPORT NSString *const SPKTabIdentifierCreate;
/// Saved has no surface of its own: it borrows a hidden native tab (the carrier),
/// which keeps its slot while showing Saved. The bar never exceeds five tabs.
FOUNDATION_EXPORT NSString *const SPKTabIdentifierSaved;

FOUNDATION_EXPORT NSString *const SPKTabSavedCarrierNone;

FOUNDATION_EXPORT NSString *const SPKPrefTabLayout;
FOUNDATION_EXPORT NSString *const SPKPrefCustomTabOrder;
FOUNDATION_EXPORT NSString *const SPKPrefSavedTabCarrier;
FOUNDATION_EXPORT NSString *const SPKPrefLaunchTab;
FOUNDATION_EXPORT NSString *const SPKPrefSwipeTabs;
/// Hides the tab bar once Messages is the only tab left. The key keeps its
/// original name so existing installs keep their setting.
FOUNDATION_EXPORT NSString *const SPKPrefHideTabBarWhenSingle;

#ifdef __cplusplus
extern "C" {
#endif

/// The five navigable destinations, in Instagram's standard order.
NSArray<NSString *> *SPKCanonicalTabIdentifiers(void);
/// Everything with a visibility toggle: the canonical destinations plus Create.
NSArray<NSString *> *SPKTabEditableIdentifiers(void);
/// The identifiers an order array may contain: the canonical five plus Saved.
NSArray<NSString *> *SPKTabOrderableIdentifiers(void);
/// Hidden slots Saved may borrow in `layout`, most preferred first. Empty outside
/// Custom, since Default and Classic are Instagram's own arrangements.
NSArray<NSString *> *SPKTabSavedCarrierPreferenceForLayout(NSString *layout);
/// Whether the identifier owns a tab bar slot in `layout`: Create only in
/// Classic, Messages everywhere except Classic.
BOOL SPKTabOccupiesBarSlot(NSString *identifier, NSString *layout);
NSArray<NSString *> *SPKNormalizeTabOrder(id _Nullable value);
NSString *SPKNormalizedTabLayout(id _Nullable value);
NSString *SPKNormalizedSavedCarrier(id _Nullable value);

/// The slot Saved draws in right now, or `SPKTabSavedCarrierNone`. The stored
/// carrier only counts in Custom and while that tab is actually hidden.
NSString *SPKEffectiveSavedCarrier(void);

/// The only destination the bar would show, or nil for none or several. Saved
/// counts as a destination; a visible Create means the bar is not single-tab.
NSString *_Nullable SPKSingleVisibleTabIdentifier(NSString *layout,
                                                  NSSet<NSString *> *hidden,
                                                  NSString *savedCarrier);
/// The same answer for the configuration stored in preferences.
NSString *_Nullable SPKSingleVisibleTabIdentifierFromPreferences(void);
/// YES when the stored configuration leaves Messages as the only tab.
BOOL SPKTabConfigurationIsMessagesOnly(void);

NSString *SPKTabTitle(NSString *identifier);
NSString *SPKTabIconName(NSString *identifier);
NSString *SPKTabHidePreferenceKey(NSString *identifier);
NSString *SPKTabLaunchPreferenceValue(NSString *identifier);
NSString *_Nullable SPKTabIdentifierForLaunchPreference(NSString *value);

/// Turns the old Standard and Alternate orders into Custom ones and normalizes
/// the stored order. Safe to call repeatedly.
void SPKMigrateTabConfigurationIfNeeded(void);

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END
