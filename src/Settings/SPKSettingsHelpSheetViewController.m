#import "SPKSettingsHelpSheetViewController.h"

#import "../Utils.h"

static CGFloat const kSPKHelpIconSize = 22.0;
static CGFloat const kSPKHelpIconGutter = 14.0;
static CGFloat const kSPKHelpEntrySpacing = 22.0;
static CGFloat const kSPKHelpHorizontalInset = 24.0;
static CGFloat const kSPKHelpTopPadding = 20.0;
static CGFloat const kSPKHelpBottomPadding = 32.0;
static CGFloat const kSPKHelpChromeHeight = 60.0;  // grabber + title bar
static CGFloat const kSPKHelpMinimumHeight = 180.0;

NSString *const SPKTopicSectionHelpKey = @"spk_sectionHelp";

NSArray<SPKSetting *> *SPKSettingsHelpRowsInSection(NSDictionary *section) {
    if (![section isKindOfClass:[NSDictionary class]])
        return @[];

    NSArray *rows = section[@"rows"];
    if (![rows isKindOfClass:[NSArray class]])
        return @[];

    NSMutableArray<SPKSetting *> *helpRows = [NSMutableArray array];
    NSString *sectionHelp = section[SPKTopicSectionHelpKey];
    if ([sectionHelp isKindOfClass:[NSString class]] && sectionHelp.length > 0) {
        SPKSetting *entry = [SPKSetting staticCellWithTitle:@"" subtitle:@"" icon:nil];
        entry.helpText = sectionHelp;
        [helpRows addObject:entry];
    }
    for (SPKSetting *row in rows) {
        if (![row isKindOfClass:[SPKSetting class]])
            continue;
        if (row.helpText.length == 0)
            continue;
        // A row removed from the table is removed from its own explanation too.
        // This is the whole point of hanging help off the row instead of listing
        // it separately in a footer.
        if (row.hiddenProvider && row.hiddenProvider())
            continue;
        [helpRows addObject:row];
    }
    return [helpRows copy];
}

@interface SPKSettingsHelpSheetViewController ()

@property (nonatomic, copy) NSString *sectionTitle;
@property (nonatomic, copy) NSArray<SPKSetting *> *rows;
@property (nonatomic, strong) UIStackView *entryStack;

- (CGFloat)spk_contentHeightForWidth:(CGFloat)width;

@end

@implementation SPKSettingsHelpSheetViewController

+ (void)presentForSectionTitle:(NSString *)sectionTitle
                          rows:(NSArray<SPKSetting *> *)rows
            fromViewController:(UIViewController *)presenter {
    if (rows.count == 0 || presenter == nil)
        return;

    SPKSettingsHelpSheetViewController *sheet = [[self alloc] init];
    sheet.sectionTitle = sectionTitle.length > 0 ? sectionTitle : @"About These Settings";
    sheet.rows = rows;

    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:sheet];
    nav.modalPresentationStyle = UIModalPresentationPageSheet;

    if (@available(iOS 15.0, *)) {
        UISheetPresentationController *presentation = nav.sheetPresentationController;
        presentation.prefersGrabberVisible = YES;
        presentation.preferredCornerRadius = 26.0;

        if (@available(iOS 16.0, *)) {
            // Size to the content rather than a fixed half screen: a two-entry
            // sheet shouldn't open as tall as an eight-entry one.
            __weak SPKSettingsHelpSheetViewController *weakSheet = sheet;
            __weak UINavigationController *weakNav = nav;
            UISheetPresentationControllerDetent *fitted =
                [UISheetPresentationControllerDetent customDetentWithIdentifier:@"spk.help.fitted"
                                                                       resolver:^CGFloat(id<UISheetPresentationControllerDetentResolutionContext> context) {
                                                                           SPKSettingsHelpSheetViewController *strongSheet = weakSheet;
                                                                           UINavigationController *strongNav = weakNav;
                                                                           if (!strongSheet || !strongNav)
                                                                               return context.maximumDetentValue * 0.5;

                                                                           CGFloat width = CGRectGetWidth(strongNav.view.bounds);
                                                                           CGFloat height = [strongSheet spk_contentHeightForWidth:width];
                                                                           return MIN(MAX(height, kSPKHelpMinimumHeight), context.maximumDetentValue);
                                                                       }];
            presentation.detents = @[ fitted, UISheetPresentationControllerDetent.largeDetent ];
        } else {
            presentation.detents = @[ UISheetPresentationControllerDetent.mediumDetent,
                                      UISheetPresentationControllerDetent.largeDetent ];
        }
    }

    [presenter presentViewController:nav animated:YES completion:nil];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [SPKUtils SPKColor_InstagramBackground];
    self.title = self.sectionTitle;
    self.navigationController.navigationBar.prefersLargeTitles = NO;

    UIBarButtonItem *close = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemClose
                                                                          target:self
                                                                          action:@selector(spk_closeTapped)];
    close.tintColor = [SPKUtils SPKColor_InstagramPrimaryText];
    self.navigationItem.rightBarButtonItem = close;

    UIScrollView *scrollView = [UIScrollView new];
    scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    scrollView.alwaysBounceVertical = YES;
    [self.view addSubview:scrollView];

    self.entryStack = [UIStackView new];
    self.entryStack.axis = UILayoutConstraintAxisVertical;
    self.entryStack.spacing = kSPKHelpEntrySpacing;
    self.entryStack.alignment = UIStackViewAlignmentFill;
    self.entryStack.translatesAutoresizingMaskIntoConstraints = NO;
    for (SPKSetting *row in self.rows) {
        [self.entryStack addArrangedSubview:[self spk_entryViewForRow:row]];
    }
    [scrollView addSubview:self.entryStack];

    [NSLayoutConstraint activateConstraints:@[
        [scrollView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [self.entryStack.topAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.topAnchor
                                                  constant:kSPKHelpTopPadding],
        [self.entryStack.bottomAnchor constraintEqualToAnchor:scrollView.contentLayoutGuide.bottomAnchor
                                                     constant:-kSPKHelpBottomPadding],
        [self.entryStack.leadingAnchor constraintEqualToAnchor:scrollView.frameLayoutGuide.leadingAnchor
                                                      constant:kSPKHelpHorizontalInset],
        [self.entryStack.trailingAnchor constraintEqualToAnchor:scrollView.frameLayoutGuide.trailingAnchor
                                                       constant:-kSPKHelpHorizontalInset]
    ]];
}

