#import "../Shared/UI/SPKDialog.h"
#import "SPKActionSectionEditViewController.h"
#import "SPKActionSectionIconPickerViewController.h"
#import "SPKInstagramIconCatalog.h"
#import "SPKTopicSettingsSupport.h"

#import "../AssetUtils.h"
#import "../Shared/ActionButton/SPKActionDescriptor.h"
#import "../Utils.h"

static char kSPKSectionEditFieldAssocKey;

@interface SPKActionSectionEditViewController () <UITableViewDataSource, UITableViewDelegate, UITableViewDragDelegate, UITableViewDropDelegate, UITextFieldDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) SPKActionButtonConfiguration *configuration;
@property (nonatomic, copy) NSString *sectionIdentifier;
@property (nonatomic, copy) dispatch_block_t onChange;

@end

@implementation SPKActionSectionEditViewController

- (UIView *)selectionBackgroundView {
    UIView *view = [[UIView alloc] initWithFrame:CGRectZero];
    view.backgroundColor = [SPKUtils SPKColor_InstagramPressedBackground];
    return view;
}

- (NSString *)displayTitleForSectionIconName:(NSString *)iconName {
    for (SPKActionDescriptor *descriptor in [SPKActionDescriptor availableSectionIconDescriptors]) {
        if ([descriptor.iconName isEqualToString:iconName]) {
            return descriptor.title ?: iconName;
        }
    }
    return [SPKInstagramIconCatalog displayNameForIconName:iconName];
}

- (void)showIconPicker {
    SPKActionMenuSection *section = [self currentSection];
    if (!section)
        return;

    __weak typeof(self) weakSelf = self;
    SPKActionSectionIconPickerViewController *controller = [[SPKActionSectionIconPickerViewController alloc] initWithSelectedIconName:section.iconName
                                                                                                                             onSelect:^(NSString *iconName) {
                                                                                                                                 __strong typeof(weakSelf) strongSelf = weakSelf;
                                                                                                                                 if (!strongSelf)
                                                                                                                                     return;
                                                                                                                                 SPKActionMenuSection *strongSection = [strongSelf currentSection];
                                                                                                                                 strongSection.iconName = iconName;
                                                                                                                                 [strongSelf.configuration save];
                                                                                                                                 if (strongSelf.onChange)
                                                                                                                                     strongSelf.onChange();
                                                                                                                                 [strongSelf.tableView reloadData];
                                                                                                                             }];
    [self.navigationController pushViewController:controller animated:YES];
}

- (instancetype)initWithConfiguration:(SPKActionButtonConfiguration *)configuration
                    sectionIdentifier:(NSString *)sectionIdentifier
                             onChange:(dispatch_block_t)onChange {
    self = [super init];
    if (self) {
        _configuration = configuration;
        _sectionIdentifier = [sectionIdentifier copy];
        _onChange = [onChange copy];
        // currentSection is available now that the identifier is set; the title
        // is refreshed in viewWillAppear in case it is renamed here.
        self.title = [self currentSection].title ?: @"Submenu";
    }
    return self;
}

- (SPKActionMenuSection *)currentSection {
    return [self.configuration sectionWithIdentifier:self.sectionIdentifier];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationController.navigationBar.prefersLargeTitles = NO;
    self.view.backgroundColor = [SPKUtils SPKColor_InstagramGroupedBackground];
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.dragInteractionEnabled = YES;
    self.tableView.dragDelegate = self;
    self.tableView.dropDelegate = self;
    self.tableView.backgroundColor = [SPKUtils SPKColor_InstagramBackground];
    // No hairline between rows: the bands do the separating, like every other
    // Sparkle screen (SPKSettingsViewController.m:553).
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.separatorColor = [SPKUtils SPKColor_InstagramSeparator];
    [self.view addSubview:self.tableView];
}

- (BOOL)isBulkSection {
    return [[self currentSection].identifier isEqualToString:@"bulk"];
}

// The submenu's own settings only. Its actions are arranged on Configure Menu,
// and what makes it a submenu is the zone it lives in — so neither the action
// lists nor the "Show as Submenu" switch belong here any more.
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return [self isBulkSection] ? 1 : 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return section == 0 ? 2 : 1;   // name · icon, then Delete Submenu
}

