#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Builds a menu element for IG's native Direct menu (`IGDSPrismMenu`).
///
/// IG's menu takes a fixed array of elements at init, so there is no deferred
/// element here the way `UIMenu` has one: whatever a row displays must be known
/// before the menu is constructed.
///
/// `templateElement` is an existing element from the menu being built; its
/// private `_subtype` is copied so the injected row renders like IG's own.
/// Returns nil when IG's builder classes or ivars are not shaped as expected.
FOUNDATION_EXPORT id _Nullable SPKDirectPrismMenuElement(id templateElement,
                                                         NSString *title,
                                                         UIImage *_Nullable image,
                                                         void (^handler)(void));

/// As above, plus a secondary line when the running IG build's item builder
/// supports one. The subtitle is dropped rather than failing when it does not.
FOUNDATION_EXPORT id _Nullable SPKDirectPrismMenuElementWithSubtitle(id templateElement,
                                                                     NSString *title,
                                                                     NSString *_Nullable subtitle,
                                                                     UIImage *_Nullable image,
                                                                     void (^handler)(void));

/// One row inside a submenu built by `SPKDirectPrismSubmenuElement`.
@interface SPKDirectMenuAction : NSObject
+ (instancetype)actionWithTitle:(NSString *)title
                          image:(nullable UIImage *)image
                        handler:(void (^)(void))handler;
@property (nonatomic, copy, readonly) NSString *title;
@property (nonatomic, strong, readonly, nullable) UIImage *image;
@property (nonatomic, copy, readonly) void (^handler)(void);
@end

/// YES when a submenu row can be built, i.e. when `IGDSPrismMenuElement` is shaped
/// as expected and no previous attempt on this IG version failed.
///
/// The element is a tagged union whose submenu case is built only from Swift, so
/// its `_subtype` and the type it nests are worked out from the class itself: the
/// subtype from the order of the payload ivar groups, and the nested type from the
/// item builder's accessory API, which changed in the same generation that changed
/// the nesting (IG 410 nests `IGDSPrismMenuItem`, IG 441 nests whole elements).
/// Both readings are confirmed against those two builds. Since IG bridges the
/// array into a typed Swift array and dies on a wrong type, the first submenu of
/// each IG version is probed, and a version whose probe does not survive gets flat
/// rows from then on. Callers must always keep that flat fallback.
FOUNDATION_EXPORT BOOL SPKDirectPrismSubmenuAvailable(void);

/// Builds a row that expands into `actions` instead of firing a handler, matching
/// IG's own "More" row. Returns nil when the shape is not yet known.
FOUNDATION_EXPORT id _Nullable SPKDirectPrismSubmenuElement(id templateElement,
                                                            NSString *title,
                                                            UIImage *_Nullable image,
                                                            NSArray<SPKDirectMenuAction *> *actions);

/// Remembers the menu a submenu row may have to dismiss. IG dismisses the menu
/// itself when a top-level row is tapped, but a submenu row's handler is expected
/// to do it, so Sparkle needs a handle on the presenting menu.
FOUNDATION_EXPORT void SPKDirectPrismMenuNoteMenu(id _Nullable menu);

/// YES when `elements` carries a submenu row built by Sparkle. IG sizes its
/// overflow panel from the parent menu unless dynamic width is allowed, which
/// truncates rows longer than IG's own.
FOUNDATION_EXPORT BOOL SPKDirectMenuContainsSparkleSubmenu(NSArray *_Nullable elements);

/// YES for an element built by the functions above.
///
/// IG re-inits a menu with the array it was previously given, so an injector
/// that is not consumed on first use sees its own rows come back around. Check
/// this before adding a row a second time.
FOUNDATION_EXPORT BOOL SPKDirectMenuContainsSparkleRow(NSArray *_Nullable elements);

NS_ASSUME_NONNULL_END
