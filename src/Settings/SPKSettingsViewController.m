#import <objc/runtime.h>
#import "SPKSettingsViewController.h"
#import "SPKToggleMenu.h"
#import "../App/SPKStartupHooks.h"
#import "../AssetUtils.h"
#import "../Features/Messages/MessageSeenButtons.h"
#import "../Features/Profile/FollowIndicator.h"
#import "../Shared/ActionButton/ActionButtonCore.h"
#import "../Shared/Avatars/SPKAvatarCache.h"
#import "../Shared/UI/SPKMediaChrome.h"
#import "../Shared/UI/SPKSwitch.h"
#import "../App/SPKCore.h"
#import "SPKOnboardingViewController.h"
#import "SPKPreferenceAvailability.h"
#import "SPKPreferences.h"
#import "SPKWhatsNewViewController.h"
#import "SPKSettingsHelpSheetViewController.h"

#pragma mark - Layout metrics (measured; one line per setting)
// Measured from Instagram's native settings via screenshot comparison.
// TOUTE retouche de mise en page se fait ICI, nulle part ailleurs.
static CGFloat const SPKUI_RowHeight          = 44.0;  // standard row pitch
static CGFloat const SPKUI_RowVMargin         = 9.0;   // marge verticale du contenu
static CGFloat const SPKUI_RowLeading         = 15.0;  // icon leading (renders ~17 on screen: glyphs carry ~2 pt of internal inset)
static CGFloat const SPKUI_RowTrailing        = 16.0;
static CGFloat const SPKUI_IconMax            = 26.0;  // glyph size cap
static CGFloat const SPKUI_SubtitleIconRise   = 8.0;   // subtitle rows: glyph and accessory rise toward the title (matches the native Accounts Center)
static CGFloat const SPKUI_IconTextGap        = 14.0;
static CGFloat const SPKUI_BandHeight         = 6.0;   // band between groups
static CGFloat const SPKUI_BandLast           = 6.0;   // same band as between groups

// Associates a menu row with its button so the tap can rebuild its picker.
static const void *kSPKMenuButtonRowKey = &kSPKMenuButtonRowKey;

static CGFloat const SPKUI_HeaderTop          = 14.0;
static CGFloat const SPKUI_HeaderBottom       = 14.0;
static CGFloat const SPKUI_HeaderLeading      = 16.5;  // renders ~18 on screen
static CGFloat const SPKUI_HeaderFontSize     = 14.0;  // full glyph height measured: 38 px native vs 44 px at 16 pt
static CGFloat const SPKUI_FirstSectionTop    = 16.0;  // espace top bar → premier item
static CGFloat const SPKUI_ValueFontSize      = 14.0;  // "11 active", menu values — native measures 31 px vs 34 at 15 pt: one step smaller than the title

// Storage bar row: a view that lays itself out, so it is correct the first time
// it appears — configuring frames from the cell's bounds only worked after a
// scroll, when the cell had finally been sized.
@interface SPKStorageBarView : UIView
@property (nonatomic, copy) NSArray<NSNumber *> *fractions;
@property (nonatomic, copy) NSAttributedString *value;
@property (nonatomic, copy) NSString *legend;
@end

@implementation SPKStorageBarView {
    UILabel *_valueLabel;
    UILabel *_legendLabel;
    UIView *_track;
    NSMutableArray<UIView *> *_segments;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _segments = [NSMutableArray array];
        _valueLabel = [UILabel new];
        _valueLabel.textAlignment = NSTextAlignmentRight;
        [self addSubview:_valueLabel];
        _track = [UIView new];
        _track.backgroundColor = [SPKUtils SPKColor_InstagramSeparator];
        _track.layer.cornerRadius = 2.5;
        _track.clipsToBounds = YES;
        [self addSubview:_track];
        _legendLabel = [UILabel new];
        _legendLabel.font = [UIFont systemFontOfSize:12.0 weight:UIFontWeightRegular];
        _legendLabel.textColor = [SPKUtils SPKColor_InstagramTertiaryText];
        [self addSubview:_legendLabel];
        self.userInteractionEnabled = NO;
    }
    return self;
}

- (void)setValue:(NSAttributedString *)value {
    _value = [value copy];
    _valueLabel.attributedText = value;
    [self setNeedsLayout];
}

- (void)setLegend:(NSString *)legend {
    _legend = [legend copy];
    _legendLabel.text = legend;
    [self setNeedsLayout];
}

- (void)setFractions:(NSArray<NSNumber *> *)fractions {
    _fractions = [fractions copy];
    for (UIView *segment in _segments)
        [segment removeFromSuperview];
    [_segments removeAllObjects];
    // Three greys, not black: the bar reports, it does not shout.
    NSArray<UIColor *> *shades = @[ [[SPKUtils SPKColor_InstagramSecondaryText] colorWithAlphaComponent:0.85],
                                    [[SPKUtils SPKColor_InstagramSecondaryText] colorWithAlphaComponent:0.45],
                                    [[SPKUtils SPKColor_InstagramSecondaryText] colorWithAlphaComponent:0.22] ];
    for (NSUInteger idx = 0; idx < fractions.count; idx++) {
        UIView *segment = [UIView new];
        segment.backgroundColor = shades[MIN(idx, shades.count - 1)];
        [_track addSubview:segment];
        [_segments addObject:segment];
    }
    [self setNeedsLayout];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat width = CGRectGetWidth(self.bounds);
    CGFloat barRow = _legendLabel.text.length > 0 ? CGRectGetHeight(self.bounds) - 16.0
                                                  : CGRectGetHeight(self.bounds);
    CGFloat valueWidth = MIN(width * 0.6, [_valueLabel.attributedText size].width + 2.0);
    _valueLabel.frame = CGRectMake(width - valueWidth, 0, valueWidth, barRow);
    _track.frame = CGRectMake(0, (barRow - 5.0) / 2.0, MAX(0.0, width - valueWidth - 14.0), 5.0);
    _legendLabel.frame = CGRectMake(0, barRow - 2.0, width, 16.0);

    CGFloat total = 0.0;
    for (NSNumber *fraction in self.fractions)
        total += MAX(0.0, fraction.doubleValue);
    CGFloat x = 0.0;
    for (NSUInteger idx = 0; idx < _segments.count; idx++) {
        CGFloat share = total > 0.0 ? MAX(0.0, self.fractions[idx].doubleValue) / total
                                    : (idx == 0 ? 1.0 : 0.0);
        CGFloat segmentWidth = CGRectGetWidth(_track.bounds) * share;
        _segments[idx].frame = CGRectMake(x, 0, segmentWidth, 5.0);
        x += segmentWidth;
    }
}

@end

// Storage bar row: the strip is rebuilt on each configuration, found by tag.
static NSInteger const kSPKStorageBarTag = 8801;

// "78 KB · 1 file" — the size carries the weight, the rest stays quiet.
static NSAttributedString *SPKStorageValueText(NSString *value) {
    NSArray<NSString *> *parts = [value componentsSeparatedByString:@" · "];
    NSMutableAttributedString *text = [NSMutableAttributedString new];
    [text appendAttributedString:[[NSAttributedString alloc]
        initWithString:parts.firstObject ?: value
            attributes:@{ NSFontAttributeName : [UIFont systemFontOfSize:SPKUI_ValueFontSize weight:UIFontWeightSemibold],
                          NSForegroundColorAttributeName : [SPKUtils SPKColor_InstagramPrimaryText] }]];
    if (parts.count > 1) {
        NSString *rest = [NSString stringWithFormat:@" · %@", [[parts subarrayWithRange:NSMakeRange(1, parts.count - 1)] componentsJoinedByString:@" · "]];
        [text appendAttributedString:[[NSAttributedString alloc]
            initWithString:rest
                attributes:@{ NSFontAttributeName : [UIFont systemFontOfSize:SPKUI_ValueFontSize weight:UIFontWeightRegular],
                              NSForegroundColorAttributeName : [SPKUtils SPKColor_InstagramSecondaryText] }]];
    }
    return text;
}


static char rowStaticRef[] = "row";
static CGFloat const kSPKSettingsRemoteImageSize = 45.0;

static NSCache<NSString *, UIImage *> *SPKSettingsRemoteImageCache(void) {
    static NSCache<NSString *, UIImage *> *cache;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cache = [NSCache new];
        cache.countLimit = 64;
    });
    return cache;
}

static double SPKNormalizedStepperValue(SPKSetting *row, double value) {
    if (!row)
        return value;

    if (row.max >= row.min) {
        value = MIN(row.max, MAX(row.min, value));
    }

    if (row.step > 0.0) {
        double origin = row.min;
        double stepCount = round((value - origin) / row.step);
        value = origin + (stepCount * row.step);
        if (row.max >= row.min) {
            value = MIN(row.max, MAX(row.min, value));
        }
    }

    double nearestInteger = round(value);
    if (fabs(value - nearestInteger) < 0.0000001) {
        value = nearestInteger;
    }

    return value;
}

@interface SPKSettingsViewController () <UITableViewDataSource, UITableViewDelegate, UITableViewDragDelegate, UITableViewDropDelegate, UISearchResultsUpdating, UITextFieldDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray *sections;
@property (nonatomic, strong) NSArray *originalSections;
@property (nonatomic, strong) UISearchController *searchController;
@property (nonatomic, strong) UIBarButtonItem *applyRestartItem;
@property (nonatomic) BOOL reduceMargin;
@property (nonatomic) BOOL defersRestartPrompt;
@property (nonatomic) BOOL hasPendingRestartChanges;
@property (nonatomic) BOOL didAttemptOnboarding;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, UIView *> *footerViewCache;

@end

///

// Multi-line rows: the native pattern lifts the glyph toward the title instead
// of centering it on the whole block. The glyph is drawn at its final size in a
// taller transparent box — the box stays centered, so the glyph rises by `rise`.
static UIImage *SPKSettingsIconRaisedForSubtitle(UIImage *icon, CGFloat side, CGFloat rise) {
    if (!icon || rise <= 0.0 || side <= 0.0 || icon.size.width <= 0.0 || icon.size.height <= 0.0)
        return icon;

    CGFloat fit = MIN(side / icon.size.width, side / icon.size.height);
    CGSize glyph = CGSizeMake(floor(icon.size.width * fit), floor(icon.size.height * fit));
    CGSize boxed = CGSizeMake(glyph.width, glyph.height + 2.0 * rise);

    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:boxed];
    UIImage *raised = [renderer imageWithActions:^(UIGraphicsImageRendererContext *_Nonnull context) {
        [icon drawInRect:CGRectMake(0.0, 0.0, glyph.width, glyph.height)];
    }];
    return [raised imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

static UIImage *SPKSettingsReorderCompositeImage(UIImage *iconImage, UIColor *tintColor) {
    UIImageSymbolConfiguration *grabberConfig = [UIImageSymbolConfiguration configurationWithPointSize:12.0 weight:UIImageSymbolWeightSemibold];
    UIImage *grabber = [[UIImage systemImageNamed:@"line.3.horizontal" withConfiguration:grabberConfig] imageWithTintColor:[SPKUtils SPKColor_InstagramTertiaryText] renderingMode:UIImageRenderingModeAlwaysOriginal];
    if (!grabber || !iconImage)
        return iconImage ?: grabber;

    CGFloat spacing = 8.0;
    CGSize size = CGSizeMake(grabber.size.width + spacing + iconImage.size.width,
                             MAX(grabber.size.height, iconImage.size.height));
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:size];
    return [renderer imageWithActions:^(UIGraphicsImageRendererContext *_Nonnull context) {
        CGFloat grabberY = floor((size.height - grabber.size.height) / 2.0);
        [grabber drawAtPoint:CGPointMake(0.0, grabberY)];

        UIImage *renderedIcon = [iconImage imageWithTintColor:tintColor ?: [SPKUtils SPKColor_InstagramPrimaryText] renderingMode:UIImageRenderingModeAlwaysOriginal];
        CGFloat iconY = floor((size.height - renderedIcon.size.height) / 2.0);
        [renderedIcon drawAtPoint:CGPointMake(grabber.size.width + spacing, iconY)];
    }];
}

