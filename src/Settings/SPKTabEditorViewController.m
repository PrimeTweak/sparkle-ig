#import "SPKTabEditorViewController.h"

#import <objc/runtime.h>

#import "../AssetUtils.h"
#import "../Shared/Navigation/SPKTabConfiguration.h"
#import "../Shared/UI/SPKChipBar.h"
#import "../Shared/UI/SPKDialog.h"
#import "../Shared/UI/SPKMediaChrome.h"
#import "SPKSettingsHelpSheetViewController.h"
#import "SPKToggleMenu.h"
#import "SPKTopicSettingsSupport.h"

static CGFloat const kSPKTabPreviewInset = 14.0;
static CGFloat const kSPKTabPreviewScreenHeight = 34.0;
static CGFloat const kSPKTabPreviewItemsHeight = 46.0;
static CGFloat const kSPKTabPreviewIndicatorHeight = 16.0;
static CGFloat const kSPKTabPreviewGlyphSize = 24.0;
static CGFloat const kSPKTabEditorCaptionInset = 16.0;
static CGFloat const kSPKTabEditorChipBarHeight = 50.0;
static CGFloat const kSPKTabEditorVisibilityGlyphSize = 22.0;

// Rows carry their tab or menu here, so taps and drops map back to the staged state.
static NSString *const kSPKTabEditorTabKey = @"spk_tabIdentifier";
static NSString *const kSPKTabEditorMenuKey = @"spk_tabEditorMenu";
static NSString *const kSPKTabEditorLaunchMenu = @"launch";
static NSString *const kSPKTabEditorSwipeMenu = @"swipe";
static const void *kSPKTabEditorMenuButtonRowKey = &kSPKTabEditorMenuButtonRowKey;

NSString *SPKTabEditorLayoutSummary(void) {
    NSString *layout = SPKNormalizedTabLayout([SPKUtils getStringPref:SPKPrefTabLayout]);
    if ([layout isEqualToString:SPKTabLayoutCustom])
        return @"Custom";
    if ([layout isEqualToString:SPKTabLayoutClassic])
        return @"Classic";
    return @"Default";
}

static NSString *SPKTabEditorSwipeTitle(NSString *mode) {
    if ([mode isEqualToString:@"enabled"])
        return @"On";
    if ([mode isEqualToString:@"disabled"])
        return @"Off";
    return @"Default";
}

static UIColor *SPKTabEditorStrokeColor(void) {
    return [SPKUtils SPKColor_InstagramSeparator];
}

#pragma mark - Preview

// A still miniature of the bar being staged, with the tab it opens on marked.
@interface SPKTabEditorPreviewView : UIView
- (void)configureWithIcons:(NSArray<NSString *> *)icons selectedIndex:(NSUInteger)selectedIndex showsHeaderLink:(BOOL)showsHeaderLink;
@end

