#import "SPKFakeLocationSettingsViewController.h"

#import "../../AssetUtils.h"
#import "../../Settings/SPKTopicSettingsSupport.h"
#import "../UI/SPKDialog.h"
#import "SPKFakeLocationPickerViewController.h"

static NSString *const kSPKFakeLocationRowPlaceIDKey = @"spkFakeLocationPlaceID";

NSString *SPKFakeLocationSettingsSummary(void) {
    if (![SPKFakeLocation isActive])
        return @"Off";
    return [SPKFakeLocation currentPlace].name ?: @"On";
}

void SPKFakeLocationPromptToSavePlace(UIViewController *presenter, SPKFakeLocationPlace *place) {
    if (!place)
        return;
    [SPKDialog presentTextInputFromController:presenter ?: SPKSettingsTopPresenter()
                                        title:@"Save place"
                                      message:[place displaySubtitle]
                                  placeholder:@"Name"
                                  initialText:place.name
                              autocapitalized:YES
                                 confirmTitle:@"Save"
                                  cancelTitle:@"Cancel"
                                 confirmStyle:SPKDialogActionStyleDefault
                                 confirmBlock:^(NSString *text) {
                                     NSString *name = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                                     SPKFakeLocationPlace *saved = [SPKFakeLocationPlace placeWithName:name.length ? name : place.name
                                                                                                address:place.address
                                                                                             coordinate:place.coordinate];
                                     [SPKFakeLocation addSavedPlace:saved];
                                 }
                                  cancelBlock:nil];
}

static BOOL SPKFakeLocationCurrentIsSaved(void) {
    for (SPKFakeLocationPlace *place in [SPKFakeLocation savedPlaces]) {
        if ([SPKFakeLocation savedPlaceMatchesCurrent:place])
            return YES;
    }
    return NO;
}

static SPKSetting *SPKFakeLocationSavedPlaceRow(SPKFakeLocationPlace *place) {
    BOOL current = [SPKFakeLocation savedPlaceMatchesCurrent:place];
    SPKSetting *row = [SPKSetting buttonCellWithTitle:place.name.length ? place.name : [place displaySubtitle]
                                             subtitle:place.name.length ? [place displaySubtitle] : nil
                                                 icon:SPKSettingsIcon(current ? @"location_filled" : @"location")
                                               action:^{
                                                   [SPKFakeLocation applyPlace:place enable:YES];
                                               }];
    if (current)
        SPKSettingApplyIconTint(row, [SPKUtils SPKColor_InstagramBlue]);
    row.userInfo = @{kSPKFakeLocationRowPlaceIDKey : place.identifier};
    return row;
}

NSArray *SPKFakeLocationSettingsSections(void) {
    SPKFakeLocationPlace *currentPlace = [SPKFakeLocation currentPlace];

    SPKSetting *enabled = [SPKSetting switchCellWithTitle:@"Use fake location"
                                                     icon:SPKSettingsIcon(@"location")
                                              defaultsKey:@""];
    enabled.helpText = @"Instagram sees the chosen location instead of where you are. Instagram still needs location access for friends to see it.";
    enabled.switchValueProvider = ^BOOL {
        return [SPKFakeLocation isActive];
    };
    enabled.switchChangeHandler = ^(BOOL isOn) {
        if ([SPKFakeLocation setEnabled:isOn])
            return;
        // No place set yet: the picker opens and the switch falls back to off until
        // a place is chosen.
        UIViewController *presenter = SPKSettingsTopPresenter();
        SPKSettingsReloadPresenter(presenter);
        [SPKFakeLocationPickerViewController presentFromViewController:presenter
                                                          initialPlace:nil
                                                                 title:@"Choose location"
                                                            completion:^(SPKFakeLocationPlace *place) {
                                                                [SPKFakeLocation applyPlace:place enable:YES];
                                                            }];
    };

    SPKSetting *location = [SPKSetting buttonCellWithTitle:@"Choose location"
                                                  subtitle:currentPlace ? [currentPlace displaySubtitle] : nil
                                                      icon:SPKSettingsIcon(@"map_pin")
                                                    action:^{
                                                        [SPKFakeLocationPickerViewController presentFromViewController:SPKSettingsTopPresenter()
                                                                                                          initialPlace:[SPKFakeLocation currentPlace]
                                                                                                                 title:@"Choose location"
                                                                                                            completion:^(SPKFakeLocationPlace *place) {
                                                                                                                [SPKFakeLocation applyPlace:place enable:NO];
                                                                                                            }];
                                                    }];
    location.userInfo = @{@"accessoryText" : currentPlace.name.length ? currentPlace.name : @"Not set"};
    location.helpText = @"Choose the location on a map or search for a place.";

    SPKSetting *mapButton = [SPKSetting switchCellWithTitle:@"Show button on map"
                                                       icon:SPKSettingsIcon(@"map")
                                                defaultsKey:kSPKFakeLocationMapButtonKey];
    mapButton.helpText = @"Adds a button to the friends map to turn the fake location on or off and change it.";
    mapButton.action = ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:SPKFakeLocationDidChangeNotification object:nil];
    };

    NSMutableArray *savedActions = [NSMutableArray array];
    SPKSetting *addPlace = [SPKSetting buttonCellWithTitle:@"Add place"
                                                  subtitle:nil
                                                      icon:SPKSettingsIcon(@"location_add")
                                                    action:^{
                                                        UIViewController *presenter = SPKSettingsTopPresenter();
                                                        [SPKFakeLocationPickerViewController presentFromViewController:presenter
                                                                                                          initialPlace:[SPKFakeLocation currentPlace]
                                                                                                                 title:@"Add place"
                                                                                                            completion:^(SPKFakeLocationPlace *place) {
                                                                                                                SPKFakeLocationPromptToSavePlace(SPKSettingsTopPresenter(), place);
                                                                                                            }];
                                                    }];
    addPlace.helpText = @"Tap a saved place to use it, or swipe left on it to rename or delete it. Saved places are shared by all accounts.";
    [savedActions addObject:addPlace];

    if (currentPlace && !SPKFakeLocationCurrentIsSaved()) {
        SPKSetting *saveCurrent = [SPKSetting buttonCellWithTitle:@"Save current location"
                                                         subtitle:nil
                                                             icon:SPKSettingsIcon(@"save")
                                                           action:^{
                                                               SPKFakeLocationPromptToSavePlace(SPKSettingsTopPresenter(), [SPKFakeLocation currentPlace]);
                                                           }];
        [savedActions addObject:saveCurrent];
    }

    NSMutableArray *placeRows = [NSMutableArray array];
    for (SPKFakeLocationPlace *place in [SPKFakeLocation savedPlaces])
        [placeRows addObject:SPKFakeLocationSavedPlaceRow(place)];

    NSMutableArray *sections = [NSMutableArray arrayWithObjects:
                                                   SPKTopicSection(@"", @[ enabled, location ], nil),
                                                   SPKTopicSection(@"Friends map", @[ mapButton ], nil),
                                                   SPKTopicSection(@"Saved places", savedActions, nil),
                                                   nil];
    // The places follow in a block of their own, below the actions that add to it.
    if (placeRows.count)
        [sections addObject:SPKTopicSection(@"", placeRows, nil)];
    return sections;
}