static NSMutableArray *SPKMutableSectionsCopy(NSArray *sections) {
    NSMutableArray *mutableSections = [NSMutableArray array];
    for (NSDictionary *section in sections) {
        NSMutableDictionary *mutableSection = [section mutableCopy];
        NSArray *rows = section[@"rows"];
        mutableSection[@"rows"] = rows ? [rows mutableCopy] : [NSMutableArray array];
        [mutableSections addObject:mutableSection];
    }
    return mutableSections;
}

// Mutable copy with rows whose `hiddenProvider` returns YES dropped. Used to
// derive the displayed `sections` from the full `originalSections`, so a row can
// disappear/reappear live in response to another control (e.g. a passcode row
// that only exists while a lock switch is on) without restructuring the tree.
static NSMutableArray *SPKVisibleSectionsCopy(NSArray *sections) {
    NSMutableArray *mutableSections = SPKMutableSectionsCopy(sections);
    for (NSMutableDictionary *section in mutableSections) {
        NSMutableArray *rows = section[@"rows"];
        if (![rows isKindOfClass:[NSArray class]])
            continue;
        NSMutableArray *visibleRows = [NSMutableArray arrayWithCapacity:rows.count];
        for (id row in rows) {
            if ([row isKindOfClass:[SPKSetting class]] && ((SPKSetting *)row).hiddenProvider && ((SPKSetting *)row).hiddenProvider())
                continue;
            [visibleRows addObject:row];
        }
        section[@"rows"] = visibleRows;
    }
    return mutableSections;
}

// A section hides rows when its displayed row count is short of the count in
// `originalSections`, which keeps every row regardless of `hiddenProvider`.
// The header's info glyph fills in to signal that options are waiting there.
static BOOL SPKSectionHidesRows(NSDictionary *displayedSection, NSArray *originalSections) {
    NSArray *displayedRows = displayedSection[@"rows"];
    if (![displayedRows isKindOfClass:[NSArray class]])
        return NO;
    for (NSDictionary *original in originalSections) {
        if (![original isKindOfClass:[NSDictionary class]])
            continue;
        NSArray *originalRows = original[@"rows"];
        if (![originalRows isKindOfClass:[NSArray class]])
            continue;
        BOOL sameHeader = (displayedSection[@"header"] == original[@"header"]) ||
                          [displayedSection[@"header"] isEqual:original[@"header"]];
        if (!sameHeader)
            continue;
        for (id row in originalRows) {
            if ([row isKindOfClass:[SPKSetting class]] && ((SPKSetting *)row).hiddenProvider &&
                ((SPKSetting *)row).hiddenProvider())
                return YES;
        }
        return NO;
    }
    return NO;
}

static UIImage *SPKSettingsSizedRemoteImage(UIImage *image, BOOL circular) {
    if (!image)
        return nil;

    CGSize targetSize = CGSizeMake(kSPKSettingsRemoteImageSize, kSPKSettingsRemoteImageSize);
    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat];
    format.scale = UIScreen.mainScreen.scale;

    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:targetSize format:format];
    return [renderer imageWithActions:^(UIGraphicsImageRendererContext *_Nonnull context) {
        CGRect bounds = (CGRect){.origin = CGPointZero, .size = targetSize};
        if (circular) {
            [[UIBezierPath bezierPathWithOvalInRect:bounds] addClip];
        }

        CGFloat scale = MAX(targetSize.width / image.size.width, targetSize.height / image.size.height);
        CGSize drawSize = CGSizeMake(image.size.width * scale, image.size.height * scale);
        CGRect drawRect = CGRectMake((targetSize.width - drawSize.width) / 2.0,
                                     (targetSize.height - drawSize.height) / 2.0,
                                     drawSize.width,
                                     drawSize.height);
        [image drawInRect:drawRect];
    }];
}

static NSString *SPKSettingsNormalizedQuery(NSString *query) {
    return [[query ?: @"" stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] localizedLowercaseString];
}

static NSString *SPKSettingsAccessoryText(SPKSetting *row) {
    NSString *providedText = row.accessoryTextProvider ? row.accessoryTextProvider() : nil;
    if ([providedText isKindOfClass:[NSString class]])
        return providedText;

    NSString *staticText = [row.userInfo[@"accessoryText"] isKindOfClass:[NSString class]] ? row.userInfo[@"accessoryText"] : nil;
    return staticText;
}

static NSArray<NSString *> *SPKSettingsSearchTokens(NSString *query) {
    NSString *normalized = SPKSettingsNormalizedQuery(query);
    if (normalized.length == 0)
        return @[];

    NSMutableArray<NSString *> *tokens = [NSMutableArray array];
    NSCharacterSet *separators = [[NSCharacterSet alphanumericCharacterSet] invertedSet];
    for (NSString *token in [normalized componentsSeparatedByCharactersInSet:separators]) {
        if (token.length > 0) {
            [tokens addObject:token];
        }
    }
    return tokens;
}

static void SPKSettingsAppendSearchString(NSMutableArray<NSString *> *strings, id value) {
    if ([value isKindOfClass:[NSString class]] && [value length] > 0) {
        [strings addObject:value];
    } else if ([value respondsToSelector:@selector(stringValue)]) {
        NSString *stringValue = [value stringValue];
        if (stringValue.length > 0)
            [strings addObject:stringValue];
    }
}

static void SPKSettingsCollectMenuSearchStrings(UIMenu *menu, NSMutableArray<NSString *> *strings) {
    if (![menu isKindOfClass:[UIMenu class]])
        return;
    SPKSettingsAppendSearchString(strings, menu.title);

    for (UIMenuElement *element in menu.children ?: @[]) {
        if ([element isKindOfClass:[UIMenu class]]) {
            SPKSettingsCollectMenuSearchStrings((UIMenu *)element, strings);
            continue;
        }

        SPKSettingsAppendSearchString(strings, element.title);
        if ([element isKindOfClass:[UICommand class]]) {
            NSDictionary *propertyList = ((UICommand *)element).propertyList;
            SPKSettingsAppendSearchString(strings, propertyList[@"defaultsKey"]);
            SPKSettingsAppendSearchString(strings, propertyList[@"value"]);
            SPKSettingsAppendSearchString(strings, propertyList[@"iconName"]);
        }
    }
}

static NSString *SPKSettingsRowSearchHaystack(SPKSetting *row, NSString *path, NSString *sectionTitle, NSString *sectionFooter) {
    NSMutableArray<NSString *> *strings = [NSMutableArray array];
    SPKSettingsAppendSearchString(strings, row.title);
    SPKSettingsAppendSearchString(strings, row.subtitle);
    SPKSettingsAppendSearchString(strings, row.defaultsKey);
    SPKSettingsAppendSearchString(strings, row.placeholder);
    SPKSettingsAppendSearchString(strings, row.label);
    SPKSettingsAppendSearchString(strings, row.singularLabel);
    SPKSettingsAppendSearchString(strings, row.searchKeywords);
    SPKSettingsAppendSearchString(strings, path);
    SPKSettingsAppendSearchString(strings, sectionTitle);
    SPKSettingsAppendSearchString(strings, sectionFooter);

    NSString *accessoryText = [row.userInfo[@"accessoryText"] isKindOfClass:[NSString class]] ? row.userInfo[@"accessoryText"] : nil;
    SPKSettingsAppendSearchString(strings, accessoryText);
    SPKSettingsCollectMenuSearchStrings(row.baseMenu, strings);
    return SPKSettingsNormalizedQuery([strings componentsJoinedByString:@" "]);
}

static BOOL SPKSettingsRowMatchesTokens(SPKSetting *row, NSArray<NSString *> *tokens, NSString *path, NSString *sectionTitle, NSString *sectionFooter) {
    if (![row isKindOfClass:[SPKSetting class]])
        return NO;
    if (tokens.count == 0)
        return YES;

    NSString *haystack = SPKSettingsRowSearchHaystack(row, path, sectionTitle, sectionFooter);
    for (NSString *token in tokens) {
        if ([haystack rangeOfString:token].location == NSNotFound) {
            return NO;
        }
    }
    return YES;
}

static NSArray<NSString *> *SPKSettingsPathComponentsByAppending(NSArray<NSString *> *components, NSString *component) {
    if (component.length == 0)
        return components ?: @[];
    NSMutableArray<NSString *> *result = [NSMutableArray arrayWithArray:components ?: @[]];
    [result addObject:component];
    return [result copy];
}

static NSString *SPKSettingsBreadcrumbText(NSArray<NSString *> *components) {
    return [components componentsJoinedByString:@" \u203a "];
}

static UIImage *SPKSettingsBreadcrumbChevronImage(void) {
    UIImage *image = [SPKAssetUtils instagramIconNamed:@"chevron_right"
                                             pointSize:12.0
                                         renderingMode:UIImageRenderingModeAlwaysTemplate];
    if (!image) {
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:10.0 weight:UIImageSymbolWeightSemibold];
        image = [[UIImage systemImageNamed:@"chevron.right" withConfiguration:config] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    }
    return image;
}

// The close mark, built from Apple's symbol rather than Instagram's asset.
//
// Measured side by side: the Instagram icon renders 13.3 pt wide with a 1.67 pt
// stroke, the symbol 16.3 pt with a 3.0 pt stroke. The heavier one is the one
// that reads as a control rather than a hairline.
static UIBarButtonItem *SPKSettingsCloseBarButtonItem(id target, SEL action) {
    UIImage *mark =
        [UIImage systemImageNamed:@"xmark"
                withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:16.0
                                                                                  weight:UIImageSymbolWeightSemibold]];
    UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithImage:mark
                                                             style:UIBarButtonItemStylePlain
                                                            target:target
                                                            action:action];
    item.tintColor = [SPKUtils SPKColor_InstagramPrimaryText];
    item.accessibilityLabel = @"Close";
    return item;
}

@implementation SPKSettingsViewController

- (UIView *)selectionBackgroundView {
    UIView *view = [[UIView alloc] initWithFrame:CGRectZero];
    view.backgroundColor = [SPKUtils SPKColor_InstagramPressedBackground];
    return view;
}

- (instancetype)initWithTitle:(NSString *)title sections:(NSArray *)sections reduceMargin:(BOOL)reduceMargin {
    self = [super init];

    if (self) {
        self.title = title;
        self.reduceMargin = reduceMargin;

        // Exclude development cells from release builds
        NSMutableArray *mutableSections = SPKMutableSectionsCopy(sections);

        [mutableSections enumerateObjectsWithOptions:NSEnumerationReverse
                                          usingBlock:^(NSDictionary *section, NSUInteger index, BOOL *stop) {
                                              if ([section[@"header"] hasPrefix:@"_"] && [section[@"footer"] hasPrefix:@"_"]) {
                                                  if (![[SPKUtils IGVersionString] isEqualToString:@"0.0.0"]) {
                                                      [mutableSections removeObjectAtIndex:index];
                                                  }
                                              }

                                              else if ([section[@"header"] isEqualToString:@"Experimental"]) {
                                                  if (![[SPKUtils IGVersionString] hasSuffix:@"-dev"]) {
                                                      [mutableSections removeObjectAtIndex:index];
                                                  }
                                              }
                                          }];

        self.originalSections = [mutableSections copy];
        self.sections = SPKVisibleSectionsCopy(mutableSections);
    }

    return self;
}