@implementation SPKTabEditorPreviewView {
    UIView *_card;
    UIView *_headerLink;
    UIStackView *_itemStack;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self)
        return nil;

    _card = [UIView new];
    _card.translatesAutoresizingMaskIntoConstraints = NO;
    _card.backgroundColor = [SPKUtils SPKColor_InstagramSecondaryBackground];
    _card.layer.cornerRadius = 12.0;
    _card.layer.cornerCurve = kCACornerCurveContinuous;
    _card.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    _card.layer.borderColor = SPKTabEditorStrokeColor().CGColor;
    _card.clipsToBounds = YES;
    [self addSubview:_card];

    // Classic keeps Messages in the feed header, drawn here above the bar.
    _headerLink = [UIView new];
    _headerLink.translatesAutoresizingMaskIntoConstraints = NO;
    [_card addSubview:_headerLink];

    UIView *wordmark = [UIView new];
    wordmark.translatesAutoresizingMaskIntoConstraints = NO;
    wordmark.backgroundColor = [[SPKUtils SPKColor_InstagramSecondaryText] colorWithAlphaComponent:0.3];
    wordmark.layer.cornerRadius = 4.0;
    [_headerLink addSubview:wordmark];

    UIImageView *messages = [[UIImageView alloc] initWithImage:[SPKAssetUtils instagramIconNamed:SPKTabIconName(SPKTabIdentifierDirect)
                                                                                       pointSize:20.0
                                                                                   renderingMode:UIImageRenderingModeAlwaysTemplate]];
    messages.translatesAutoresizingMaskIntoConstraints = NO;
    messages.contentMode = UIViewContentModeScaleAspectFit;
    messages.tintColor = [SPKUtils SPKColor_InstagramPrimaryText];
    [_headerLink addSubview:messages];

    UIView *bar = [UIView new];
    bar.translatesAutoresizingMaskIntoConstraints = NO;
    bar.backgroundColor = [SPKUtils SPKColor_InstagramBackground];
    [_card addSubview:bar];

    UIView *rule = [UIView new];
    rule.translatesAutoresizingMaskIntoConstraints = NO;
    rule.backgroundColor = SPKTabEditorStrokeColor();
    [bar addSubview:rule];

    _itemStack = [UIStackView new];
    _itemStack.translatesAutoresizingMaskIntoConstraints = NO;
    _itemStack.axis = UILayoutConstraintAxisHorizontal;
    _itemStack.distribution = UIStackViewDistributionFillEqually;
    _itemStack.alignment = UIStackViewAlignmentFill;
    [bar addSubview:_itemStack];

    UIView *homeIndicator = [UIView new];
    homeIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    homeIndicator.backgroundColor = [SPKUtils SPKColor_InstagramPrimaryText];
    homeIndicator.layer.cornerRadius = 2.5;
    [bar addSubview:homeIndicator];

    CGFloat hairline = 1.0 / UIScreen.mainScreen.scale;
    [NSLayoutConstraint activateConstraints:@[
        [_card.topAnchor constraintEqualToAnchor:self.topAnchor],
        [_card.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
        [_card.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:kSPKTabPreviewInset],
        [_card.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-kSPKTabPreviewInset],

        [_headerLink.topAnchor constraintEqualToAnchor:_card.topAnchor],
        [_headerLink.bottomAnchor constraintEqualToAnchor:bar.topAnchor],
        [_headerLink.leadingAnchor constraintEqualToAnchor:_card.leadingAnchor constant:14.0],
        [_headerLink.trailingAnchor constraintEqualToAnchor:_card.trailingAnchor constant:-14.0],
        [wordmark.leadingAnchor constraintEqualToAnchor:_headerLink.leadingAnchor],
        [wordmark.centerYAnchor constraintEqualToAnchor:_headerLink.centerYAnchor],
        [wordmark.widthAnchor constraintEqualToConstant:52.0],
        [wordmark.heightAnchor constraintEqualToConstant:8.0],
        [messages.trailingAnchor constraintEqualToAnchor:_headerLink.trailingAnchor],
        [messages.centerYAnchor constraintEqualToAnchor:_headerLink.centerYAnchor],
        [messages.widthAnchor constraintEqualToConstant:20.0],
        [messages.heightAnchor constraintEqualToConstant:20.0],

        [bar.leadingAnchor constraintEqualToAnchor:_card.leadingAnchor],
        [bar.trailingAnchor constraintEqualToAnchor:_card.trailingAnchor],
        [bar.bottomAnchor constraintEqualToAnchor:_card.bottomAnchor],
        [bar.heightAnchor constraintEqualToConstant:kSPKTabPreviewItemsHeight + kSPKTabPreviewIndicatorHeight],
        [rule.topAnchor constraintEqualToAnchor:bar.topAnchor],
        [rule.leadingAnchor constraintEqualToAnchor:bar.leadingAnchor],
        [rule.trailingAnchor constraintEqualToAnchor:bar.trailingAnchor],
        [rule.heightAnchor constraintEqualToConstant:hairline],

        [_itemStack.topAnchor constraintEqualToAnchor:bar.topAnchor],
        [_itemStack.leadingAnchor constraintEqualToAnchor:bar.leadingAnchor constant:8.0],
        [_itemStack.trailingAnchor constraintEqualToAnchor:bar.trailingAnchor constant:-8.0],
        [_itemStack.heightAnchor constraintEqualToConstant:kSPKTabPreviewItemsHeight],

        [homeIndicator.centerXAnchor constraintEqualToAnchor:bar.centerXAnchor],
        [homeIndicator.bottomAnchor constraintEqualToAnchor:bar.bottomAnchor constant:-7.0],
        [homeIndicator.widthAnchor constraintEqualToConstant:96.0],
        [homeIndicator.heightAnchor constraintEqualToConstant:5.0],
    ]];
    return self;
}

// Layer colors do not follow the appearance on their own.
- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    _card.layer.borderColor = [SPKTabEditorStrokeColor() resolvedColorWithTraitCollection:self.traitCollection].CGColor;
}

- (UIView *)itemViewWithIcon:(NSString *)iconName selected:(BOOL)selected {
    UIView *item = [UIView new];

    UIImageView *glyph = [[UIImageView alloc] initWithImage:[SPKAssetUtils instagramIconNamed:iconName
                                                                                     pointSize:kSPKTabPreviewGlyphSize
                                                                                 renderingMode:UIImageRenderingModeAlwaysTemplate]];
    glyph.translatesAutoresizingMaskIntoConstraints = NO;
    glyph.contentMode = UIViewContentModeScaleAspectFit;
    glyph.tintColor = selected ? [SPKUtils SPKColor_InstagramPrimaryText] : [SPKUtils SPKColor_InstagramTertiaryText];
    [item addSubview:glyph];

    UIView *dot = [UIView new];
    dot.translatesAutoresizingMaskIntoConstraints = NO;
    dot.backgroundColor = [SPKUtils SPKColor_InstagramBlue];
    dot.layer.cornerRadius = 2.5;
    dot.hidden = !selected;
    [item addSubview:dot];

    [NSLayoutConstraint activateConstraints:@[
        [glyph.centerXAnchor constraintEqualToAnchor:item.centerXAnchor],
        [glyph.centerYAnchor constraintEqualToAnchor:item.centerYAnchor constant:-3.0],
        [glyph.widthAnchor constraintEqualToConstant:kSPKTabPreviewGlyphSize],
        [glyph.heightAnchor constraintEqualToConstant:kSPKTabPreviewGlyphSize],
        [dot.centerXAnchor constraintEqualToAnchor:item.centerXAnchor],
        [dot.topAnchor constraintEqualToAnchor:glyph.bottomAnchor constant:4.0],
        [dot.widthAnchor constraintEqualToConstant:5.0],
        [dot.heightAnchor constraintEqualToConstant:5.0],
    ]];
    return item;
}

