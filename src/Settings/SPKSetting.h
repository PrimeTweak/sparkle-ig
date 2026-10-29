#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, SPKTableCell) {
    SPKTableCellStatic,
    SPKTableCellLink,
    SPKTableCellSwitch,
    SPKTableCellStepper,
    SPKTableCellButton,
    SPKTableCellMenu,
    SPKTableCellNavigation,
    SPKTableCellTextField,
    SPKTableCellValue,
    SPKTableCellStorageBar,
};

/// Posted on the main thread when a value behind a row's `accessoryTextProvider`
/// changed, so open settings pages reload the rows that show one.
FOUNDATION_EXPORT NSNotificationName const SPKSettingAccessoryTextDidChangeNotification;

///

@interface SPKSetting : NSObject

@property (nonatomic, readonly) SPKTableCell type;

/// Storage bar rows only: the segment weights and the trailing value.
@property (nonatomic, copy, nullable) NSArray<NSNumber *> *barFractions;
@property (nonatomic, copy, nullable) NSString *barValue;
@property (nonatomic, copy, nullable) NSString *barLegend;

@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong) NSString *subtitle;

/// Long-form explanation, shown only in the section's ⓘ sheet. Any section with
/// at least one row carrying `helpText` gets its ⓘ button automatically.
///
/// The sheet prints the row's title above this text, so a `helpText` that merely
/// restates the title reads twice. Leave it nil there — the row is then simply
/// absent from the sheet.
@property (nonatomic, copy, nullable) NSString *helpText;

@property (nonatomic, strong, nullable) UIImage *icon;
@property (nonatomic, strong, nullable) UIColor *iconTintColor;
@property (nonatomic, copy, nullable) UIImage * (^iconProvider)(void);
@property (nonatomic, copy, nullable) NSString * (^accessoryTextProvider)(void);
@property (nonatomic, copy, nullable) BOOL (^enabledProvider)(void);
/// When set and it returns YES, the row is omitted from the table entirely
/// (not merely greyed out). Evaluated whenever the table's visible sections are
/// rebuilt — call `-rebuildVisibleSections` after changing the state this reads.
@property (nonatomic, copy, nullable) BOOL (^hiddenProvider)(void);
@property (nonatomic, strong, nullable) UIColor *tintColor;
@property (nonatomic, strong) NSString *defaultsKey;

@property (nonatomic, strong) NSURL *url;
@property (nonatomic, strong) NSURL *imageUrl;

/// When set, the row's leading image is a self-healing circular avatar loaded
/// via SPKAvatarCache (keyed by PK). `avatarURLString` is the last-known URL;
/// user PKs (numeric) re-resolve a fresh URL when the stored one expires. Group
/// avatars pass a "grp_<threadId>" key + URL and can't be re-resolved.
@property (nonatomic, copy, nullable) NSString *avatarPK;
@property (nonatomic, copy, nullable) NSString *avatarURLString;
@property (nonatomic) BOOL avatarIsGroup;

@property (nonatomic) BOOL requiresRestart;

/// When this switch is turned on, the bool at this key is forced off (and the table reloads). Used for prefs that share one gesture.
@property (nonatomic, copy, nullable) NSString *mutuallyExclusiveDefaultsKey;

@property (nonatomic) double min;
@property (nonatomic) double max;
@property (nonatomic) double step;
@property (nonatomic, copy) NSString *label;
@property (nonatomic, copy) NSString *singularLabel;

@property (nonatomic, copy, nullable) NSString *placeholder;
@property (nonatomic) UIKeyboardType keyboardType;

@property (nonatomic, copy) void (^action)(void);
@property (nonatomic, copy, nullable) BOOL (^switchValueProvider)(void);
@property (nonatomic, copy, nullable) void (^switchChangeHandler)(BOOL isOn);
/// When YES, dependent rows reload after `switchChangeHandler` runs so their
/// enabled/greyed state can refresh. The toggled row itself is left untouched, so
/// the switch keeps its native (Liquid Glass) slide animation. Set YES only when
/// toggling this row changes another row's appearance and the handler doesn't
/// already reload the table itself.
@property (nonatomic) BOOL reloadsTableOnSwitchChange;

@property (nonatomic, strong) UIMenu *baseMenu;
@property (nonatomic, strong, nullable) NSDictionary *userInfo;

@property (nonatomic, strong) NSArray *navSections;
@property (nonatomic, strong) UIViewController *navViewController;

/// Optional gate on a navigation row: the push happens only if the block calls its
/// `allow` continuation. For destinations behind a lock, so the prompt appears on the
/// row tap rather than over a screen that is already open.
@property (nonatomic, copy, nullable) void (^navigationGate)(void (^allow)(void));
@property (nonatomic, copy, nullable) NSArray * (^searchSectionsProvider)(void);
@property (nonatomic, copy, nullable) NSString *searchKeywords;