- (instancetype)init {
    self = [self initWithTitle:[SPKTweakSettings title] sections:[SPKTweakSettings sections] reduceMargin:YES];
    if (self) {
        self.searchesAllSettings = YES;
    }
    return self;
}

- (UITableViewStyle)preferredTableViewStyle {
    // Convention v1 (GO gate 0): native Instagram styling — full-width rows,
    // no cards. The rest of the controller already keys off this style.
    // Grouped (not inset): the same full-width rows as plain, but section
    // headers SCROLL with the content instead of pinning to the top —
    // the floating white bar artifact. Matches Instagram's behavior.
    return UITableViewStyleGrouped;
}

- (void)setSections:(NSMutableArray *)sections {
    _sections = sections;
    // Footer views are indexed by section number: as soon as the list
    // changes (search, hiddenProvider, replaceSections:), the indexes no
    // longer point at the same sections.
    [_footerViewCache removeAllObjects];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.navigationController.navigationBar.prefersLargeTitles = NO;

    UITableViewStyle style = [self preferredTableViewStyle];
    UIColor *backgroundColor = (style != UITableViewStyleInsetGrouped)
                                   ? [SPKUtils SPKColor_InstagramBackground]
                                   : [SPKUtils SPKColor_InstagramGroupedBackground];
    self.view.backgroundColor = backgroundColor;

    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:style];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.dragInteractionEnabled = [self pageAllowsReordering];
    self.tableView.dragDelegate = self;
    self.tableView.dropDelegate = self;
    self.tableView.backgroundColor = backgroundColor;
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    self.tableView.separatorColor = [SPKUtils SPKColor_InstagramSeparator];
    self.tableView.tintColor = [SPKUtils SPKColor_InstagramBlue];

    // Number pads (used by some text-field rows) have no return key; tap
    // elsewhere to dismiss the keyboard.
    UITapGestureRecognizer *dismissTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(spk_dismissKeyboard)];
    dismissTap.cancelsTouchesInView = NO;
    [self.tableView addGestureRecognizer:dismissTap];
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 72.0;
    // Disable header/footer height estimation. The grouped footers are multi-line
    // self-sizing labels; with a non-zero estimate UIKit lays them out short, then
    // corrects to the real (taller) height as they scroll into view, which shifts
    // the content offset and reads as the table "jumping" (most visible on pages
    // with long footers like Storage). Computing the real heights up front removes it.
    self.tableView.estimatedSectionHeaderHeight = 0.0;
    self.tableView.estimatedSectionFooterHeight = 0.0;

    self.footerViewCache = [NSMutableDictionary dictionary];
    // Native IG: no hairline between rows (the group bands are enough).
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;

    [self.view addSubview:self.tableView];
    [self setupNavigationItems];
    [self setupSearchController];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(spk_accessoryTextDidChange:)
                                                 name:SPKSettingAccessoryTextDidChangeNotification
                                               object:nil];
}

// No window check: the first change often lands while the page is still being
// pushed, and skipping it left the row blank until the next reload.
- (void)spk_accessoryTextDidChange:(NSNotification *)notification {
    if (!self.isViewLoaded)
        return;

    NSMutableArray<NSIndexPath *> *paths = [NSMutableArray array];
    for (NSIndexPath *indexPath in self.tableView.indexPathsForVisibleRows) {
        if (indexPath.section >= (NSInteger)self.sections.count)
            continue;
        NSArray *rows = self.sections[indexPath.section][@"rows"];
        SPKSetting *row = indexPath.row < (NSInteger)rows.count ? rows[indexPath.row] : nil;
        if ([row isKindOfClass:[SPKSetting class]] && row.accessoryTextProvider)
            [paths addObject:indexPath];
    }
    if (paths.count > 0)
        [self.tableView reloadRowsAtIndexPaths:paths withRowAnimation:UITableViewRowAnimationNone];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self setupNavigationItems];
    [self.tableView reloadData];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self presentIntroSheetsIfNeeded];
}

// Intro sheets shown when the user opens Sparkle settings. Only the root settings
// page presents them (sub-topic pages are also SPKSettingsViewControllers pushed
// onto the same stack), and at most one flow per process:
//   - First-ever run (`app_first_run` never stamped) → onboarding only. On finish
//     it stamps both keys so a fresh install doesn't also get What's New.
//   - Otherwise, already onboarded but a new version's notes are unseen (including
//     upgraders who predate the feature) → What's New only.
// Gating predicates live in SPKCore so the launch-time auto-open agrees. The Tools
// "Show Onboarding" / "Show What's New" buttons replay each directly without
// touching this state (onFinish is nil).
- (void)presentIntroSheetsIfNeeded {
    if (self.didAttemptOnboarding)
        return;
    if (self.navigationController.viewControllers.firstObject != self)
        return;
    if (self.presentedViewController)
        return;

    self.didAttemptOnboarding = YES;

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    if (SPKCoreOnboardingPending()) {
        [SPKOnboardingViewController presentFromViewController:self onFinish:^{
            [defaults setValue:SPKVersionString forKey:@"app_first_run"];
            [defaults setValue:SPKVersionString forKey:@"app_last_whatsnew_version"];
        }];
        return;
    }

    if (SPKCoreWhatsNewPending()) {
        [SPKWhatsNewViewController presentFromViewController:self onFinish:^{
            [defaults setValue:SPKVersionString forKey:@"app_last_whatsnew_version"];
        }];
    }
}

- (void)setupNavigationItems {
    BOOL isModalRoot = self.navigationController.presentingViewController &&
                       self.navigationController.viewControllers.firstObject == self;
    NSArray<UIBarButtonItem *> *leadingItems = isModalRoot
                                                   ? @[ SPKSettingsCloseBarButtonItem(self, @selector(closeTapped)) ]
                                                   : @[];
    SPKMediaChromeSetLeadingTopBarItems(self.navigationItem, leadingItems);

    NSArray<UIBarButtonItem *> *trailingItems = @[];
    if (self.defersRestartPrompt) {
        UIBarButtonItem *applyItem = SPKMediaChromeTopBarButtonItemWithStyle(@"check",
                                                                             self,
                                                                             @selector(applyRestartChanges),
                                                                             UIBarButtonItemStyleDone,
                                                                             [SPKUtils SPKColor_InstagramPrimaryText],
                                                                             @"Apply Liquid Glass changes");
        applyItem.enabled = self.hasPendingRestartChanges;
        self.applyRestartItem = applyItem;
        trailingItems = @[ applyItem ];
    } else {
        self.applyRestartItem = nil;
    }
    SPKMediaChromeSetTrailingTopBarItems(self.navigationItem, trailingItems);
}

- (void)setupSearchController {
    self.searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    self.searchController.searchResultsUpdater = self;
    self.searchController.obscuresBackgroundDuringPresentation = NO;
    self.searchController.hidesNavigationBarDuringPresentation = NO;
    [self.searchController.searchBar setImage:[SPKAssetUtils instagramIconNamed:@"search" pointSize:18.0]
                             forSearchBarIcon:UISearchBarIconSearch
                                        state:UIControlStateNormal];
    self.searchController.searchBar.placeholder = self.searchesAllSettings ? @"Search All Settings" : [NSString stringWithFormat:@"Search %@", self.title ?: @"settings"];
    if (@available(iOS 16.0, *)) {
        // Without this, recent iOS docks the search as a floating pill at the
        // bottom of the screen — and the full-width table scrolls behind it
        // (the ghost "Gallery" artifact). Stacked = under the title, matching
        // Instagram's native settings.
        self.navigationItem.preferredSearchBarPlacement = UINavigationItemSearchBarPlacementStacked;
    }
    // Flat grey field, like Instagram's own search. Without this, iOS 26 renders
    // the bar as a floating glass pill that does not match the rest of the screen.
    self.searchController.searchBar.searchBarStyle = UISearchBarStyleMinimal;
    self.searchController.searchBar.backgroundImage = [UIImage new];
    UITextField *searchField = self.searchController.searchBar.searchTextField;
    searchField.backgroundColor = [SPKUtils SPKColor_InstagramSecondaryBackground];
    searchField.layer.cornerRadius = 10.0;
    searchField.layer.cornerCurve = kCACornerCurveContinuous;
    searchField.layer.borderWidth = 0.0;
    searchField.clipsToBounds = YES;

    self.navigationItem.searchController = self.searchController;
    // Hidden until the list is pulled down, matching Instagram's "Settings
    // and activity" screen.
    self.navigationItem.hidesSearchBarWhenScrolling = YES;
    self.definesPresentationContext = YES;
}

- (void)closeTapped {
    [self.navigationController dismissViewControllerAnimated:YES completion:nil];
}