- (void)configureWithIcons:(NSArray<NSString *> *)icons selectedIndex:(NSUInteger)selectedIndex showsHeaderLink:(BOOL)showsHeaderLink {
    _headerLink.hidden = !showsHeaderLink;
    for (UIView *view in _itemStack.arrangedSubviews) {
        [_itemStack removeArrangedSubview:view];
        [view removeFromSuperview];
    }
    [icons enumerateObjectsUsingBlock:^(NSString *icon, NSUInteger index, __unused BOOL *stop) {
        [self->_itemStack addArrangedSubview:[self itemViewWithIcon:icon selected:index == selectedIndex]];
    }];
}

@end

#pragma mark - Editor

@interface SPKTabEditorViewController () <SPKChipBarDelegate>
@property (nonatomic, strong) UIView *headerContainer;
@property (nonatomic, strong) SPKChipBar *layoutChipBar;
@property (nonatomic, strong) SPKTabEditorPreviewView *previewView;
@property (nonatomic, strong) UILabel *captionLabel;

@property (nonatomic, copy) NSString *layoutMode;
@property (nonatomic, strong) NSMutableArray<NSString *> *order;
@property (nonatomic, strong) NSMutableSet<NSString *> *hidden;
@property (nonatomic, copy) NSString *launchTab;
@property (nonatomic, copy) NSString *swipeMode;
@property (nonatomic, copy) NSString *savedCarrier;
@property (nonatomic) BOOL hidesTabBarWhenSingle;
@property (nonatomic, copy) NSDictionary *persistedSnapshot;
@end

@implementation SPKTabEditorViewController

- (instancetype)init {
    self = [super initWithTitle:@"Tab editor" sections:@[] reduceMargin:NO];
    if (self) {
        [self spk_loadPersistedValues];
        [self replaceSections:[self spk_sections]];
    }
    return self;
}

#pragma mark Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    // Too few rows to need a search field.
    self.navigationItem.searchController = nil;
    [self spk_buildHeader];
    [self spk_refreshHeader];
}

- (void)viewWillAppear:(BOOL)animated {
    // Staged edits survive leaving the page, unless the stored setup changed in
    // the meantime (an import, for one).
    if (self.isMovingToParentViewController &&
        (![self spk_isDirty] || ![self.persistedSnapshot isEqual:[self spk_storedSnapshot]])) {
        [self spk_loadPersistedValues];
        [self replaceSections:[self spk_sections]];
        [self spk_refreshHeader];
    }
    [super viewWillAppear:animated];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self spk_layoutHeader];
}

- (void)setupNavigationItems {
    [super setupNavigationItems];
    if (![self spk_isDirty])
        return;
    UIBarButtonItem *apply = SPKMediaChromeTopBarButtonItemWithStyle(@"check", self, @selector(spk_applyTapped),
                                                                    UIBarButtonItemStyleDone,
                                                                    [SPKUtils SPKColor_InstagramBlue],
                                                                    @"Apply and restart");
    SPKMediaChromeSetTrailingTopBarItems(self.navigationItem, @[ apply ]);
}

#pragma mark Header

- (void)spk_buildHeader {
    self.headerContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, CGRectGetWidth(self.view.bounds), 0)];

    self.layoutChipBar = [[SPKChipBar alloc] init];
    self.layoutChipBar.delegate = self;
    self.layoutChipBar.distributesToFit = YES;
    [self.layoutChipBar setItems:@[ @"Default", @"Custom", @"Classic" ] symbols:nil];
    [self.headerContainer addSubview:self.layoutChipBar];

    self.previewView = [[SPKTabEditorPreviewView alloc] initWithFrame:CGRectZero];
    [self.headerContainer addSubview:self.previewView];

    self.captionLabel = [UILabel new];
    self.captionLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
    self.captionLabel.adjustsFontForContentSizeCategory = YES;
    self.captionLabel.textColor = [SPKUtils SPKColor_InstagramSecondaryText];
    self.captionLabel.numberOfLines = 0;
    [self.headerContainer addSubview:self.captionLabel];

    self.tableView.tableHeaderView = self.headerContainer;
}