// The 6 pt band the rest of Sparkle puts between groups. #EFEFF1 in hard code:
// SPKColor_InstagramGroupedBackground returns white in this palette.
- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    return 6.0;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
    UIView *band = [UIView new];
    band.backgroundColor = [UIColor colorWithRed:0.937 green:0.937 blue:0.945 alpha:1.0];
    return band;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if ([self isBulkSection] && section == 0)
        return @"Bulk shows Download All / Copy All / Select Media on carousels. Its actions come from your single-item Download and Copy actions.";
    if (section == 1)
        return @"Its actions move to \"Not in the Menu\". Nothing is lost.";
    if (section == 0)
        return @"The name and icon are what the row in Instagram's menu will show.";
    return nil;
}

// The 44 pt pitch of the rest of the tweak.
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 44.0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    SPKActionMenuSection *section = [self currentSection];
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    UIListContentConfiguration *config = cell.defaultContentConfiguration;
    UIImage *deferredIconAccessoryImage = nil;
    cell.backgroundColor = [SPKUtils SPKColor_InstagramBackground];
    cell.selectedBackgroundView = [self selectionBackgroundView];
    config.textProperties.color = [SPKUtils SPKColor_InstagramPrimaryText];
    config.secondaryTextProperties.color = [SPKUtils SPKColor_InstagramSecondaryText];

    if (indexPath.section == 0) {
        if (indexPath.row == 0) {
            config.text = @"Name";
            UITextField *field = [[UITextField alloc] initWithFrame:CGRectMake(0, 0, 180, 30)];
            field.textAlignment = NSTextAlignmentRight;
            field.placeholder = @"Submenu";
            field.text = section.title;
            field.returnKeyType = UIReturnKeyDone;
            field.delegate = self;
            objc_setAssociatedObject(field, &kSPKSectionEditFieldAssocKey, self, OBJC_ASSOCIATION_ASSIGN);
            [field addTarget:self action:@selector(titleFieldChanged:) forControlEvents:UIControlEventEditingChanged];
            cell.accessoryView = field;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        } else if (indexPath.row == 1) {
            config.text = @"Icon";
            config.secondaryText = nil;
            config.image = nil;
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

            UIImage *iconImage = SPKSettingsIcon(section.iconName);
            if (iconImage) {
                deferredIconAccessoryImage = iconImage;
            }

            cell.selectionStyle = UITableViewCellSelectionStyleDefault;
        }
    } else {
        config.text = @"Delete Submenu";
        config.textProperties.color = [SPKUtils SPKColor_InstagramDestructive];
        config.image = SPKSettingsIcon(@"trash");
        config.imageProperties.tintColor = [SPKUtils SPKColor_InstagramDestructive];
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    }

    cell.contentConfiguration = config;
    if (deferredIconAccessoryImage) {
        UIImageView *iconView = [[UIImageView alloc] initWithImage:deferredIconAccessoryImage];
        iconView.tintColor = [SPKUtils SPKColor_InstagramSecondaryText];
        iconView.contentMode = UIViewContentModeScaleAspectFit;
        iconView.translatesAutoresizingMaskIntoConstraints = NO;
        [cell.contentView addSubview:iconView];
        [NSLayoutConstraint activateConstraints:@[
            [iconView.centerYAnchor constraintEqualToAnchor:cell.contentView.centerYAnchor],
            [iconView.trailingAnchor constraintEqualToAnchor:cell.contentView.layoutMarginsGuide.trailingAnchor],
            [iconView.widthAnchor constraintEqualToConstant:24.0],
            [iconView.heightAnchor constraintEqualToConstant:24.0]
        ]];
    }
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    return indexPath.section == 1;
}

- (NSArray<UIDragItem *> *)tableView:(UITableView *)tableView itemsForBeginningDragSession:(id<UIDragSession>)session atIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section != 1)
        return @[];
    NSString *identifier = [self currentSection].actions[indexPath.row];
    UIDragItem *item = [[UIDragItem alloc] initWithItemProvider:[[NSItemProvider alloc] initWithObject:identifier]];
    item.localObject = identifier;
    return @[ item ];
}

- (BOOL)tableView:(UITableView *)tableView dragSessionAllowsMoveOperation:(id<UIDragSession>)session {
    return YES;
}