// MARK: - UITableViewDataSource

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    // Screenshot measurements: the native pitch is 44 pt, and rows WITHOUT a
    // value already sit there — rows with "N active" inflate to 52 because
    // sizing reserves the stacked height of the side-by-side secondary text.
    // 44 is locked for standard rows, automatic
    // only when the content calls for it.
    SPKSetting *row = self.sections[indexPath.section][@"rows"][indexPath.row];
    if (![row isKindOfClass:[SPKSetting class]])
        return UITableViewAutomaticDimension;

    // A value row puts its figure on the trailing side, not under the title:
    // it keeps the standard pitch even though it carries a subtitle.
    if (row.type == SPKTableCellValue)
        return SPKUI_RowHeight;

    // The storage bar carries its legend inside the row, so it needs the extra
    // line — without it, everything else keeps the measured 44 pt pitch.
    if (row.type == SPKTableCellStorageBar)
        return row.barLegend.length > 0 ? SPKUI_RowHeight + 14.0 : SPKUI_RowHeight;
    BOOL needsAutomatic = row.subtitle.length > 0 ||
                          row.avatarPK.length > 0 ||
                          row.imageUrl != nil ||
                          [row.userInfo[@"avatarIcon"] boolValue];
    return needsAutomatic ? UITableViewAutomaticDimension : SPKUI_RowHeight;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    SPKSetting *row = self.sections[indexPath.section][@"rows"][indexPath.row];
    if (!row)
        return nil;

    // Phase 0.2 — cell recycling. One identifier PER TYPE: a cell
    // Switch never comes back as Navigation — each branch of the pool keeps its type,
    // hence the accessory family it expects. The rest of the method already
    // reconfigures every property on each pass (contentConfiguration
    // restarts from a default config, accessories reassigned) — recycling
    // changes the cost of scrolling, not the state of the rows.
    NSString *reuseIdentifier = [NSString stringWithFormat:@"SPKSettingsCell.%ld", (long)row.type];
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuseIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier];
    }
    // A recycled cell of the same type can carry an accessory from its previous life:
    // a chevron, a switch or a value label left over from a previous row.
    cell.accessoryView = nil;
    cell.editingAccessoryView = nil;
    cell.accessoryType = UITableViewCellAccessoryNone;
    UIListContentConfiguration *cellContentConfig = cell.defaultContentConfiguration;
    // Plain (flat) pages use the page background so rows sit edge-to-edge with no
    // grouped-card tint; inset-grouped pages keep the elevated secondary color.
    cell.backgroundColor = ([self preferredTableViewStyle] != UITableViewStyleInsetGrouped)
                               ? [SPKUtils SPKColor_InstagramBackground]
                               : [SPKUtils SPKColor_InstagramSecondaryBackground];
    cell.tintColor = [SPKUtils SPKColor_InstagramBlue];
    cell.selectedBackgroundView = [self selectionBackgroundView];
    cellContentConfig.textProperties.color = [SPKUtils SPKColor_InstagramPrimaryText];
    cellContentConfig.secondaryTextProperties.color = [SPKUtils SPKColor_InstagramSecondaryText];
    cellContentConfig.textProperties.numberOfLines = 0;
    cellContentConfig.secondaryTextProperties.numberOfLines = 0;
    cellContentConfig.secondaryTextProperties.lineBreakMode = NSLineBreakByWordWrapping;
    // Native calibration, 2nd pass (side-by-side screenshot measurements):
    // IG = large DENSE text — 17 pt title with a ~43-44 pt row pitch
    // (center to center), not 60. Margins 9/9: icon 26 + 18 = 44.
    cellContentConfig.textProperties.font =
        [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody] scaledFontForFont:[UIFont systemFontOfSize:17.0]];
    NSDirectionalEdgeInsets rowMargins = cellContentConfig.directionalLayoutMargins;
    rowMargins.top = SPKUI_RowVMargin;
    rowMargins.bottom = SPKUI_RowVMargin;
    // Measured on native: icons sit 17 pt from the edge. The config PRESERVES
    // container margins by default when they are larger
    // (axesPreservingSuperviewLayoutMargins) — which is why 16 does not
    // did not apply: it lost against the cell's ~22.
    rowMargins.leading = SPKUI_RowLeading;
    rowMargins.trailing = SPKUI_RowTrailing;
    cellContentConfig.directionalLayoutMargins = rowMargins;
    cellContentConfig.axesPreservingSuperviewLayoutMargins = UIAxisNeither;  // "no axis" — not UIAxisBoth, which would re-preserve the margins
    cellContentConfig.imageToTextPadding = SPKUI_IconTextGap;
    // IG bundle glyphs come out at ~34 pt and inflated the row to 52
    // (34 + 9 + 9). A 26 pt cap → 44 pt row, the measured native pitch. Special
    // cases (avatars, remote images) restore their own size afterwards.
    cellContentConfig.imageProperties.maximumSize = CGSizeMake(SPKUI_IconMax, SPKUI_IconMax);
    cellContentConfig.imageProperties.reservedLayoutSize = CGSizeMake(SPKUI_IconMax, SPKUI_IconMax);
    BOOL rowEnabled = (row.userInfo[@"enabled"] ? [row.userInfo[@"enabled"] boolValue] : YES) &&
                      (!row.enabledProvider || row.enabledProvider()) &&
                      SPKPrefIsAvailable(row.defaultsKey);

    cellContentConfig.text = row.title;

    // Subtitle
    if (row.subtitle.length) {
        cellContentConfig.secondaryText = row.subtitle;
        cellContentConfig.textToSecondaryTextVerticalPadding = 4.5;
    }

    // Icon
    UIImage *rowIcon = row.iconProvider ? row.iconProvider() : row.icon;
    if (rowIcon != nil) {
        cellContentConfig.image = rowIcon;
        if ([row.userInfo[@"avatarIcon"] boolValue]) {
            // Pre-rendered circular avatar image: apply the same sizing as remote imageUrl.
            cellContentConfig.imageProperties.tintColor = nil;
            cellContentConfig.imageProperties.maximumSize = CGSizeMake(kSPKSettingsRemoteImageSize, kSPKSettingsRemoteImageSize);
            cellContentConfig.imageProperties.reservedLayoutSize = CGSizeMake(kSPKSettingsRemoteImageSize, kSPKSettingsRemoteImageSize);
            cellContentConfig.imageToTextPadding = 14;
        } else {
            cellContentConfig.imageProperties.tintColor = row.iconTintColor ?: [SPKUtils SPKColor_InstagramPrimaryText];
            if (row.subtitle.length > 0) {
                UIImage *raised = SPKSettingsIconRaisedForSubtitle(rowIcon, SPKUI_IconMax, SPKUI_SubtitleIconRise);
                if (raised != rowIcon) {
                    CGSize box = CGSizeMake(SPKUI_IconMax, SPKUI_IconMax + 2.0 * SPKUI_SubtitleIconRise);
                    cellContentConfig.image = raised;
                    cellContentConfig.imageProperties.maximumSize = box;       // already at its final size: no resizing
                    cellContentConfig.imageProperties.reservedLayoutSize = box;
                }
            }
        }
    }

    if ([row.userInfo[@"showsReorderGrabber"] boolValue] && rowIcon != nil) {
        UIColor *iconTintColor = row.iconTintColor ?: [SPKUtils SPKColor_InstagramPrimaryText];
        UIImage *composite = SPKSettingsReorderCompositeImage(rowIcon, iconTintColor);
        cellContentConfig.image = composite;
        cellContentConfig.imageProperties.tintColor = nil;
        // Wider than a glyph: only the height keeps the icon cap, or the grabber
        // and icon would shrink together.
        cellContentConfig.imageProperties.maximumSize = CGSizeMake(composite.size.width, SPKUI_IconMax);
        cellContentConfig.imageProperties.reservedLayoutSize = CGSizeMake(composite.size.width, SPKUI_IconMax);
        cellContentConfig.imageToTextPadding = 12.0;
    }

    // Self-healing avatar (SPKAvatarCache, keyed by PK)
    if (row.avatarPK.length > 0) {
        UIImage *warm = [[SPKAvatarCache shared] cachedImageForPK:row.avatarPK];
        if (warm) {
            cellContentConfig.image = SPKSettingsSizedRemoteImage(warm, YES);
            cellContentConfig.imageProperties.tintColor = nil;
        } else {
            // Crisp native-size glyph placeholder (the asset is 24px — don't upscale).
            NSString *glyphName = row.avatarIsGroup ? @"group" : @"user_circle";
            UIImage *placeholder = [SPKAssetUtils instagramIconNamed:glyphName pointSize:24.0 renderingMode:UIImageRenderingModeAlwaysTemplate]
                                       ?: [SPKAssetUtils instagramIconNamed:@"user_circle" pointSize:24.0 renderingMode:UIImageRenderingModeAlwaysTemplate];
            cellContentConfig.image = placeholder;
            cellContentConfig.imageProperties.tintColor = [SPKUtils SPKColor_InstagramSecondaryText];
            [self loadAvatarForPK:row.avatarPK urlString:row.avatarURLString atIndexPath:indexPath forTableView:tableView];
        }
        cellContentConfig.imageProperties.maximumSize = CGSizeMake(kSPKSettingsRemoteImageSize, kSPKSettingsRemoteImageSize);
        cellContentConfig.imageProperties.reservedLayoutSize = CGSizeMake(kSPKSettingsRemoteImageSize, kSPKSettingsRemoteImageSize);
        cellContentConfig.imageToTextPadding = 14;
    }

    // Image url
    if (row.avatarPK.length == 0 && row.imageUrl != nil) {
        BOOL circular = ![row.userInfo[@"remoteImageCircular"] isEqual:@NO];
        NSString *cacheKey = [NSString stringWithFormat:@"%@|%@", row.imageUrl.absoluteString, circular ? @"circle" : @"square"];
        UIImage *cachedImage = [SPKSettingsRemoteImageCache() objectForKey:cacheKey];
        if (cachedImage) {
            cellContentConfig.image = cachedImage;
            cellContentConfig.imageProperties.maximumSize = CGSizeMake(kSPKSettingsRemoteImageSize, kSPKSettingsRemoteImageSize);
            cellContentConfig.imageProperties.reservedLayoutSize = CGSizeMake(kSPKSettingsRemoteImageSize, kSPKSettingsRemoteImageSize);
        } else {
            [self loadImageFromURL:row.imageUrl atIndexPath:indexPath forTableView:tableView circular:circular];
        }

        cellContentConfig.imageToTextPadding = 14;
    }

    // Custom Tint Color
    if (row.tintColor != nil && rowEnabled) {
        cellContentConfig.textProperties.color = row.tintColor;
    }

    switch (row.type) {
    case SPKTableCellStatic: {
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        break;
    }

    case SPKTableCellLink: {
        cellContentConfig.textProperties.color = [SPKUtils SPKColor_InstagramBlue];
        UIFont *linkFont = [row.userInfo[@"titleFont"] isKindOfClass:[UIFont class]]
                               ? row.userInfo[@"titleFont"]
                               : [UIFont systemFontOfSize:[UIFont preferredFontForTextStyle:UIFontTextStyleBody].pointSize weight:UIFontWeightMedium];
        cellContentConfig.textProperties.font = linkFont;

        cell.selectionStyle = UITableViewCellSelectionStyleDefault;

        UIImageView *imageView = [[UIImageView alloc] initWithImage:[SPKAssetUtils instagramIconNamed:@"compass" pointSize:20.0]];
        imageView.tintColor = [SPKUtils SPKColor_InstagramTertiaryText];
        cell.accessoryView = imageView;

        break;
    }

    case SPKTableCellSwitch: {
        SPKSwitch *toggle = [SPKSwitch new];
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        if (row.switchValueProvider) {
            toggle.on = row.switchValueProvider();
        } else if (!SPKPrefIsAvailable(row.defaultsKey)) {
            toggle.on = NO;
        } else {
            NSString *effectiveKey = SPKEffectivePreferenceKey(row.defaultsKey);
            id storedValue = [defaults objectForKey:effectiveKey] ?: [defaults objectForKey:row.defaultsKey];
            NSNumber *defaultValue = row.userInfo[@"defaultValue"];
            toggle.on = storedValue ? [storedValue boolValue] : defaultValue.boolValue;
        }
        if (!row.switchValueProvider && row.mutuallyExclusiveDefaultsKey.length) {
            BOOL otherOn = [SPKUtils getBoolPref:row.mutuallyExclusiveDefaultsKey];
            toggle.enabled = toggle.isOn || !otherOn;
        }
        toggle.enabled = toggle.enabled && rowEnabled;
        if (!rowEnabled) {
            cellContentConfig.textProperties.color = [SPKUtils SPKColor_InstagramSecondaryText];
            cellContentConfig.secondaryTextProperties.color = [SPKUtils SPKColor_InstagramTertiaryText];
        }

        objc_setAssociatedObject(toggle, rowStaticRef, row, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

        [toggle addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];

        cell.accessoryView = toggle;
        cell.editingAccessoryView = toggle;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        break;
    }

    case SPKTableCellStepper: {
        UIStepper *stepper = [UIStepper new];
        stepper.minimumValue = row.min;
        stepper.maximumValue = row.max;
        stepper.stepValue = row.step;
        stepper.value = SPKNormalizedStepperValue(row, [SPKUtils getDoublePref:row.defaultsKey]);

        objc_setAssociatedObject(stepper, rowStaticRef, row, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

        [stepper addTarget:self
                      action:@selector(stepperChanged:)
            forControlEvents:UIControlEventValueChanged];

        // Template subtitle
        if (row.subtitle.length) {
            cellContentConfig.secondaryText = [self formatString:row.subtitle withValue:stepper.value step:row.step label:row.label singularLabel:row.singularLabel];
        }

        cell.accessoryView = stepper;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        break;
    }

    case SPKTableCellButton: {
        NSString *accessoryText = SPKSettingsAccessoryText(row);
        if (rowEnabled && accessoryText.length > 0) {
            cellContentConfig.secondaryText = accessoryText;
            cellContentConfig.prefersSideBySideTextAndSecondaryText = YES;
            cellContentConfig.secondaryTextProperties.numberOfLines = 1;
            cellContentConfig.secondaryTextProperties.color = [SPKUtils SPKColor_InstagramSecondaryText];
            cellContentConfig.secondaryTextProperties.font =
                [[UIFontMetrics metricsForTextStyle:UIFontTextStyleSubheadline] scaledFontForFont:[UIFont systemFontOfSize:SPKUI_ValueFontSize
                                                                                                                     weight:UIFontWeightRegular]];
        }
        // Avatar rows read as flat list entries (like Profile Analyzer), not
        // settings nav rows — no disclosure chevron.
        BOOL hidesChevron = row.avatarPK.length > 0 || [row.userInfo[@"hidesDisclosure"] boolValue];
        cell.accessoryType = (rowEnabled && !hidesChevron) ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;
        if (!rowEnabled) {
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cellContentConfig.textProperties.color = [SPKUtils SPKColor_InstagramSecondaryText];
            cellContentConfig.secondaryTextProperties.color = [SPKUtils SPKColor_InstagramTertiaryText];
        }
        break;
    }

    case SPKTableCellMenu: {
        UIButton *menuButton = [UIButton buttonWithType:UIButtonTypeSystem];
        // Show the chosen value, like every other picker. The dots are only a
        // placeholder for a row that provides no text at all.
        NSString *menuValue = SPKSettingsAccessoryText(row);
        [menuButton setTitle:(menuValue.length > 0 ? menuValue : @"•••") forState:UIControlStateNormal];
        // One picker for the whole tweak: the value menus now open the same view
        // as the gates, built from the UIMenu the row already provides. The
        // commands carry their key and value, so applying a choice runs through
        // menuChanged: exactly as before.
        // No UIKit menu on the button: assigning one installs its own gesture,
        // which swallows the tap. The call still runs, for its side effect of
        // putting the current value in the title.
        (void)[row menuForButton:menuButton];
        menuButton.showsMenuAsPrimaryAction = NO;
        objc_setAssociatedObject(menuButton, kSPKMenuButtonRowKey, row, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [menuButton addTarget:self action:@selector(spk_menuButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
        menuButton.enabled = rowEnabled;
        // Same weight as the other value labels (Regular, like IG).
        menuButton.titleLabel.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleSubheadline] scaledFontForFont:[UIFont systemFontOfSize:SPKUI_ValueFontSize
                                                                                                                                          weight:UIFontWeightRegular]];
        menuButton.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        [menuButton setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
        [menuButton setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];

        UIButtonConfiguration *config = menuButton.configuration ?: [UIButtonConfiguration plainButtonConfiguration];
        config.contentInsets = NSDirectionalEdgeInsetsMake(8, 8, 8, 8);
        config.image = [UIImage systemImageNamed:@"chevron.up.chevron.down"];
        config.imagePlacement = NSDirectionalRectEdgeTrailing;
        config.imagePadding = 6.0;
        // UIButtonConfiguration overrides titleLabel.font; the value label
        // keeps the shared 14 pt state-text size through the transformer.
        config.titleTextAttributesTransformer = ^NSDictionary<NSAttributedStringKey, id> *(NSDictionary<NSAttributedStringKey, id> *attrs) {
            NSMutableDictionary *withFont = [attrs mutableCopy];
            withFont[NSFontAttributeName] = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleSubheadline]
                scaledFontForFont:[UIFont systemFontOfSize:SPKUI_ValueFontSize weight:UIFontWeightRegular]];
            return withFont;
        };
        config.preferredSymbolConfigurationForImage = [UIImageSymbolConfiguration configurationWithPointSize:10.0 weight:UIImageSymbolWeightBold];

        menuButton.configuration = config;
        // Must be set AFTER assigning the configuration: UIButtonConfiguration
        // re-manages titleLabel and defaults it to multi-line, so a long selected
        // value wraps onto a second line inside the accessory. Clamp it to one line
        // (truncating) here so the value stays on the row like every other picker.
        menuButton.titleLabel.numberOfLines = 1;
        menuButton.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        menuButton.tintColor = rowEnabled ? [SPKUtils SPKColor_InstagramSecondaryText] : [SPKUtils SPKColor_InstagramTertiaryText];
        if (!rowEnabled) {
            cellContentConfig.textProperties.color = [SPKUtils SPKColor_InstagramSecondaryText];
            cellContentConfig.secondaryTextProperties.color = [SPKUtils SPKColor_InstagramTertiaryText];
        }

        [menuButton sizeToFit];

        cell.accessoryView = menuButton;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        break;
    }

    case SPKTableCellNavigation: {
        NSString *accessoryText = SPKSettingsAccessoryText(row);
        if (rowEnabled && accessoryText.length > 0 && row.subtitle.length > 0) {
            // Both a subtitle and an accessory ("General · 4 active"): keep
            // the subtitle below the title, move the accessory into a
            // trailing label + chevron so neither steals secondaryText.
            UILabel *accessoryLabel = [[UILabel alloc] init];
            accessoryLabel.text = accessoryText;
            accessoryLabel.textColor = [SPKUtils SPKColor_InstagramSecondaryText];
            accessoryLabel.font =
                [[UIFontMetrics metricsForTextStyle:UIFontTextStyleSubheadline] scaledFontForFont:[UIFont systemFontOfSize:SPKUI_ValueFontSize
                                                                                                                     weight:UIFontWeightRegular]];
            UIImageView *chevronView = [[UIImageView alloc] initWithImage:
                [UIImage systemImageNamed:@"chevron.right"
                        withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:13.0
                                                                                          weight:UIImageSymbolWeightSemibold]]];
            chevronView.tintColor = [SPKUtils SPKColor_InstagramTertiaryText];
            [accessoryLabel sizeToFit];
            [chevronView sizeToFit];
            // Same trailing margin the native side-by-side layout uses, so the
            // value column lines up with every single-line row above and below.
            CGFloat gap = SPKUI_RowTrailing;
            CGFloat w = accessoryLabel.bounds.size.width + gap + chevronView.bounds.size.width;
            CGFloat h = MAX(accessoryLabel.bounds.size.height, chevronView.bounds.size.height);
            // The box is taller than its content and stays centered by UIKit:
            // value + chevron ride up to the title line, like the glyph.
            UIView *trailing = [[UIView alloc] initWithFrame:CGRectMake(0, 0, w, h + 2.0 * SPKUI_SubtitleIconRise)];
            accessoryLabel.frame = CGRectMake(0, (h - accessoryLabel.bounds.size.height) / 2.0,
                                              accessoryLabel.bounds.size.width, accessoryLabel.bounds.size.height);
            chevronView.frame = CGRectMake(w - chevronView.bounds.size.width, (h - chevronView.bounds.size.height) / 2.0,
                                           chevronView.bounds.size.width, chevronView.bounds.size.height);
            [trailing addSubview:accessoryLabel];
            [trailing addSubview:chevronView];
            cell.accessoryView = trailing;
        } else if (rowEnabled && accessoryText.length > 0) {
            cellContentConfig.secondaryText = accessoryText;
            cellContentConfig.prefersSideBySideTextAndSecondaryText = YES;
            cellContentConfig.secondaryTextProperties.numberOfLines = 1;
            cellContentConfig.secondaryTextProperties.lineBreakMode = NSLineBreakByTruncatingTail;
            cellContentConfig.secondaryTextProperties.color = [SPKUtils SPKColor_InstagramSecondaryText];
            cellContentConfig.secondaryTextProperties.font =
                [[UIFontMetrics metricsForTextStyle:UIFontTextStyleSubheadline] scaledFontForFont:[UIFont systemFontOfSize:SPKUI_ValueFontSize
                                                                                                                     weight:UIFontWeightRegular]];
        }
        if (cell.accessoryView == nil)
            cell.accessoryType = rowEnabled ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;
        if (!rowEnabled) {
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cellContentConfig.textProperties.color = [SPKUtils SPKColor_InstagramSecondaryText];
            cellContentConfig.secondaryTextProperties.color = [SPKUtils SPKColor_InstagramTertiaryText];
        }
        break;
    }

    case SPKTableCellTextField: {
        UITextField *textField = [[UITextField alloc] initWithFrame:CGRectMake(0, 0, 150, 34)];
        textField.textAlignment = NSTextAlignmentRight;
        textField.font = [UIFont systemFontOfSize:[UIFont preferredFontForTextStyle:UIFontTextStyleBody].pointSize weight:UIFontWeightMedium];
        textField.textColor = rowEnabled ? [SPKUtils SPKColor_InstagramPrimaryText] : [SPKUtils SPKColor_InstagramTertiaryText];
        textField.placeholder = row.placeholder;
        textField.keyboardType = row.keyboardType;
        textField.text = [SPKUtils getStringPref:row.defaultsKey];
        textField.enabled = rowEnabled;
        textField.returnKeyType = UIReturnKeyDone;
        textField.delegate = self;

        if (!rowEnabled) {
            cellContentConfig.textProperties.color = [SPKUtils SPKColor_InstagramSecondaryText];
        }

        objc_setAssociatedObject(textField, rowStaticRef, row, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [textField addTarget:self action:@selector(textFieldChanged:) forControlEvents:UIControlEventEditingDidEnd];

        cell.accessoryView = textField;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        break;
    }

    case SPKTableCellValue: {
        cellContentConfig.secondaryText = row.subtitle;
        cellContentConfig.prefersSideBySideTextAndSecondaryText = YES;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        break;
    }

    case SPKTableCellStorageBar: {
        // A figure that is read, not set: no icon, nothing to tap.
        cellContentConfig.text = @"";
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.accessoryType = UITableViewCellAccessoryNone;

        // Attached as the accessory view, like every other custom control in
        // this table: a subview of contentView is wiped when the content
        // configuration is applied a few lines below. Sized from the table's
        // width, which is known here — the cell's own bounds are not yet.
        CGFloat barHeight = row.barLegend.length > 0 ? SPKUI_RowHeight + 14.0 : SPKUI_RowHeight;
        // Left edge on the icon column: the accessory sits against the trailing
        // margin, so the width is what places its start.
        CGFloat barWidth = MAX(0.0, CGRectGetWidth(tableView.bounds) - SPKUI_RowLeading - 20.0);
        SPKStorageBarView *bar = [[SPKStorageBarView alloc] initWithFrame:CGRectMake(0, 0, barWidth, barHeight)];
        bar.tag = kSPKStorageBarTag;
        bar.fractions = row.barFractions;
        bar.value = SPKStorageValueText(row.barValue);
        bar.legend = row.barLegend;
        cell.accessoryView = bar;
        break;
    }
    }

    cell.contentConfiguration = cellContentConfig;
    cell.showsReorderControl = NO;
    cell.shouldIndentWhileEditing = NO;

    return cell;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.sections[section][@"rows"] count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if ([self isSearching] && [self.sections[section][@"breadcrumbComponents"] isKindOfClass:[NSArray class]]) {
        return nil;
    }
    return self.sections[section][@"header"];
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    NSArray<NSString *> *components = self.sections[section][@"breadcrumbComponents"];
    if (![self isSearching] || ![components isKindOfClass:[NSArray class]] || components.count == 0) {
        return [self spk_nativeHeaderForSection:section forSizing:NO];
    }

    UITableViewHeaderFooterView *header = [[UITableViewHeaderFooterView alloc] initWithReuseIdentifier:nil];
    UIStackView *stack = [[UIStackView alloc] initWithFrame:CGRectZero];
    stack.axis = UILayoutConstraintAxisHorizontal;
    stack.alignment = UIStackViewAlignmentCenter;
    stack.spacing = 5.0;
    stack.translatesAutoresizingMaskIntoConstraints = NO;

    UIFont *font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
    UIColor *textColor = [SPKUtils SPKColor_InstagramSecondaryText];
    UIColor *chevronColor = [SPKUtils SPKColor_InstagramTertiaryText];
    UIImage *chevron = SPKSettingsBreadcrumbChevronImage();

    for (NSUInteger index = 0; index < components.count; index++) {
        if (index > 0) {
            if (chevron) {
                UIImageView *imageView = [[UIImageView alloc] initWithImage:chevron];
                imageView.tintColor = chevronColor;
                imageView.contentMode = UIViewContentModeScaleAspectFit;
                [imageView setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
                [stack addArrangedSubview:imageView];
            } else {
                UILabel *separator = [UILabel new];
                separator.text = @"\u203a";
                separator.font = font;
                separator.textColor = chevronColor;
                [separator setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
                [stack addArrangedSubview:separator];
            }
        }

        UILabel *label = [UILabel new];
        label.text = components[index];
        label.font = font;
        label.textColor = textColor;
        label.numberOfLines = 1;
        label.lineBreakMode = NSLineBreakByTruncatingTail;
        [stack addArrangedSubview:label];
    }

    [header.contentView addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:header.contentView.layoutMarginsGuide.leadingAnchor],
        [stack.trailingAnchor constraintLessThanOrEqualToAnchor:header.contentView.layoutMarginsGuide.trailingAnchor],
        [stack.topAnchor constraintEqualToAnchor:header.contentView.topAnchor
                                        constant:8.0],
        [stack.bottomAnchor constraintEqualToAnchor:header.contentView.bottomAnchor
                                           constant:-4.0]
    ]];
    header.accessibilityLabel = SPKSettingsBreadcrumbText(components);
    return header;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if ([self isSearching] && [self.sections[section][@"breadcrumbComponents"] isKindOfClass:[NSArray class]] && [self.sections[section][@"breadcrumbComponents"] count] > 0) {
        return 34.0;
    }
    // Flat pages: collapse the empty section header so rows meet the nav bar with
    // no grey plain-header strip.
    NSString *header = self.sections[section][@"header"];
    NSArray<SPKSetting *> *helpRows = SPKSettingsHelpRowsInSection(self.sections[section]);
    if ([self preferredTableViewStyle] != UITableViewStyleInsetGrouped && header.length == 0 && helpRows.count == 0) {
        // First untitled section (the root, flat pages): a
        // touch of breathing room under the title bar instead of hugging the content.
        return (section == 0) ? SPKUI_FirstSectionTop : CGFLOAT_MIN;
    }
    UIView *native = [self spk_nativeHeaderForSection:section forSizing:YES];
    if (native == nil) {
        return UITableViewAutomaticDimension;
    }
    // estimatedSectionHeaderHeight is 0: without an explicit measure, the custom
    // view renders collapsed. Same pattern as the footers — the cache makes the call free.
    CGFloat width = CGRectGetWidth(tableView.bounds);
    if (width <= 0.0) {
        width = CGRectGetWidth(UIScreen.mainScreen.bounds);
    }
    CGSize fitting = [native systemLayoutSizeFittingSize:CGSizeMake(width, UILayoutFittingCompressedSize.height)
                           withHorizontalFittingPriority:UILayoutPriorityRequired
                                 verticalFittingPriority:UILayoutPriorityFittingSizeLevel];
    return MAX(fitting.height, 30.0);
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return self.sections[section][@"footer"];
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
    // Convention: no footer text. A full-width band separates the groups,
    // matching Instagram's native settings.
    UIView *band = [UIView new];
    band.backgroundColor = [UIColor colorWithRed:0.937 green:0.937 blue:0.945 alpha:1.0];  // #EFEFF1
    return band;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    // Native band measured: 6 pt (18 px), not 8.
    return (section == (NSInteger)self.sections.count - 1) ? SPKUI_BandLast : SPKUI_BandHeight;
}

- (UIView *)spk_nativeHeaderForSection:(NSInteger)section forSizing:(BOOL)forSizing {
    NSString *title = self.sections[section][@"header"];
    NSArray<SPKSetting *> *helpRows = SPKSettingsHelpRowsInSection(self.sections[section]);
    if (title.length == 0 && helpRows.count == 0) {
        return nil;
    }

    // The cache is a sizing template only (heightForHeader). Never
    // displayed: handing UIKit an instance it already owns — tolerated in
    // tolerated in plain by luck, dangerous in grouped, where header
    // lifecycles differ. Display always receives a fresh view.
    NSNumber *cacheKey = @(section);
    if (forSizing) {
        UIView *cached = self.footerViewCache[cacheKey];
        if (cached) {
            return cached;
        }
    }

    // A bare UIView, NOT a UITableViewHeaderFooterView: when the section also
    // supplies a title through titleForHeaderInSection:, UIKit fills the
    // HeaderFooterView's built-in textLabel over the custom label — the
    // doubled-text artifact. A plain UIView has nothing to fill.
    UIView *container = [UIView new];
    // Opaque: with plain-style pinning, nothing shows through behind.
    container.backgroundColor = [SPKUtils SPKColor_InstagramBackground];

    UILabel *label = [UILabel new];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.text = title;
    UIFont *base = [UIFont systemFontOfSize:SPKUI_HeaderFontSize weight:UIFontWeightSemibold];
    label.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleSubheadline] scaledFontForFont:base];
    label.adjustsFontForContentSizeCategory = YES;
    label.textColor = [UIColor colorWithRed:0.396 green:0.404 blue:0.420 alpha:1.0];  // #65676B
    [container addSubview:label];

    NSMutableArray<NSLayoutConstraint *> *constraints = [@[
        [label.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:SPKUI_HeaderLeading],
        [label.topAnchor constraintEqualToAnchor:container.topAnchor constant:SPKUI_HeaderTop],
        [label.bottomAnchor constraintEqualToAnchor:container.bottomAnchor constant:-SPKUI_HeaderBottom]
    ] mutableCopy];

    if (helpRows.count > 0) {
        UIButton *helpButton = [UIButton buttonWithType:UIButtonTypeSystem];
        helpButton.translatesAutoresizingMaskIntoConstraints = NO;
        helpButton.tag = section;
        helpButton.tintColor = [UIColor colorWithRed:0.651 green:0.651 blue:0.675 alpha:1.0];  // #A6A6AC
        helpButton.accessibilityLabel = @"About these settings";
        BOOL hidesRows = SPKSectionHidesRows(self.sections[section], self.originalSections);
        [helpButton setImage:[UIImage systemImageNamed:(hidesRows ? @"info.circle.fill" : @"info.circle")
                                     withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:17.0
                                                                                                       weight:UIImageSymbolWeightRegular]]
                    forState:UIControlStateNormal];
        [helpButton addTarget:self action:@selector(spk_helpButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
        helpButton.contentEdgeInsets = UIEdgeInsetsMake(12.0, 12.0, 12.0, 12.0);
        [container addSubview:helpButton];
        [constraints addObjectsFromArray:@[
            [helpButton.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-6.0],
            [helpButton.centerYAnchor constraintEqualToAnchor:label.centerYAnchor constant:2.0],
            [label.trailingAnchor constraintLessThanOrEqualToAnchor:helpButton.leadingAnchor constant:-4.0]
        ]];
    } else {
        [constraints addObject:[label.trailingAnchor constraintLessThanOrEqualToAnchor:container.trailingAnchor constant:-16.0]];
    }
    [NSLayoutConstraint activateConstraints:constraints];

    if (forSizing) {
        self.footerViewCache[cacheKey] = container;
    }
    return container;
}