// Frame-based: a table header view is sized by its frame.
- (void)spk_layoutHeader {
    CGFloat width = CGRectGetWidth(self.tableView.bounds);
    if (!self.headerContainer || width <= 0.0)
        return;

    CGFloat y = 4.0;
    self.layoutChipBar.frame = CGRectMake(0.0, y, width, kSPKTabEditorChipBarHeight);
    y += kSPKTabEditorChipBarHeight + 4.0;

    CGFloat previewHeight = kSPKTabPreviewScreenHeight + kSPKTabPreviewItemsHeight + kSPKTabPreviewIndicatorHeight;
    self.previewView.frame = CGRectMake(0.0, y, width, previewHeight);
    y += previewHeight + 8.0;

    CGFloat captionWidth = width - 2.0 * kSPKTabEditorCaptionInset;
    CGFloat captionHeight = ceil([self.captionLabel sizeThatFits:CGSizeMake(captionWidth, CGFLOAT_MAX)].height);
    self.captionLabel.frame = CGRectMake(kSPKTabEditorCaptionInset, y, captionWidth, captionHeight);
    y += captionHeight + 4.0;

    CGRect frame = CGRectMake(0.0, 0.0, width, y);
    if (!CGRectEqualToRect(self.headerContainer.frame, frame)) {
        self.headerContainer.frame = frame;
        self.tableView.tableHeaderView = self.headerContainer;
    }
}

- (void)spk_refreshHeader {
    if (!self.headerContainer)
        return;
    self.layoutChipBar.selectedIndex = [self spk_usesCustomLayout] ? 1 : ([self spk_usesClassicLayout] ? 2 : 0);

    NSMutableArray<NSString *> *shown = [NSMutableArray array];
    for (NSString *identifier in [self spk_rowIdentifiers]) {
        if (![self spk_isHidden:identifier])
            [shown addObject:identifier];
    }
    // Without a launch tab, the first destination is where the app opens.
    NSString *highlighted = SPKTabIdentifierForLaunchPreference(self.launchTab);
    if (!highlighted || ![shown containsObject:highlighted]) {
        highlighted = nil;
        for (NSString *identifier in shown) {
            if (![identifier isEqualToString:SPKTabIdentifierCreate]) {
                highlighted = identifier;
                break;
            }
        }
    }
    NSMutableArray<NSString *> *icons = [NSMutableArray arrayWithCapacity:shown.count];
    for (NSString *identifier in shown)
        [icons addObject:SPKTabIconName(identifier)];
    [self.previewView configureWithIcons:icons
                           selectedIndex:highlighted ? [shown indexOfObject:highlighted] : NSNotFound
                         showsHeaderLink:[self spk_usesClassicLayout]];

    if ([self spk_usesCustomLayout])
        self.captionLabel.text = @"Your own order. The only layout that can hold Saved.";
    else if ([self spk_usesClassicLayout])
        self.captionLabel.text = @"Instagram's old layout: Messages in the feed header, Create as a tab.";
    else
        self.captionLabel.text = @"Instagram decides the order. You can still hide tabs.";
    [self.view setNeedsLayout];
}

- (void)chipBar:(SPKChipBar *)bar didSelectIndex:(NSInteger)index {
    NSString *layout = index == 1 ? SPKTabLayoutCustom : (index == 2 ? SPKTabLayoutClassic : SPKTabLayoutDefault);
    if ([layout isEqualToString:self.layoutMode])
        return;
    self.layoutMode = layout;
    [self spk_normalize];
    [self spk_reload];
}

#pragma mark Staged state

- (BOOL)spk_usesCustomLayout {
    return [self.layoutMode isEqualToString:SPKTabLayoutCustom];
}

- (BOOL)spk_usesClassicLayout {
    return [self.layoutMode isEqualToString:SPKTabLayoutClassic];
}

// Not -getBoolPref:, whose disable-all overlay reports values the user never set.
static BOOL SPKTabEditorStoredBool(NSString *key) {
    id value = SPKPreferenceObjectForKey(key);
    return [value respondsToSelector:@selector(boolValue)] && [value boolValue];
}

static NSString *SPKTabEditorStoredString(NSString *key) {
    id value = SPKPreferenceObjectForKey(key);
    return [value isKindOfClass:[NSString class]] && [value length] > 0 ? value : @"default";
}

static NSDictionary *SPKTabEditorSnapshot(NSString *layout, NSArray *order, NSSet *hidden, NSString *launch,
                                          NSString *swipe, NSString *saved, BOOL hidesBar) {
    return @{
        @"layout" : layout ?: SPKTabLayoutDefault,
        @"order" : order ?: @[],
        @"hidden" : [hidden.allObjects sortedArrayUsingSelector:@selector(compare:)] ?: @[],
        @"launch" : launch ?: @"default",
        @"swipe" : swipe ?: @"default",
        @"saved" : saved ?: SPKTabSavedCarrierNone,
        @"hidesBar" : @(hidesBar),
    };
}

- (NSDictionary *)spk_snapshot {
    return SPKTabEditorSnapshot(self.layoutMode, [self.order copy], self.hidden, self.launchTab, self.swipeMode,
                                self.savedCarrier, self.hidesTabBarWhenSingle);
}

