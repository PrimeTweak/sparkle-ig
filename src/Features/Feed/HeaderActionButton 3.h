#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

// Master enable (surface-prefixed: this installs in the Feed surface group).
// Default tap action id: "menu" or a destination identifier below.
FOUNDATION_EXPORT NSString *const kSPKHeaderButtonDefaultActionKey;  // feed_header_button_default
FOUNDATION_EXPORT NSString *const kSPKHeaderButtonDefaultActionMenu; // "menu"

// A single quick-access destination the header button can open.
@interface SPKHeaderDestination : NSObject
@property (nonatomic, copy, readonly) NSString *identifier;
@property (nonatomic, copy, readonly) NSString *title;    // full label (menus / toggles / picker)
@property (nonatomic, copy, readonly) NSString *iconName; // IG-bundle icon name
// Presents the destination. `window` is the header's window (may be nil).
@property (nonatomic, copy, readonly) void (^present)(UIWindow *_Nullable window);
@end

// Every possible destination, in display order.
FOUNDATION_EXPORT NSArray<SPKHeaderDestination *> *SPKHeaderButtonAllDestinations(void);
// Only the destinations whose per-destination pref is enabled.
FOUNDATION_EXPORT NSArray<SPKHeaderDestination *> *SPKHeaderButtonEnabledDestinations(void);

// Resolved default tap action: the saved id if it's a currently-enabled destination,
// else the "Open Menu" sentinel. Plus its display title / icon for the settings row.
FOUNDATION_EXPORT NSString *SPKHeaderButtonResolvedDefaultActionIdentifier(void);
FOUNDATION_EXPORT NSString *SPKHeaderButtonDefaultActionTitle(void);
FOUNDATION_EXPORT NSString *SPKHeaderButtonDefaultActionIconName(void);

// Registry installer (called from SPKStartupHooks Feed surface group).
FOUNDATION_EXPORT void SPKInstallHeaderActionButtonHooksIfEnabled(void);

NS_ASSUME_NONNULL_END