- (void)spk_helpButtonTapped:(UIButton *)sender {
    NSInteger section = sender.tag;
    if (section < 0 || section >= (NSInteger)self.sections.count)
        return;

    NSArray<SPKSetting *> *helpRows = SPKSettingsHelpRowsInSection(self.sections[section]);
    // Untitled sections (Meta AI, for example) borrow the page title.
    NSString *header = self.sections[section][@"header"];
    [SPKSettingsHelpSheetViewController presentForSectionTitle:header.length > 0 ? header : self.title
                                                          rows:helpRows
                                            fromViewController:self];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.sections.count;
}

// MARK: - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    SPKSetting *row = self.sections[indexPath.section][@"rows"][indexPath.row];
    if (!row)
        return;
    BOOL rowEnabled = (row.userInfo[@"enabled"] ? [row.userInfo[@"enabled"] boolValue] : YES) &&
                      (!row.enabledProvider || row.enabledProvider()) &&
                      SPKPrefIsAvailable(row.defaultsKey);
    if (!rowEnabled) {
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        return;
    }

    if (row.type == SPKTableCellLink) {
        [[UIApplication sharedApplication] openURL:row.url options:@{} completionHandler:nil];
    } else if (row.type == SPKTableCellButton) {
        NSArray *spk_toggleMenuItems = row.userInfo[@"spk_toggleMenuItems"];
        if (spk_toggleMenuItems.count > 0) {
            UITableViewCell *anchorCell = [tableView cellForRowAtIndexPath:indexPath];
            [SPKToggleMenu presentWithItems:spk_toggleMenuItems
                                   fromView:(anchorCell ?: tableView)
                           inViewController:self
                                  onDismiss:^{ [tableView reloadData]; }];
        } else if (row.action != nil) {
            row.action();
            [tableView reloadData];
        }
    } else if (row.type == SPKTableCellNavigation) {
        __weak __typeof(self) weakSelf = self;
        void (^push)(void) = ^{
            __strong __typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf)
                return;
            if (row.navSections.count > 0) {
                UIViewController *vc = [[SPKSettingsViewController alloc] initWithTitle:row.title sections:row.navSections reduceMargin:NO];
                ((SPKSettingsViewController *)vc).defersRestartPrompt = [row.userInfo[@"deferRestartPrompt"] boolValue];
                vc.title = row.title;
                [strongSelf.navigationController pushViewController:vc animated:YES];
            } else if (row.navViewController) {
                [strongSelf.navigationController pushViewController:row.navViewController animated:YES];
            }
        };
        if (row.navigationGate)
            row.navigationGate(push);
        else
            push();
    }

    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([self isSearching])
        return NO;
    return [self.sections[indexPath.section][@"allowsReordering"] boolValue];
}