- (NSDictionary *)spk_storedSnapshot {
    NSMutableSet<NSString *> *hidden = [NSMutableSet set];
    for (NSString *identifier in SPKTabEditableIdentifiers()) {
        if (SPKTabEditorStoredBool(SPKTabHidePreferenceKey(identifier)))
            [hidden addObject:identifier];
    }
    return SPKTabEditorSnapshot(SPKNormalizedTabLayout(SPKPreferenceObjectForKey(SPKPrefTabLayout)),
                                SPKNormalizeTabOrder(SPKPreferenceObjectForKey(SPKPrefCustomTabOrder)),
                                hidden,
                                SPKTabEditorStoredString(SPKPrefLaunchTab),
                                SPKTabEditorStoredString(SPKPrefSwipeTabs),
                                SPKNormalizedSavedCarrier(SPKPreferenceObjectForKey(SPKPrefSavedTabCarrier)),
                                SPKTabEditorStoredBool(SPKPrefHideTabBarWhenSingle));
}

- (void)spk_loadPersistedValues {
    NSDictionary *stored = [self spk_storedSnapshot];
    self.layoutMode = stored[@"layout"];
    self.order = [stored[@"order"] mutableCopy];
    self.hidden = [NSMutableSet setWithArray:stored[@"hidden"]];
    self.launchTab = stored[@"launch"];
    self.swipeMode = stored[@"swipe"];
    self.savedCarrier = stored[@"saved"];
    self.hidesTabBarWhenSingle = [stored[@"hidesBar"] boolValue];
    self.persistedSnapshot = stored;
    // A setup left inconsistent elsewhere is repaired here, which leaves the page
    // dirty on purpose: applying stores the repaired values.
    [self spk_normalize];
}

- (BOOL)spk_isDirty {
    return ![[self spk_snapshot] isEqual:self.persistedSnapshot];
}

// The rows of the Tabs section, in the order they are drawn.
- (NSArray<NSString *> *)spk_rowIdentifiers {
    if ([self spk_usesCustomLayout])
        return self.order;
    if ([self spk_usesClassicLayout])
        return @[ SPKTabIdentifierFeed, SPKTabIdentifierSearch, SPKTabIdentifierCreate, SPKTabIdentifierClips, SPKTabIdentifierProfile ];
    return @[ SPKTabIdentifierFeed, SPKTabIdentifierSearch, SPKTabIdentifierClips, SPKTabIdentifierDirect, SPKTabIdentifierProfile ];
}

- (BOOL)spk_savedEnabled {
    return ![self.savedCarrier isEqualToString:SPKTabSavedCarrierNone];
}

- (BOOL)spk_isHidden:(NSString *)identifier {
    if ([identifier isEqualToString:SPKTabIdentifierSaved])
        return ![self spk_savedEnabled];
    return [self.hidden containsObject:identifier];
}

// Native destinations the bar would still show; Saved is counted apart.
- (NSUInteger)spk_visibleDestinationCount {
    NSUInteger count = 0;
    for (NSString *identifier in SPKCanonicalTabIdentifiers()) {
        if (SPKTabOccupiesBarSlot(identifier, self.layoutMode) && ![self.hidden containsObject:identifier])
            count++;
    }
    return count;
}

- (NSString *)spk_availableSavedCarrier {
    for (NSString *identifier in SPKTabSavedCarrierPreferenceForLayout(self.layoutMode)) {
        if ([self.hidden containsObject:identifier])
            return identifier;
    }
    return nil;
}

- (NSArray<NSString *> *)spk_launchCandidates {
    NSMutableArray<NSString *> *candidates = [NSMutableArray array];
    for (NSString *identifier in [self spk_rowIdentifiers]) {
        if ([identifier isEqualToString:SPKTabIdentifierCreate] || [identifier isEqualToString:SPKTabIdentifierSaved])
            continue;
        if (![self.hidden containsObject:identifier])
            [candidates addObject:identifier];
    }
    return candidates;
}

- (void)spk_normalize {
    // Saved only borrows a hidden slot of the Custom layout.
    if ([self spk_savedEnabled]) {
        BOOL keepsSlot = [self spk_usesCustomLayout] && [self.hidden containsObject:self.savedCarrier];
        if (!keepsSlot)
            self.savedCarrier = ([self spk_usesCustomLayout] ? [self spk_availableSavedCarrier] : nil) ?: SPKTabSavedCarrierNone;
    }
    // Instagram falls back to Feed when no destination is left.
    if ([self spk_visibleDestinationCount] == 0 && ![self spk_savedEnabled])
        [self.hidden removeObject:SPKTabIdentifierFeed];
    NSString *launch = SPKTabIdentifierForLaunchPreference(self.launchTab);
    if (launch && ![[self spk_launchCandidates] containsObject:launch])
        self.launchTab = @"default";
}