@implementation SPKFakeLocationSettingsViewController {
    id _changeObserver;
}

- (instancetype)init {
    return [super initWithTitle:@"Fake location" sections:SPKFakeLocationSettingsSections() reduceMargin:NO];
}

- (void)dealloc {
    if (_changeObserver)
        [[NSNotificationCenter defaultCenter] removeObserver:_changeObserver];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Changes also arrive from the friends map menu and from the picker, which
    // outlive the row that started them, so the page follows the store instead.
    __weak typeof(self) weakSelf = self;
    _changeObserver = [[NSNotificationCenter defaultCenter] addObserverForName:SPKFakeLocationDidChangeNotification
                                                                        object:nil
                                                                         queue:[NSOperationQueue mainQueue]
                                                                    usingBlock:^(__unused NSNotification *note) {
                                                                        [weakSelf spk_reloadIfVisible];
                                                                    }];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self replaceSections:SPKFakeLocationSettingsSections()];
}

- (void)spk_reloadIfVisible {
    if (!self.viewIfLoaded.window)
        return;
    // A reload rebuilds the switch cells without animation; let a toggle that
    // triggered this change finish sliding first.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self replaceSections:SPKFakeLocationSettingsSections()];
    });
}

- (SPKSetting *)spk_rowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section >= (NSInteger)self.sections.count)
        return nil;
    NSArray *rows = self.sections[indexPath.section][@"rows"];
    return indexPath.row < (NSInteger)rows.count ? rows[indexPath.row] : nil;
}

- (NSString *)spk_placeIdentifierAtIndexPath:(NSIndexPath *)indexPath {
    NSString *identifier = [self spk_rowAtIndexPath:indexPath].userInfo[kSPKFakeLocationRowPlaceIDKey];
    return [identifier isKindOfClass:[NSString class]] ? identifier : nil;
}

// The base page reports no editing style for any row, which also withholds swipe
// actions; saved places are the one kind of row here that can be swiped.
- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    return [self spk_placeIdentifierAtIndexPath:indexPath] ? UITableViewCellEditingStyleDelete : UITableViewCellEditingStyleNone;
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    SPKSetting *row = [self spk_rowAtIndexPath:indexPath];
    NSString *identifier = [self spk_placeIdentifierAtIndexPath:indexPath];
    if (!identifier)
        return [UISwipeActionsConfiguration configurationWithActions:@[]];

    UIContextualAction *delete = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive
                                                                         title:nil
                                                                       handler:^(__unused UIContextualAction *action, __unused UIView *sourceView, void (^completion)(BOOL)) {
                                                                           [SPKFakeLocation removeSavedPlaceWithIdentifier:identifier];
                                                                           completion(YES);
                                                                       }];
    UIContextualAction *rename = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                                         title:nil
                                                                       handler:^(__unused UIContextualAction *action, __unused UIView *sourceView, void (^completion)(BOOL)) {
                                                                           completion(YES);
                                                                           [SPKDialog presentTextInputFromController:self
                                                                                                               title:@"Rename place"
                                                                                                             message:nil
                                                                                                         placeholder:@"Name"
                                                                                                         initialText:row.title
                                                                                                     autocapitalized:YES
                                                                                                        confirmTitle:@"Save"
                                                                                                         cancelTitle:@"Cancel"
                                                                                                        confirmStyle:SPKDialogActionStyleDefault
                                                                                                        confirmBlock:^(NSString *text) {
                                                                                                            [SPKFakeLocation renameSavedPlaceWithIdentifier:identifier toName:text ?: @""];
                                                                                                        }
                                                                                                         cancelBlock:nil];
                                                                       }];
    delete.image = [SPKAssetUtils menuIconNamed:@"trash"];
    delete.backgroundColor = [SPKUtils SPKColor_InstagramDestructive];
    delete.accessibilityLabel = @"Delete";
    rename.image = [SPKAssetUtils menuIconNamed:@"edit"];
    rename.backgroundColor = [SPKUtils SPKColor_InstagramBlue];
    rename.accessibilityLabel = @"Rename";
    return [UISwipeActionsConfiguration configurationWithActions:@[ delete, rename ]];
}

@end