- (NSIndexPath *)tableView:(UITableView *)tableView targetIndexPathForMoveFromRowAtIndexPath:(NSIndexPath *)sourceIndexPath toProposedIndexPath:(NSIndexPath *)proposedDestinationIndexPath {
    if (sourceIndexPath.section != proposedDestinationIndexPath.section) {
        NSInteger rowCount = [self.sections[sourceIndexPath.section][@"rows"] count];
        NSInteger targetRow = MIN(MAX(0, proposedDestinationIndexPath.row), MAX(0, rowCount - 1));
        return [NSIndexPath indexPathForRow:targetRow inSection:sourceIndexPath.section];
    }
    return proposedDestinationIndexPath;
}

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath toIndexPath:(NSIndexPath *)destinationIndexPath {
    NSMutableArray *rows = self.sections[sourceIndexPath.section][@"rows"];
    if (![rows isKindOfClass:[NSMutableArray class]])
        return;

    SPKSetting *row = rows[sourceIndexPath.row];
    [rows removeObjectAtIndex:sourceIndexPath.row];
    [rows insertObject:row atIndex:destinationIndexPath.row];

    NSString *reorderDefaultsKey = self.sections[sourceIndexPath.section][@"reorderDefaultsKey"];
    if (reorderDefaultsKey.length > 0) {
        NSMutableArray<NSString *> *order = [NSMutableArray array];
        for (SPKSetting *candidate in rows) {
            NSString *identifier = candidate.userInfo[@"actionIdentifier"];
            if (identifier.length > 0)
                [order addObject:identifier];
        }
        [[NSUserDefaults standardUserDefaults] setObject:[order copy] forKey:SPKEffectivePreferenceKey(reorderDefaultsKey)];
    }
    self.originalSections = [self.sections copy];
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    return UITableViewCellEditingStyleNone;
}