// The last destination cannot be hidden, and Saved cannot show without a hidden
// slot to borrow.
- (BOOL)spk_isLocked:(NSString *)identifier {
    if ([identifier isEqualToString:SPKTabIdentifierSaved])
        return [self spk_savedEnabled] ? [self spk_visibleDestinationCount] == 0 : ![self spk_availableSavedCarrier];
    if ([identifier isEqualToString:SPKTabIdentifierCreate] || [self.hidden containsObject:identifier])
        return NO;
    return [self spk_visibleDestinationCount] <= 1 && ![self spk_savedEnabled];
}

- (NSString *)spk_statusForTab:(NSString *)identifier {
    if ([identifier isEqualToString:SPKTabIdentifierSaved]) {
        if (![self spk_savedEnabled])
            return [self spk_availableSavedCarrier] ? nil : @"Hide a tab first";
        return [NSString stringWithFormat:@"Replaces %@", SPKTabTitle(self.savedCarrier)];
    }
    if ([self.hidden containsObject:identifier])
        return nil;
    if ([identifier isEqualToString:SPKTabIdentifierCreate])
        return @"Opens the camera";
    if ([identifier isEqualToString:SPKTabIdentifierForLaunchPreference(self.launchTab)])
        return @"Opens at launch";
    return nil;
}

- (NSString *)spk_singleVisibleTab {
    return SPKSingleVisibleTabIdentifier(self.layoutMode, self.hidden, self.savedCarrier);
}

#pragma mark Sections

- (NSArray *)spk_sections {
    NSMutableArray *tabRows = [NSMutableArray array];
    for (NSString *identifier in [self spk_rowIdentifiers])
        [tabRows addObject:[self spk_rowForTab:identifier]];
    NSMutableDictionary *tabs = [SPKTopicSection(@"Tabs", tabRows, nil) mutableCopy];
    tabs[SPKTopicSectionHelpKey] = @"Tap a tab to show or hide it. In Custom, drag the handles to reorder; Saved takes the place of a hidden tab.";
    tabs[@"allowsReordering"] = @([self spk_usesCustomLayout]);

    NSMutableArray *sections = [NSMutableArray arrayWithObjects:
                                                   tabs,
                                                   SPKTopicSection(@"Behavior", @[ [self spk_launchRow], [self spk_swipeRow] ], nil),
                                                   nil];
    if ([[self spk_singleVisibleTab] isEqualToString:SPKTabIdentifierDirect])
        [sections addObject:SPKTopicSection(@"Single tab", @[ [self spk_hideTabBarRow] ], nil)];

    __weak typeof(self) weakSelf = self;
    NSMutableArray *actions = [NSMutableArray array];
    if ([self spk_isDirty]) {
        SPKSetting *discard = [SPKSetting buttonCellWithTitle:@"Discard changes"
                                                     subtitle:nil
                                                         icon:nil
                                                       action:^{
                                                           [weakSelf spk_discardTapped];
                                                       }];
        discard.tintColor = [SPKUtils SPKColor_InstagramDestructive];
        discard.userInfo = @{@"hidesDisclosure" : @YES};
        [actions addObject:discard];
    }
    SPKSetting *reset = [SPKSetting buttonCellWithTitle:@"Reset to Instagram default"
                                               subtitle:nil
                                                   icon:nil
                                                 action:^{
                                                     [weakSelf spk_stageDefaults];
                                                 }];
    reset.tintColor = [SPKUtils SPKColor_InstagramBlue];
    reset.userInfo = @{@"hidesDisclosure" : @YES};
    [actions addObject:reset];
    [sections addObject:SPKTopicSection(@"", actions, nil)];
    return sections;
}

- (SPKSetting *)spk_rowForTab:(NSString *)identifier {
    __weak typeof(self) weakSelf = self;
    SPKSetting *row = [SPKSetting buttonCellWithTitle:SPKTabTitle(identifier)
                                             subtitle:nil
                                                 icon:SPKSettingsIcon(SPKTabIconName(identifier))
                                               action:^{
                                                   [weakSelf spk_toggleTab:identifier];
                                               }];
    NSMutableDictionary *info = [@{kSPKTabEditorTabKey : identifier, @"hidesDisclosure" : @YES} mutableCopy];
    NSString *status = [self spk_statusForTab:identifier];
    if (status.length > 0)
        info[@"accessoryText"] = status;
    if ([self spk_usesCustomLayout])
        info[@"showsReorderGrabber"] = @YES;
    row.userInfo = info;
    if ([self spk_isHidden:identifier]) {
        row.tintColor = [SPKUtils SPKColor_InstagramTertiaryText];
        row.iconTintColor = [SPKUtils SPKColor_InstagramTertiaryText];
    }
    return row;
}

- (SPKSetting *)spk_launchRow {
    NSString *launch = SPKTabIdentifierForLaunchPreference(self.launchTab);
    SPKSetting *row = [SPKSetting menuCellWithTitle:@"Launch tab"
                                               icon:SPKSettingsIcon(launch ? SPKTabIconName(launch) : @"home")
                                               menu:[UIMenu menuWithChildren:@[]]];
    row.userInfo = @{@"accessoryText" : launch ? SPKTabTitle(launch) : @"Default", kSPKTabEditorMenuKey : kSPKTabEditorLaunchMenu};
    return row;
}