+ (instancetype)staticCellWithTitle:(NSString *)title
                           subtitle:(NSString *)subtitle
                               icon:(nullable UIImage *)icon;

+ (instancetype)linkCellWithTitle:(NSString *)title
                         subtitle:(NSString *)subtitle
                             icon:(nullable UIImage *)icon
                              url:(NSString *)url;

+ (instancetype)linkCellWithTitle:(NSString *)title
                         subtitle:(NSString *)subtitle
                         imageUrl:(NSString *)imageUrl
                              url:(NSString *)url;

+ (instancetype)switchCellWithTitle:(NSString *)title
                        defaultsKey:(NSString *)defaultsKey;

+ (instancetype)switchCellWithTitle:(NSString *)title
                        defaultsKey:(NSString *)defaultsKey
                    requiresRestart:(BOOL)requiresRestart;

+ (instancetype)switchCellWithTitle:(NSString *)title
                               icon:(nullable UIImage *)icon
                        defaultsKey:(NSString *)defaultsKey;

+ (instancetype)switchCellWithTitle:(NSString *)title
                               icon:(nullable UIImage *)icon
                        defaultsKey:(NSString *)defaultsKey
                    requiresRestart:(BOOL)requiresRestart;

+ (instancetype)switchCellWithTitle:(NSString *)title
                           subtitle:(NSString *)subtitle
                        defaultsKey:(NSString *)defaultsKey;

+ (instancetype)switchCellWithTitle:(NSString *)title
                           subtitle:(NSString *)subtitle
                               icon:(nullable UIImage *)icon
                        defaultsKey:(NSString *)defaultsKey;

+ (instancetype)switchCellWithTitle:(NSString *)title
                           subtitle:(NSString *)subtitle
                        defaultsKey:(NSString *)defaultsKey
                    requiresRestart:(BOOL)requiresRestart;

+ (instancetype)switchCellWithTitle:(NSString *)title
                           subtitle:(NSString *)subtitle
                        defaultsKey:(NSString *)defaultsKey
                    requiresRestart:(BOOL)requiresRestart
       mutuallyExclusiveDefaultsKey:(nullable NSString *)exclusiveDefaultsKey;

+ (instancetype)stepperCellWithTitle:(NSString *)title
                            subtitle:(NSString *)subtitle
                         defaultsKey:(NSString *)defaultsKey
                                 min:(double)min
                                 max:(double)max
                                step:(double)step
                               label:(NSString *)label
                       singularLabel:(NSString *)singularLabel;

+ (instancetype)stepperCellWithTitle:(NSString *)title
                            subtitle:(NSString *)subtitle
                                icon:(nullable UIImage *)icon
                         defaultsKey:(NSString *)defaultsKey
                                 min:(double)min
                                 max:(double)max
                                step:(double)step
                               label:(NSString *)label
                       singularLabel:(NSString *)singularLabel;

+ (instancetype)buttonCellWithTitle:(NSString *)title
                           subtitle:(nullable NSString *)subtitle
                               icon:(nullable UIImage *)icon
                             action:(void (^)(void))action;

+ (instancetype)menuCellWithTitle:(NSString *)title
                         subtitle:(nullable NSString *)subtitle
                             menu:(UIMenu *)menu;

+ (instancetype)menuCellWithTitle:(NSString *)title
                             icon:(nullable UIImage *)icon
                             menu:(UIMenu *)menu;

+ (instancetype)menuCellWithTitle:(NSString *)title
                         subtitle:(nullable NSString *)subtitle
                             icon:(nullable UIImage *)icon
                             menu:(UIMenu *)menu;

+ (instancetype)navigationCellWithTitle:(NSString *)title
                               subtitle:(nullable NSString *)subtitle
                                   icon:(nullable UIImage *)icon
                            navSections:(NSArray *)navSections;

+ (instancetype)navigationCellWithTitle:(NSString *)title
                               subtitle:(nullable NSString *)subtitle
                                   icon:(nullable UIImage *)icon
                         viewController:(UIViewController *)viewController;

+ (instancetype)textFieldCellWithTitle:(NSString *)title
                           placeholder:(nullable NSString *)placeholder
                          keyboardType:(UIKeyboardType)keyboardType
                           defaultsKey:(NSString *)defaultsKey;

+ (instancetype)valueCellWithTitle:(NSString *)title
                          subtitle:(nullable NSString *)subtitle
                              icon:(nullable UIImage *)icon;

/// A read-only row that draws a proportional bar followed by a value, for a
/// figure that is observed rather than set. `fractions` are shaded from dark to
/// light in order and are normalised by the cell.
+ (instancetype)storageBarCellWithFractions:(NSArray<NSNumber *> *)fractions
                                      value:(NSString *)value
                                     legend:(nullable NSString *)legend;

#pragma mark - Instance methods

- (UIMenu *)menuForButton:(UIButton *)button;

@end

NS_ASSUME_NONNULL_END
