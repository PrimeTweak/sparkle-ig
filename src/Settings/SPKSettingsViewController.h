#import "../Utils.h"
#import "SPKSetting.h"
#import "TweakSettings.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

NS_ASSUME_NONNULL_BEGIN

@interface SPKSettingsViewController : UIViewController <UITableViewDataSource, UITableViewDelegate, UISearchResultsUpdating>

- (instancetype)initWithTitle:(NSString *)title sections:(NSArray *)sections reduceMargin:(BOOL)reduceMargin;
- (instancetype)init;

/// Builds the leading and trailing bar buttons. Runs on load and on every
/// appearance, and resets both sets, so a subclass adding its own button must
/// override this and re-add after calling super rather than installing it once.
- (void)setupNavigationItems;

@property (nonatomic, strong, readonly) UITableView *tableView;
@property (nonatomic, strong, readonly) NSArray *sections;

@property (nonatomic, assign) BOOL searchesAllSettings;

/// Table style for this page. Defaults to UITableViewStyleInsetGrouped; override
/// to return UITableViewStylePlain for a flat, edge-to-edge list.
- (UITableViewStyle)preferredTableViewStyle;

- (void)switchChanged:(UISwitch *)sender;
/// Applies a menu selection to its `defaultsKey`. Exposed so pages whose rows depend
/// on a menu's value (titles, footers) can override, call super, and rebuild.
- (void)menuChanged:(UICommand *)command;
- (SPKSetting *)settingForSender:(id)sender;
- (void)replaceSections:(NSArray *)sections;

/// Re-evaluate every row's `hiddenProvider` and reload the table. Call after
/// changing state that a row's `hiddenProvider` depends on. No-op while searching.
- (void)rebuildVisibleSections;

@end

NS_ASSUME_NONNULL_END