- (SPKSetting *)spk_swipeRow {
    SPKSetting *row = [SPKSetting menuCellWithTitle:@"Swipe between tabs"
                                               icon:SPKSettingsIcon(@"left_right")
                                               menu:[UIMenu menuWithChildren:@[]]];
    row.userInfo = @{@"accessoryText" : SPKTabEditorSwipeTitle(self.swipeMode), kSPKTabEditorMenuKey : kSPKTabEditorSwipeMenu};
    return row;
}

- (SPKSetting *)spk_hideTabBarRow {
    SPKSetting *row = [SPKSetting switchCellWithTitle:@"Hide tab bar" icon:SPKSettingsIcon(@"eye_off") defaultsKey:@""];
    row.helpText = @"Only Messages is left, so the tab bar can go. Sparkle stays one tap away from the \u2726 button in the Messages header.";
    __weak typeof(self) weakSelf = self;
    row.switchValueProvider = ^BOOL {
        return weakSelf.hidesTabBarWhenSingle;
    };
    row.switchChangeHandler = ^(BOOL isOn) {
        weakSelf.hidesTabBarWhenSingle = isOn;
        // Rebuilt once the switch has finished sliding: a reload swaps in a still one.
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [weakSelf spk_reload];
        });
    };
    return row;
}

- (void)spk_reload {
    [self replaceSections:[self spk_sections]];
    [self spk_refreshHeader];
    [self setupNavigationItems];
}

#pragma mark Table

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [super tableView:tableView cellForRowAtIndexPath:indexPath];
    SPKSetting *row = self.sections[indexPath.section][@"rows"][indexPath.row];
    NSString *identifier = row.userInfo[kSPKTabEditorTabKey];
    if (identifier) {
        BOOL hidden = [self spk_isHidden:identifier];
        BOOL muted = hidden || [self spk_isLocked:identifier];
        UIImage *glyph = [SPKAssetUtils instagramIconNamed:(hidden ? @"circle" : @"circle_check_filled")
                                                 pointSize:kSPKTabEditorVisibilityGlyphSize
                                             renderingMode:UIImageRenderingModeAlwaysTemplate];
        UIImageView *visibility = [[UIImageView alloc] initWithImage:glyph];
        visibility.tintColor = muted ? [SPKUtils SPKColor_InstagramTertiaryText] : [SPKUtils SPKColor_InstagramBlue];
        cell.accessoryView = visibility;
        cell.accessibilityValue = hidden ? @"Hidden" : @"Shown";
    } else if (row.userInfo[kSPKTabEditorMenuKey] && [cell.accessoryView isKindOfClass:[UIButton class]]) {
        // The picker writes nothing: the choice is staged like every other edit.
        UIButton *button = (UIButton *)cell.accessoryView;
        [button removeTarget:nil action:NULL forControlEvents:UIControlEventAllEvents];
        objc_setAssociatedObject(button, kSPKTabEditorMenuButtonRowKey, row, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [button addTarget:self action:@selector(spk_behaviorMenuTapped:) forControlEvents:UIControlEventTouchUpInside];
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath toIndexPath:(NSIndexPath *)destinationIndexPath {
    [super tableView:tableView moveRowAtIndexPath:sourceIndexPath toIndexPath:destinationIndexPath];
    NSMutableArray<NSString *> *order = [NSMutableArray array];
    for (SPKSetting *row in self.sections[sourceIndexPath.section][@"rows"]) {
        NSString *identifier = row.userInfo[kSPKTabEditorTabKey];
        if (identifier)
            [order addObject:identifier];
    }
    if (order.count == 0)
        return;
    self.order = [SPKNormalizeTabOrder(order) mutableCopy];
    // The table is mid-update here; the page is rebuilt once the drop has landed.
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        [weakSelf spk_reload];
    });
}

#pragma mark Actions

- (void)spk_toggleTab:(NSString *)identifier {
    if ([self spk_isLocked:identifier]) {
        [[UINotificationFeedbackGenerator new] notificationOccurred:UINotificationFeedbackTypeWarning];
        [self spk_shakeRowForTab:identifier];
        return;
    }
    if ([identifier isEqualToString:SPKTabIdentifierSaved])
        self.savedCarrier = [self spk_savedEnabled] ? SPKTabSavedCarrierNone : ([self spk_availableSavedCarrier] ?: SPKTabSavedCarrierNone);
    else if ([self.hidden containsObject:identifier])
        [self.hidden removeObject:identifier];
    else
        [self.hidden addObject:identifier];
    [[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight] impactOccurred];
    [self spk_normalize];
    [self spk_reload];
}