- (NSArray<UIDragItem *> *)tableView:(UITableView *)tableView itemsForBeginningDragSession:(id<UIDragSession>)session atIndexPath:(NSIndexPath *)indexPath {
    if (![self tableView:tableView canMoveRowAtIndexPath:indexPath]) {
        return @[];
    }

    SPKSetting *row = self.sections[indexPath.section][@"rows"][indexPath.row];
    NSString *identifier = row.userInfo[@"actionIdentifier"] ?: row.title ?
                                                                          : @"action";
    NSItemProvider *provider = [[NSItemProvider alloc] initWithObject:identifier];
    UIDragItem *item = [[UIDragItem alloc] initWithItemProvider:provider];
    item.localObject = row;
    return @[ item ];
}

- (BOOL)tableView:(UITableView *)tableView dragSessionAllowsMoveOperation:(id<UIDragSession>)session {
    return YES;
}

- (BOOL)tableView:(UITableView *)tableView dragSessionIsRestrictedToDraggingApplication:(id<UIDragSession>)session {
    return YES;
}

- (UITableViewDropProposal *)tableView:(UITableView *)tableView dropSessionDidUpdate:(id<UIDropSession>)session withDestinationIndexPath:(NSIndexPath *)destinationIndexPath {
    if (session.localDragSession == nil || destinationIndexPath == nil) {
        return [[UITableViewDropProposal alloc] initWithDropOperation:UIDropOperationCancel];
    }
    if (![self.sections[destinationIndexPath.section][@"allowsReordering"] boolValue]) {
        return [[UITableViewDropProposal alloc] initWithDropOperation:UIDropOperationCancel];
    }
    return [[UITableViewDropProposal alloc] initWithDropOperation:UIDropOperationMove intent:UITableViewDropIntentInsertAtDestinationIndexPath];
}

- (void)tableView:(UITableView *)tableView performDropWithCoordinator:(id<UITableViewDropCoordinator>)coordinator {
    NSIndexPath *destinationIndexPath = coordinator.destinationIndexPath;
    if (destinationIndexPath == nil)
        return;

    id<UITableViewDropItem> dropItem = coordinator.items.firstObject;
    NSIndexPath *sourceIndexPath = dropItem.sourceIndexPath;
    if (sourceIndexPath == nil || sourceIndexPath.section != destinationIndexPath.section)
        return;
    if (![self tableView:tableView canMoveRowAtIndexPath:sourceIndexPath])
        return;

    NSInteger rowCount = [self.sections[sourceIndexPath.section][@"rows"] count];
    NSInteger destinationRow = MIN(MAX(0, destinationIndexPath.row), MAX(0, rowCount - 1));
    NSIndexPath *clampedDestination = [NSIndexPath indexPathForRow:destinationRow inSection:destinationIndexPath.section];

    [tableView
        performBatchUpdates:^{
            [self tableView:tableView moveRowAtIndexPath:sourceIndexPath toIndexPath:clampedDestination];
            [tableView moveRowAtIndexPath:sourceIndexPath toIndexPath:clampedDestination];
        }
                 completion:nil];

    [coordinator dropItem:dropItem.dragItem toRowAtIndexPath:clampedDestination];
}

// MARK: - Search

- (BOOL)isSearching {
    return self.searchController.isActive && self.searchController.searchBar.text.length > 0;
}

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    NSString *query = SPKSettingsNormalizedQuery(searchController.searchBar.text);
    if (query.length == 0) {
        self.sections = SPKVisibleSectionsCopy(self.originalSections);
    } else if (self.searchesAllSettings) {
        self.sections = [self searchAllSettingsForQuery:query];
    } else {
        self.sections = [self filterCurrentSettingsForQuery:query];
    }
    self.tableView.dragInteractionEnabled = ![self isSearching] && [self pageAllowsReordering];
    [self.tableView reloadData];
}

- (NSMutableArray *)filterCurrentSettingsForQuery:(NSString *)query {
    NSArray<NSString *> *tokens = SPKSettingsSearchTokens(query);
    NSMutableArray *filteredSections = [NSMutableArray array];
    for (NSDictionary *section in self.originalSections) {
        NSArray *rows = section[@"rows"];
        NSMutableArray *matchedRows = [NSMutableArray array];
        NSString *sectionTitle = section[@"header"];
        NSString *sectionFooter = section[@"footer"];
        for (SPKSetting *row in rows) {
            if (row.hiddenProvider && row.hiddenProvider())
                continue;
            if (SPKSettingsRowMatchesTokens(row, tokens, self.title, sectionTitle, sectionFooter)) {
                [matchedRows addObject:row];
            }
        }
        if (matchedRows.count == 0)
            continue;

        NSMutableDictionary *filteredSection = [section mutableCopy];
        filteredSection[@"rows"] = matchedRows;
        filteredSection[@"allowsReordering"] = @NO;
        [filteredSections addObject:filteredSection];
    }
    return filteredSections;
}

- (NSMutableArray *)searchAllSettingsForQuery:(NSString *)query {
    NSMutableDictionary<NSString *, NSMutableArray<SPKSetting *> *> *rowsByPath = [NSMutableDictionary dictionary];
    NSMutableDictionary<NSString *, NSArray<NSString *> *> *componentsByPath = [NSMutableDictionary dictionary];
    NSMutableArray<NSString *> *orderedPaths = [NSMutableArray array];
    NSArray<NSString *> *tokens = SPKSettingsSearchTokens(query);
    [self collectSearchRowsFromSections:self.originalSections
                         pathComponents:@[]
                                 tokens:tokens
                             rowsByPath:rowsByPath
                       componentsByPath:componentsByPath
                           orderedPaths:orderedPaths];

    NSMutableArray *sections = [NSMutableArray array];
    for (NSString *path in orderedPaths) {
        NSArray *rows = rowsByPath[path];
        if (rows.count == 0)
            continue;
        [sections addObject:[@{
                      @"header" : path,
                      @"breadcrumbComponents" : componentsByPath[path] ?: @[],
                      @"rows" : [rows mutableCopy],
                      @"allowsReordering" : @NO
                  } mutableCopy]];
    }
    return sections;
}

- (void)collectSearchRowsFromSections:(NSArray *)sections
                       pathComponents:(NSArray<NSString *> *)pathComponents
                               tokens:(NSArray<NSString *> *)tokens
                           rowsByPath:(NSMutableDictionary<NSString *, NSMutableArray<SPKSetting *> *> *)rowsByPath
                     componentsByPath:(NSMutableDictionary<NSString *, NSArray<NSString *> *> *)componentsByPath
                         orderedPaths:(NSMutableArray<NSString *> *)orderedPaths {
    for (NSDictionary *section in sections) {
        NSString *sectionTitle = section[@"header"];
        NSString *sectionFooter = section[@"footer"];
        NSArray<NSString *> *sectionPathComponents = SPKSettingsPathComponentsByAppending(pathComponents, sectionTitle);
        for (SPKSetting *row in section[@"rows"]) {
            if (![row isKindOfClass:[SPKSetting class]])
                continue;
            if (row.hiddenProvider && row.hiddenProvider())
                continue;

            NSArray<NSString *> *rowPathComponents = sectionPathComponents.count > 0 ? sectionPathComponents : SPKSettingsPathComponentsByAppending(pathComponents, row.title);
            NSString *rowPath = SPKSettingsBreadcrumbText(rowPathComponents);
            if (SPKSettingsRowMatchesTokens(row, tokens, rowPath, sectionTitle, sectionFooter)) {
                NSString *resultPath = rowPath.length > 0 ? rowPath : (row.title ?: @"");
                NSMutableArray *rows = rowsByPath[resultPath];
                if (!rows) {
                    rows = [NSMutableArray array];
                    rowsByPath[resultPath] = rows;
                    componentsByPath[resultPath] = rowPathComponents;
                    [orderedPaths addObject:resultPath];
                }
                [rows addObject:row];
            }

            NSArray *childSections = row.navSections.count > 0 ? row.navSections : (row.searchSectionsProvider ? row.searchSectionsProvider() : nil);
            if (childSections.count > 0) {
                NSArray<NSString *> *childPathComponents = SPKSettingsPathComponentsByAppending(pathComponents, row.title);
                [self collectSearchRowsFromSections:childSections
                                     pathComponents:childPathComponents
                                             tokens:tokens
                                         rowsByPath:rowsByPath
                                   componentsByPath:componentsByPath
                                       orderedPaths:orderedPaths];
            }
        }
    }
}

// MARK: - Actions

- (SPKSetting *)settingForSender:(id)sender {
    return objc_getAssociatedObject(sender, rowStaticRef);
}

- (void)switchChanged:(UISwitch *)sender {
    SPKSetting *row = objc_getAssociatedObject(sender, rowStaticRef);
    if (!row)
        return;
    if (!SPKPrefIsAvailable(row.defaultsKey)) {
        sender.on = NO;
        return;
    }

    if (row.switchChangeHandler) {
        row.switchChangeHandler(sender.isOn);
        if (row.action) {
            row.action();
        }
        // Avoid reloading by default: rebuilding the cell swaps in a fresh
        // switch set non-animated, which cuts the native (Liquid Glass) toggle
        // animation short. Handlers that need a table refresh either set
        // reloadsTableOnSwitchChange or reload themselves (e.g. rebuildSections).
        if (row.reloadsTableOnSwitchChange) {
            [self refreshDependentRowsAfterSwitchChange:sender];
        }
        return;
    }

    [[NSUserDefaults standardUserDefaults] setBool:sender.isOn forKey:SPKEffectivePreferenceKey(row.defaultsKey)];
    if (sender.isOn && row.mutuallyExclusiveDefaultsKey.length) {
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:SPKEffectivePreferenceKey(row.mutuallyExclusiveDefaultsKey)];
    }

    SPKLog(@"General", @"Switch changed: %@", sender.isOn ? @"ON" : @"OFF");
    if (sender.isOn) {
        SPKInstallEnabledFeatureHooks();
    }

    if (row.mutuallyExclusiveDefaultsKey.length) {
        [self.tableView reloadData];
    }

    if (row.requiresRestart) {
        if (self.defersRestartPrompt) {
            self.hasPendingRestartChanges = YES;
            self.applyRestartItem.enabled = YES;
        } else {
            [SPKUtils showRestartConfirmation];
        }
    }

    if (row.action) {
        row.action();
    }

    // Same contract as the switchChangeHandler branch above: a plain pref-backed switch
    // that gates other rows still has to refresh them, or their enabledProvider state is
    // stale until the page is left and re-entered.
    if (row.reloadsTableOnSwitchChange) {
        [self refreshDependentRowsAfterSwitchChange:sender];
    }
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

- (void)spk_dismissKeyboard {
    [self.view endEditing:YES];
}