- (UIView *)spk_entryViewForRow:(SPKSetting *)row {
    UIView *container = [UIView new];
    container.translatesAutoresizingMaskIntoConstraints = NO;

    UIImage *icon = row.iconProvider ? row.iconProvider() : row.icon;
    // Section-wide help has neither icon nor title: its text spans the full width.
    if (!icon && row.title.length == 0) {
        UILabel *textLabel = [UILabel new];
        textLabel.translatesAutoresizingMaskIntoConstraints = NO;
        textLabel.text = row.helpText;
        textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
        textLabel.adjustsFontForContentSizeCategory = YES;
        textLabel.textColor = [SPKUtils SPKColor_InstagramSecondaryText];
        textLabel.numberOfLines = 0;
        [container addSubview:textLabel];
        [NSLayoutConstraint activateConstraints:@[
            [textLabel.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
            [textLabel.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
            [textLabel.topAnchor constraintEqualToAnchor:container.topAnchor],
            [textLabel.bottomAnchor constraintEqualToAnchor:container.bottomAnchor]
        ]];
        return container;
    }
    UIImageView *iconView = [[UIImageView alloc] initWithImage:icon];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    iconView.tintColor = row.iconTintColor ?: [SPKUtils SPKColor_InstagramPrimaryText];
    [container addSubview:iconView];

    UIFont *subheadline = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
    UILabel *titleLabel = [UILabel new];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.text = row.title;
    titleLabel.font = [UIFont systemFontOfSize:subheadline.pointSize weight:UIFontWeightSemibold];
    titleLabel.adjustsFontForContentSizeCategory = YES;
    titleLabel.textColor = [SPKUtils SPKColor_InstagramPrimaryText];
    titleLabel.numberOfLines = 0;
    [container addSubview:titleLabel];

    UILabel *bodyLabel = [UILabel new];
    bodyLabel.translatesAutoresizingMaskIntoConstraints = NO;
    bodyLabel.text = row.helpText;
    bodyLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
    bodyLabel.adjustsFontForContentSizeCategory = YES;
    bodyLabel.textColor = [SPKUtils SPKColor_InstagramSecondaryText];
    bodyLabel.numberOfLines = 0;
    [container addSubview:bodyLabel];

    [NSLayoutConstraint activateConstraints:@[
        [iconView.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [iconView.topAnchor constraintEqualToAnchor:container.topAnchor constant:1.0],
        [iconView.widthAnchor constraintEqualToConstant:kSPKHelpIconSize],
        [iconView.heightAnchor constraintEqualToConstant:kSPKHelpIconSize],

        [titleLabel.leadingAnchor constraintEqualToAnchor:iconView.trailingAnchor constant:kSPKHelpIconGutter],
        [titleLabel.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [titleLabel.topAnchor constraintEqualToAnchor:container.topAnchor],

        [bodyLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [bodyLabel.trailingAnchor constraintEqualToAnchor:container.trailingAnchor],
        [bodyLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:3.0],
        [bodyLabel.bottomAnchor constraintEqualToAnchor:container.bottomAnchor]
    ]];

    return container;
}

- (CGFloat)spk_contentHeightForWidth:(CGFloat)width {
    if (width <= 0.0) {
        width = CGRectGetWidth(UIScreen.mainScreen.bounds);
    }

    [self.view layoutIfNeeded];

    CGFloat contentWidth = MAX(width - (kSPKHelpHorizontalInset * 2.0), 1.0);
    CGFloat total = 0.0;
    for (UIView *entry in self.entryStack.arrangedSubviews) {
        total += [entry systemLayoutSizeFittingSize:CGSizeMake(contentWidth, UILayoutFittingCompressedSize.height)
                      withHorizontalFittingPriority:UILayoutPriorityRequired
                            verticalFittingPriority:UILayoutPriorityFittingSizeLevel]
                     .height;
    }

    NSInteger gaps = (NSInteger)self.entryStack.arrangedSubviews.count - 1;
    if (gaps > 0) {
        total += kSPKHelpEntrySpacing * (CGFloat)gaps;
    }

    return total + kSPKHelpTopPadding + kSPKHelpBottomPadding + kSPKHelpChromeHeight;
}

- (void)spk_closeTapped {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