// Runs after the table reload that follows every row tap.
- (void)spk_shakeRowForTab:(NSString *)identifier {
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        typeof(self) strongSelf = weakSelf;
        for (NSIndexPath *indexPath in strongSelf.tableView.indexPathsForVisibleRows) {
            SPKSetting *row = strongSelf.sections[indexPath.section][@"rows"][indexPath.row];
            if (![row.userInfo[kSPKTabEditorTabKey] isEqual:identifier])
                continue;
            CAKeyframeAnimation *shake = [CAKeyframeAnimation animationWithKeyPath:@"transform.translation.x"];
            shake.values = @[ @0, @-8, @8, @-5, @5, @-2, @0 ];
            shake.duration = 0.35;
            [[strongSelf.tableView cellForRowAtIndexPath:indexPath].contentView.layer addAnimation:shake forKey:@"spk_shake"];
        }
    });
}

- (SPKToggleMenuItem *)spk_choiceWithTitle:(NSString *)title
                                       icon:(NSString *)icon
                                      value:(NSString *)value
                                    current:(NSString *)current
                                      apply:(void (^)(void))apply {
    SPKToggleMenuItem *item = [SPKToggleMenuItem itemWithTitle:title iconName:icon defaultsKey:@""];
    item.pickValue = value;
    BOOL selected = [current isEqualToString:value];
    item.selectedProvider = ^BOOL {
        return selected;
    };
    __weak typeof(self) weakSelf = self;
    item.pickHandler = ^{
        apply();
        [weakSelf spk_normalize];
        [weakSelf spk_reload];
    };
    return item;
}

- (void)spk_behaviorMenuTapped:(UIButton *)sender {
    SPKSetting *row = objc_getAssociatedObject(sender, kSPKTabEditorMenuButtonRowKey);
    __weak typeof(self) weakSelf = self;
    NSMutableArray<SPKToggleMenuItem *> *items = [NSMutableArray array];
    if ([row.userInfo[kSPKTabEditorMenuKey] isEqualToString:kSPKTabEditorLaunchMenu]) {
        [items addObject:[self spk_choiceWithTitle:@"Default"
                                              icon:@""
                                             value:@"default"
                                           current:self.launchTab
                                             apply:^{
                                                 weakSelf.launchTab = @"default";
                                             }]];
        for (NSString *identifier in [self spk_launchCandidates]) {
            NSString *value = SPKTabLaunchPreferenceValue(identifier);
            [items addObject:[self spk_choiceWithTitle:SPKTabTitle(identifier)
                                                  icon:SPKTabIconName(identifier)
                                                 value:value
                                               current:self.launchTab
                                                 apply:^{
                                                     weakSelf.launchTab = value;
                                                 }]];
        }
    } else {
        for (NSString *mode in @[ @"default", @"enabled", @"disabled" ]) {
            [items addObject:[self spk_choiceWithTitle:SPKTabEditorSwipeTitle(mode)
                                                  icon:@""
                                                 value:mode
                                               current:self.swipeMode
                                                 apply:^{
                                                     weakSelf.swipeMode = mode;
                                                 }]];
        }
    }
    [SPKToggleMenu presentWithChoices:items fromView:sender inViewController:self onDismiss:nil];
}

- (void)spk_stageDefaults {
    self.layoutMode = SPKTabLayoutDefault;
    self.order = [SPKNormalizeTabOrder(nil) mutableCopy];
    [self.hidden removeAllObjects];
    self.launchTab = @"default";
    self.swipeMode = @"default";
    self.savedCarrier = SPKTabSavedCarrierNone;
    self.hidesTabBarWhenSingle = NO;
    [self spk_reload];
}

- (void)spk_discardTapped {
    __weak typeof(self) weakSelf = self;
    [SPKDialog presentFromController:self
                               title:@"Discard changes"
                             message:@"The tab bar goes back to how it was last applied."
                             actions:@[
                                 [SPKDialogAction actionWithTitle:@"Cancel" style:SPKDialogActionStyleCancel handler:nil],
                                 [SPKDialogAction actionWithTitle:@"Discard"
                                                            style:SPKDialogActionStyleDestructive
                                                          handler:^{
                                                              [weakSelf spk_loadPersistedValues];
                                                              [weakSelf spk_reload];
                                                          }],
                             ]];
}

- (void)spk_applyTapped {
    SPKPreferenceSetObject(self.layoutMode, SPKPrefTabLayout);
    SPKPreferenceSetObject(SPKNormalizeTabOrder(self.order), SPKPrefCustomTabOrder);
    for (NSString *identifier in SPKTabEditableIdentifiers())
        SPKPreferenceSetObject(@([self.hidden containsObject:identifier]), SPKTabHidePreferenceKey(identifier));
    SPKPreferenceSetObject(self.launchTab, SPKPrefLaunchTab);
    SPKPreferenceSetObject(self.swipeMode, SPKPrefSwipeTabs);
    SPKPreferenceSetObject(self.savedCarrier, SPKPrefSavedTabCarrier);
    SPKPreferenceSetObject(@(self.hidesTabBarWhenSingle), SPKPrefHideTabBarWhenSingle);
    // The restart prompt can end the process, so the values are flushed first.
    [NSUserDefaults.standardUserDefaults synchronize];

    self.persistedSnapshot = [self spk_snapshot];
    [self spk_reload];
    [SPKUtils showRestartConfirmation];
}

@end