- (void)textFieldChanged:(UITextField *)sender {
    SPKSetting *row = objc_getAssociatedObject(sender, rowStaticRef);
    if (!row)
        return;

    NSString *value = [sender.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    [[NSUserDefaults standardUserDefaults] setObject:value ?: @"" forKey:SPKEffectivePreferenceKey(row.defaultsKey)];
}

- (void)applyRestartChanges {
    [SPKUtils showRestartConfirmation];
}

- (void)stepperChanged:(UIStepper *)sender {
    SPKSetting *row = objc_getAssociatedObject(sender, rowStaticRef);
    double normalizedValue = SPKNormalizedStepperValue(row, sender.value);
    sender.value = normalizedValue;
    [[NSUserDefaults standardUserDefaults] setDouble:normalizedValue forKey:SPKEffectivePreferenceKey(row.defaultsKey)];

    SPKLog(@"General", @"Stepper changed: %f", normalizedValue);

    [self reloadCellForView:sender];
}

// Flattens the row's UIMenu — inline submenus included — into the picker items.
static void SPKCollectMenuCommands(UIMenu *menu, NSMutableArray<UICommand *> *out) {
    for (UIMenuElement *element in menu.children) {
        if ([element isKindOfClass:[UIMenu class]])
            SPKCollectMenuCommands((UIMenu *)element, out);
        else if ([element isKindOfClass:[UICommand class]])
            [out addObject:(UICommand *)element];
    }
}

- (void)spk_menuButtonTapped:(UIButton *)sender {
    SPKSetting *row = objc_getAssociatedObject(sender, kSPKMenuButtonRowKey);
    UIMenu *menu = [row menuForButton:sender] ?: sender.menu;
    if (!menu)
        return;

    NSMutableArray<UICommand *> *commands = [NSMutableArray array];
    SPKCollectMenuCommands(menu, commands);
    if (commands.count == 0)
        return;

    NSMutableArray<SPKToggleMenuItem *> *items = [NSMutableArray array];
    for (UICommand *command in commands) {
        NSDictionary *properties = command.propertyList;
        NSString *key = properties[@"defaultsKey"];
        NSString *value = properties[@"value"];
        if (key.length == 0 || value.length == 0)
            continue;
        SPKToggleMenuItem *item = [SPKToggleMenuItem itemWithTitle:command.title
                                                          iconName:properties[@"iconName"] ?: @""
                                                       defaultsKey:key];
        item.pickValue = value;
        BOOL disabled = (command.attributes & UIMenuElementAttributesDisabled) != 0;
        if (disabled) {
            item.enabledProvider = ^BOOL {
                return NO;
            };
        }
        __weak typeof(self) weakSelf = self;
        item.pickHandler = ^{
            [weakSelf menuChanged:command];
        };
        [items addObject:item];
    }
    if (items.count == 0) {
        // Never leave a dead control: hand the row back to the system menu.
        sender.menu = menu;
        sender.showsMenuAsPrimaryAction = YES;
        return;
    }

    [SPKToggleMenu presentWithChoices:items fromView:sender inViewController:self onDismiss:nil];
}

- (void)menuChanged:(UICommand *)command {
    NSDictionary *properties = command.propertyList;

    NSString *defaultsKey = properties[@"defaultsKey"];
    NSString *writeKey = SPKEffectivePreferenceKey(defaultsKey);
    [[NSUserDefaults standardUserDefaults] setValue:properties[@"value"] forKey:writeKey];
    // Flush immediately: a requiresRestart change may kill the app before the
    // automatic NSUserDefaults sync, losing the just-written value.
    [[NSUserDefaults standardUserDefaults] synchronize];
    if ([defaultsKey containsString:@"_action_btn"]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:SPKActionButtonConfigurationDidChangeNotification object:nil];
    }
    if ([defaultsKey hasPrefix:@"profile_follow_indicator"]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:SPKFollowIndicatorDidChangeNotification object:nil];
    }
    if ([defaultsKey isEqualToString:@"msgs_seen_button_position"]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:SPKMessageSeenButtonPositionDidChangeNotification object:nil];
    }
    if ([defaultsKey isEqualToString:kSPKPrefInterfaceScrollEdgeStyle]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:SPKScrollEdgeStyleDidChangeNotification object:nil];
    }

    SPKLog(@"General", @"Menu changed: %@ = %@", writeKey, properties[@"value"]);

    // A menu selection can gate another row's visibility (e.g. the Create Tab
    // toggle only shows for the Classic tab order). Only pay for a full rebuild
    // on pages that actually have hideable rows; otherwise keep the animated
    // single-cell refresh.
    BOOL hasHideableRows = NO;
    for (NSDictionary *section in self.originalSections) {
        for (id row in section[@"rows"]) {
            if ([row isKindOfClass:[SPKSetting class]] && ((SPKSetting *)row).hiddenProvider) {
                hasHideableRows = YES;
                break;
            }
        }
        if (hasHideableRows)
            break;
    }
    if (hasHideableRows && ![self isSearching]) {
        [self rebuildVisibleSections];
    } else {
        [self reloadCellForView:command.sender animated:YES];
    }

    if (properties[@"requiresRestart"]) {
        [SPKUtils showRestartConfirmation];
    }
}

// MARK: - Helper

- (void)replaceSections:(NSArray *)sections {
    self.originalSections = [sections copy] ?: @[];
    self.sections = SPKVisibleSectionsCopy(self.originalSections);
    self.tableView.dragInteractionEnabled = ![self isSearching] && [self pageAllowsReordering];
    [self.tableView reloadData];
}

// Re-evaluate every row's `hiddenProvider` against the full `originalSections`
// and reload. Call after a control changes state that another row's visibility
// depends on. No-op while searching (search maintains its own filtered set).
- (void)rebuildVisibleSections {
    if ([self isSearching])
        return;
    self.sections = SPKVisibleSectionsCopy(self.originalSections);
    [self.tableView reloadData];
}

// Like rebuildVisibleSections, but reloads every row *except* the one holding
// `sender`, so a toggled switch keeps its native slide animation while dependent
// rows refresh their enabled/greyed state. Falls back to a full reload if the
// visible row layout changed (a row appeared/disappeared), where a targeted
// reload would desync the table.
- (void)refreshDependentRowsAfterSwitchChange:(UISwitch *)sender {
    if ([self isSearching]) {
        [self.tableView reloadData];
        return;
    }

    UITableViewCell *cell = (UITableViewCell *)sender.superview;
    while (cell && ![cell isKindOfClass:[UITableViewCell class]])
        cell = (UITableViewCell *)cell.superview;
    NSIndexPath *senderPath = cell ? [self.tableView indexPathForCell:cell] : nil;

    NSMutableArray<NSNumber *> *previousCounts = [NSMutableArray array];
    for (NSDictionary *section in self.sections)
        [previousCounts addObject:@([section[@"rows"] count])];

    self.sections = SPKVisibleSectionsCopy(self.originalSections);

    NSMutableArray<NSNumber *> *newCounts = [NSMutableArray array];
    for (NSDictionary *section in self.sections)
        [newCounts addObject:@([section[@"rows"] count])];

    if (!senderPath || ![previousCounts isEqualToArray:newCounts]) {
        [self.tableView reloadData];
        return;
    }

    NSMutableArray<NSIndexPath *> *paths = [NSMutableArray array];
    for (NSInteger s = 0; s < (NSInteger)self.sections.count; s++) {
        NSInteger rowCount = [self.sections[s][@"rows"] count];
        for (NSInteger r = 0; r < rowCount; r++) {
            if (s == senderPath.section && r == senderPath.row)
                continue;
            [paths addObject:[NSIndexPath indexPathForRow:r inSection:s]];
        }
    }
    if (paths.count > 0)
        [self.tableView reloadRowsAtIndexPaths:paths withRowAnimation:UITableViewRowAnimationNone];
}

- (NSString *)formatString:(NSString *)template withValue:(double)value step:(double)step label:(NSString *)label singularLabel:(NSString *)singularLabel {
    // Singular or plural labels
    NSString *applicableLabel = fabs(value - 1.0) < 0.00001 ? singularLabel : label;

    // Force value to 0 to prevent it being -0
    if (fabs(value) < 0.00001) {
        value = 0.0;
    }

    // Get correct decimal value based on step value
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    formatter.numberStyle = NSNumberFormatterDecimalStyle;
    formatter.minimumFractionDigits = 0;
    formatter.maximumFractionDigits = step > 0.0 ? [SPKUtils decimalPlacesInDouble:step] : [SPKUtils decimalPlacesInDouble:value];

    NSString *stringValue = [formatter stringFromNumber:@(value)];

    return [NSString stringWithFormat:template, stringValue, applicableLabel];
}

- (void)reloadCellForView:(UIView *)view animated:(BOOL)animated {
    UITableViewCell *cell = (UITableViewCell *)view.superview;
    while (cell && ![cell isKindOfClass:[UITableViewCell class]]) {
        cell = (UITableViewCell *)cell.superview;
    }
    if (!cell)
        return;

    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    if (!indexPath)
        return;

    [self.tableView reloadRowsAtIndexPaths:@[ indexPath ]
                          withRowAnimation:animated ? UITableViewRowAnimationAutomatic : UITableViewRowAnimationNone];
}
- (void)reloadCellForView:(UIView *)view {
    [self reloadCellForView:view animated:NO];
}

- (BOOL)pageAllowsReordering {
    if ([self isSearching])
        return NO;
    for (NSDictionary *section in self.sections) {
        if ([section[@"allowsReordering"] boolValue]) {
            return YES;
        }
    }
    return NO;
}

- (void)loadAvatarForPK:(NSString *)pk urlString:(NSString *)urlString atIndexPath:(NSIndexPath *)indexPath forTableView:(UITableView *)tableView {
    if (pk.length == 0)
        return;
    // SPKAvatarCache self-heals: tries the stored URL, then re-resolves a fresh one
    // for numeric user PKs when it has expired. Completion is on the main queue.
    [[SPKAvatarCache shared] avatarForPK:pk
                               urlString:urlString
                              completion:^(UIImage *image) {
                                  if (!image)
                                      return;
                                  UIImage *circular = SPKSettingsSizedRemoteImage(image, YES);
                                  if (!circular)
                                      return;

                                  UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
                                  if (![cell.contentConfiguration isKindOfClass:UIListContentConfiguration.class])
                                      return;
                                  UIListContentConfiguration *config = (UIListContentConfiguration *)cell.contentConfiguration;
                                  config.image = circular;
                                  config.imageProperties.tintColor = nil;
                                  config.imageProperties.maximumSize = CGSizeMake(kSPKSettingsRemoteImageSize, kSPKSettingsRemoteImageSize);
                                  config.imageProperties.reservedLayoutSize = CGSizeMake(kSPKSettingsRemoteImageSize, kSPKSettingsRemoteImageSize);
                                  cell.contentConfiguration = config;
                              }];
}

- (void)loadImageFromURL:(NSURL *)url atIndexPath:(NSIndexPath *)indexPath forTableView:(UITableView *)tableView circular:(BOOL)circular {
    if (!url)
        return;

    NSString *cacheKey = [NSString stringWithFormat:@"%@|%@", url.absoluteString, circular ? @"circle" : @"square"];
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL:url
                                                             completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                                                                 if (!data || error)
                                                                     return;

                                                                 UIImage *image = SPKSettingsSizedRemoteImage([UIImage imageWithData:data], circular);
                                                                 if (!image)
                                                                     return;
                                                                 [SPKSettingsRemoteImageCache() setObject:image forKey:cacheKey];

                                                                 dispatch_async(dispatch_get_main_queue(), ^{
                                                                     UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
                                                                     if (!cell)
                                                                         return;

                                                                     UIListContentConfiguration *config = (UIListContentConfiguration *)cell.contentConfiguration;
                                                                     config.image = image;
                                                                     config.imageProperties.maximumSize = CGSizeMake(kSPKSettingsRemoteImageSize, kSPKSettingsRemoteImageSize);
                                                                     config.imageProperties.reservedLayoutSize = CGSizeMake(kSPKSettingsRemoteImageSize, kSPKSettingsRemoteImageSize);
                                                                     cell.contentConfiguration = config;
                                                                 });
                                                             }];

    [task resume];
}

@end
