#import <UIKit/UIKit.h>

#import "SPKSetting.h"

NS_ASSUME_NONNULL_BEGIN

// SPKToggleMenu — Sparkle's multi-toggle state menu (convention v1.2).
//
// A system-menu look-alike anchored to its row, holding one checkable item per
// preference. It exists because UIMenu hard-codes the opposite anatomy
// (checkmark leading, image trailing); Sparkle's convention mirrors the
// settings cells instead:
//
//   · icon on the LEFT (same Instagram glyphs as the cells, template-tinted)
//   · checkmark on the RIGHT
//   · item height 44 pt (= SPKUI_RowHeight), width 262 pt, corner radius 13
//   · the menu STAYS OPEN while toggling — tap outside or the Done
//     footer to dismiss (v1.4: 6pt content padding, 6pt sectioned gap +
//     44pt centered semibold "Done", 20pt screen margin)
//
// The host row ("gate row") is built with SPKToggleMenuRowSetting(): a button
// cell that closes its page, carries an "N on" / "Off" accessory (re-read on
// every reloadData, same mechanic as the root "N active" counters), and
// exposes its items to settings search as real switch rows — so they stay
// individually findable *and* togglable from search results.

@interface SPKToggleMenuItem : NSObject

+ (instancetype)itemWithTitle:(NSString *)title
                     iconName:(NSString *)iconName
                  defaultsKey:(NSString *)defaultsKey;

@property (nonatomic, copy, readonly) NSString *title;
@property (nonatomic, copy, readonly) NSString *iconName;
@property (nonatomic, copy, readonly) NSString *defaultsKey;

/// nil = always enabled. A disabled item renders dimmed and ignores taps,
/// mirroring `enabledProvider` on regular rows.
@property (nonatomic, copy, nullable) BOOL (^enabledProvider)(void);

/// nil = always visible. A hidden item is absent from the menu, from the "N on"
/// count and from search — the item-level twin of `hiddenProvider` on rows.
@property (nonatomic, copy, nullable) BOOL (^hiddenProvider)(void);

/// Toggling this item prompts for a restart, exactly like a switch row that
/// declares `requiresRestart`.
@property (nonatomic, assign) BOOL requiresRestart;

/// Single-choice mode: the item writes `pickValue` into its key instead of
/// toggling a bool, shows a checkmark when the key already holds that value,
/// and closes the menu on tap — one picker look for the whole tweak.
@property (nonatomic, copy, nullable) NSString *pickValue;

/// Called instead of the preference write when the host wants to apply the
/// choice itself (the settings screen routes it through menuChanged:).
@property (nonatomic, copy, nullable) void (^pickHandler)(void);

/// nil = the key's stored value decides. Set it on pages that stage their
/// choices before writing them.
@property (nonatomic, copy, nullable) BOOL (^selectedProvider)(void);

/// Runs right after the preference is written, mirroring `switchChangeHandler`
/// on a switch row — for families whose rows do more than store a bool.
@property (nonatomic, copy, nullable) void (^changeHandler)(BOOL isOn);

@end

@interface SPKToggleMenu : NSObject

+ (void)presentWithItems:(NSArray<SPKToggleMenuItem *> *)items
                fromView:(UIView *)anchorView
        inViewController:(UIViewController *)viewController
               onDismiss:(void (^_Nullable)(void))onDismiss;

/// Same menu, single-choice: no "Done" footer — picking closes it.
+ (void)presentWithChoices:(NSArray<SPKToggleMenuItem *> *)items
                  fromView:(UIView *)anchorView
          inViewController:(UIViewController *)viewController
                 onDismiss:(void (^_Nullable)(void))onDismiss;

@end

/// Builds the standard gate row: button cell + counter accessory + search
/// index. `title` doubles as the search-section header, so results read
/// "Page › <title> › Item".
SPKSetting *SPKToggleMenuRowSetting(NSString *title,
                                    NSString *iconName,
                                    NSArray<SPKToggleMenuItem *> *items);

NS_ASSUME_NONNULL_END
