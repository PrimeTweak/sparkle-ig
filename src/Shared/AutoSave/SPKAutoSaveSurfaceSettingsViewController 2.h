#import <UIKit/UIKit.h>

#import "../../Settings/SPKSettingsViewController.h"

@class SPKAutoSaveFilterConfig;

NS_ASSUME_NONNULL_BEGIN

/// Describes one surface's Auto-Save page. Every surface has the same three rows --
/// enable, Filter Mode, the active list -- differing only in wording and which list
/// screen the row opens.
@interface SPKAutoSaveSurfaceDescriptor : NSObject
/// The surface's filter (supplies the pref keys and the subject noun).
@property (nonatomic, strong) SPKAutoSaveFilterConfig *filter;
/// Page title, e.g. "Stories".
@property (nonatomic, copy) NSString *title;
/// Master switch title, e.g. "Auto-Save Stories".
@property (nonatomic, copy) NSString *masterTitle;
/// Icon for the list row ("users" / "messages").
@property (nonatomic, copy) NSString *listIcon;
/// Builds the list screen. A block, not an instance: the screen reads the current
/// Filter Mode at init, so it has to be built fresh each time the page is shown.
@property (nonatomic, copy) UIViewController * (^listProvider)(void);
/// Numbered footer lines matching the rows, per mode.
@property (nonatomic, copy) NSString * (^footerProvider)(BOOL allMode);
@end

/// Downloads > Auto-Save > <Surface>. Surface-specific settings only: enable, filter
/// mode, and the active list. Destination/quality/feedback are shared and live on the
/// parent page.
///
/// Subclasses override `+descriptor` only.
@interface SPKAutoSaveSurfaceSettingsViewController : SPKSettingsViewController
+ (SPKAutoSaveSurfaceDescriptor *)descriptor;
+ (NSArray *)contentSections;
+ (NSArray *)searchSections;
@end

NS_ASSUME_NONNULL_END