- (BOOL)tableView:(UITableView *)tableView dragSessionIsRestrictedToDraggingApplication:(id<UIDragSession>)session {
    return YES;
}

- (UITableViewDropProposal *)tableView:(UITableView *)tableView dropSessionDidUpdate:(id<UIDropSession>)session withDestinationIndexPath:(NSIndexPath *)destinationIndexPath {
    if (session.localDragSession == nil || destinationIndexPath.section != 1) {
        return [[UITableViewDropProposal alloc] initWithDropOperation:UIDropOperationCancel];
    }
    return [[UITableViewDropProposal alloc] initWithDropOperation:UIDropOperationMove intent:UITableViewDropIntentInsertAtDestinationIndexPath];
}

- (void)tableView:(UITableView *)tableView performDropWithCoordinator:(id<UITableViewDropCoordinator>)coordinator {
    NSIndexPath *destinationIndexPath = coordinator.destinationIndexPath;
    id<UITableViewDropItem> dropItem = coordinator.items.firstObject;
    NSIndexPath *sourceIndexPath = dropItem.sourceIndexPath;
    if (!destinationIndexPath || !sourceIndexPath || sourceIndexPath.section != 1 || destinationIndexPath.section != 1)
        return;

    NSInteger rowCount = [self currentSection].actions.count;
    NSInteger destinationRow = MIN(MAX(0, destinationIndexPath.row), MAX(0, rowCount - 1));
    NSIndexPath *target = [NSIndexPath indexPathForRow:destinationRow inSection:1];

    [tableView
        performBatchUpdates:^{
            [self.configuration moveActionInSectionIdentifier:self.sectionIdentifier fromIndex:sourceIndexPath.row toIndex:target.row];
            [self.configuration save];
            if (self.onChange)
                self.onChange();
            [tableView moveRowAtIndexPath:sourceIndexPath toIndexPath:target];
        }
                 completion:nil];
    [coordinator dropItem:dropItem.dragItem toRowAtIndexPath:target];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (indexPath.section == 0 && indexPath.row == 1) {
        [self showIconPicker];
        return;
    }
    if (indexPath.section == 1)
        [self confirmDeleteSubmenu];
}

// Deleting a submenu empties it rather than losing anything: its actions land
// in "Not in the Menu", where a swipe puts them back.
- (void)confirmDeleteSubmenu {
    SPKActionMenuSection *section = [self currentSection];
    NSString *message = section.actions.count > 0
        ? [NSString stringWithFormat:@"Its %lu action%@ move back to \"Not in the menu\".",
           (unsigned long)section.actions.count, section.actions.count == 1 ? @"" : @"s"]
        : @"This group has nothing in it.";

    // The only alert in the tweak that was built by hand, so it wore iOS's
    // colours while every other confirmation wore Sparkle's.
    __weak typeof(self) weakSelf = self;
    [SPKDialog presentFromController:self
                               title:[NSString stringWithFormat:@"Delete \"%@\"", section.title]
                             message:message
                             actions:@[
                                 [SPKDialogAction actionWithTitle:@"Cancel"
                                                            style:SPKDialogActionStyleCancel
                                                          handler:nil],
                                 [SPKDialogAction actionWithTitle:@"Delete"
                                                            style:SPKDialogActionStyleDestructive
                                                          handler:^{
                                     typeof(self) strongSelf = weakSelf;
                                     if (!strongSelf)
                                         return;
                                     SPKActionMenuSection *doomed = [strongSelf currentSection];
                                     for (NSString *identifier in [doomed.actions copy])
                                         [strongSelf.configuration setAction:identifier assignedToSectionIdentifier:nil];
                                     [strongSelf.configuration.sections removeObject:doomed];
                                     [strongSelf.configuration normalize];
                                     [strongSelf.configuration save];
                                     if (strongSelf.onChange)
                                         strongSelf.onChange();
                                     [strongSelf.navigationController popViewControllerAnimated:YES];
                                 }],
                             ]];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

- (void)titleFieldChanged:(UITextField *)sender {
    SPKActionMenuSection *section = [self currentSection];
    section.title = sender.text.length > 0 ? sender.text : @"Submenu";
    self.title = section.title;
    [self.configuration save];
    if (self.onChange)
        self.onChange();
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated {
    [super setEditing:editing animated:animated];
    [self.tableView setEditing:editing animated:animated];
}

@end
