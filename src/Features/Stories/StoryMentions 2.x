// Story Mentions — Gallery-style bottom sheet listing mentioned users with Follow/Following buttons.
// Triggered by the @ button in story overlays (SeenButtons.x).

#import "../../AssetUtils.h"
#import "../../InstagramHeaders.h"
#import "../../Networking/SPKInstagramAPI.h"
#import "../../Shared/UI/SPKMediaChrome.h"
#import "../../Shared/UI/SPKNotificationCenter.h"
#import "../../Utils.h"
#import <objc/message.h>
#import <objc/runtime.h>

extern void SPKPauseStoryPlaybackFromOverlaySubview(UIView *view);
extern void SPKResumeStoryPlaybackFromOverlaySubview(UIView *view);

static NSMutableDictionary<NSString *, NSArray<NSDictionary *> *> *SPKStoryMentionsSessionCache;
static NSMutableDictionary<NSString *, NSDictionary *> *SPKStoryMentionsFriendshipStatusCache;
static NSCache<NSString *, UIImage *> *SPKStoryMentionsAvatarCache;

static void SPKStoryMentionsEnsureSessionCaches(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        SPKStoryMentionsSessionCache = [NSMutableDictionary dictionary];
        SPKStoryMentionsFriendshipStatusCache = [NSMutableDictionary dictionary];
        SPKStoryMentionsAvatarCache = [[NSCache alloc] init];
        SPKStoryMentionsAvatarCache.countLimit = 128;
    });
}

static NSString *SPKStoryMentionsCacheKeyForMedia(id media) {
    if (!media)
        return nil;
    for (NSString *selectorName in @[ @"pk", @"id", @"mediaID", @"mediaId", @"code", @"shortCode", @"shortcode" ]) {
        id value = nil;
        @try {
            SEL selector = NSSelectorFromString(selectorName);
            if ([media respondsToSelector:selector])
                value = ((id (*)(id, SEL))objc_msgSend)(media, selector);
        } @catch (__unused id e) {
        }
        NSString *string = value ? [NSString stringWithFormat:@"%@", value] : nil;
        if (string.length > 0)
            return [NSString stringWithFormat:@"%@:%@", selectorName, string];
    }
    return [NSString stringWithFormat:@"ptr:%p", media];
}

// ============ User PK extraction ============

// IGUser stores fields in a Pando-backed dictionary (_fieldCache).
// Standard KVC may return NSNull, so we read the dict directly.
static id SPKMentionFieldCacheValue(id obj, NSString *key) {
    if (!obj || !key)
        return nil;
    static Ivar fcIvar = NULL;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        Class c = NSClassFromString(@"IGAPIStorableObject");
        if (c)
            fcIvar = class_getInstanceVariable(c, "_fieldCache");
    });
    if (!fcIvar)
        return nil;
    NSDictionary *fc = object_getIvar(obj, fcIvar);
    if (!fc || ![fc isKindOfClass:[NSDictionary class]])
        return nil;
    id val = fc[key];
    if (!val || [val isKindOfClass:[NSNull class]])
        return nil;
    return val;
}

static NSString *SPKMentionUserPK(id userObj) {
    if (!userObj)
        return nil;
    id pk = SPKMentionFieldCacheValue(userObj, @"strong_id__");
    if (!pk)
        pk = SPKMentionFieldCacheValue(userObj, @"pk");
    if (!pk) {
        @try {
            Ivar pkIvar = class_getInstanceVariable([userObj class], "_pk");
            if (pkIvar)
                pk = object_getIvar(userObj, pkIvar);
        } @catch (__unused id e) {
        }
    }
    return pk ? [NSString stringWithFormat:@"%@", pk] : nil;
}

static void SPKMentionStyleFollowButton(UIButton *btn, BOOL following) {
    [btn setTitle:following ? @"Following" : @"Follow" forState:UIControlStateNormal];
    if (following) {
        btn.backgroundColor = [SPKUtils SPKColor_InstagramSecondaryBackground];
        [btn setTitleColor:[SPKUtils SPKColor_InstagramPrimaryText] forState:UIControlStateNormal];
    } else {
        btn.backgroundColor = [SPKUtils SPKColor_InstagramBlue];
        [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    }
    btn.layer.borderWidth = 0.0;
    btn.layer.cornerRadius = 8.0;
    btn.clipsToBounds = YES;
}

// ============ Enhanced mention extraction ============

// Enriched version that also extracts userObj, pk, and profile_pic_url
// (the SeenButtons.x version only extracts username and fullName)
static NSArray<NSDictionary *> *SPKStoryMentionsEnriched(UIView *overlayView) {
    if (!overlayView)
        return @[];

    // Use the same resolution path as SeenButtons.x
    id media = nil;
    @try {
        // Walk up to find IGStoryViewerViewController or IGStoryItemMediaView
        UIView *v = overlayView;
        for (NSInteger i = 0; i < 25 && v; i++, v = v.superview) {
            // Try the media view first
            SEL mediaSel = NSSelectorFromString(@"media");
            if ([v respondsToSelector:mediaSel]) {
                id candidate = ((id (*)(id, SEL))objc_msgSend)(v, mediaSel);
                if (candidate && [candidate respondsToSelector:NSSelectorFromString(@"reelMentions")]) {
                    media = candidate;
                    break;
                }
            }
        }

        // Fallback: try the view controller hierarchy
        if (!media) {
            UIResponder *r = overlayView;
            while (r) {
                if ([r isKindOfClass:[UIViewController class]]) {
                    UIViewController *vc = (UIViewController *)r;
                    // Try currentStoryItem
                    SEL csi = NSSelectorFromString(@"currentStoryItem");
                    if ([vc respondsToSelector:csi]) {
                        id item = ((id (*)(id, SEL))objc_msgSend)(vc, csi);
                        if ([item respondsToSelector:NSSelectorFromString(@"reelMentions")]) {
                            media = item;
                            break;
                        }
                    }
                    // Try currentItem
                    SEL ci = NSSelectorFromString(@"currentItem");
                    if ([vc respondsToSelector:ci]) {
                        id item = ((id (*)(id, SEL))objc_msgSend)(vc, ci);
                        if ([item respondsToSelector:NSSelectorFromString(@"reelMentions")]) {
                            media = item;
                            break;
                        }
                    }
                }
                r = r.nextResponder;
            }
        }
    } @catch (__unused id e) {
    }

    if (!media)
        return @[];

    SPKStoryMentionsEnsureSessionCaches();
    NSString *cacheKey = SPKStoryMentionsCacheKeyForMedia(media);
    NSArray<NSDictionary *> *cached = cacheKey.length > 0 ? SPKStoryMentionsSessionCache[cacheKey] : nil;
    if (cached)
        return cached;

    SEL mentionsSel = NSSelectorFromString(@"reelMentions");
    if (![media respondsToSelector:mentionsSel])
        return @[];
    id mentionsCollection = ((id (*)(id, SEL))objc_msgSend)(media, mentionsSel);

    NSArray *mentions = nil;
    if ([mentionsCollection isKindOfClass:[NSArray class]]) {
        mentions = (NSArray *)mentionsCollection;
    } else if ([mentionsCollection isKindOfClass:[NSSet class]]) {
        mentions = [(NSSet *)mentionsCollection allObjects];
    } else if ([mentionsCollection isKindOfClass:[NSOrderedSet class]]) {
        mentions = [(NSOrderedSet *)mentionsCollection array];
    }
    if (mentions.count == 0)
        return @[];

    NSMutableArray<NSDictionary *> *userInfos = [NSMutableArray array];
    for (id mention in mentions) {
        id user = nil;
        @try {
            user = [mention valueForKey:@"user"];
        } @catch (__unused id e) {
        }
        if (!user)
            continue;

        NSMutableDictionary *info = [NSMutableDictionary dictionary];
        info[@"userObj"] = user;

        NSString *username = SPKMentionFieldCacheValue(user, @"username");
        if (username.length)
            info[@"username"] = username;

        NSString *fullName = SPKMentionFieldCacheValue(user, @"full_name");
        if (fullName.length)
            info[@"fullName"] = fullName;

        NSString *picStr = SPKMentionFieldCacheValue(user, @"profile_pic_url");
        if (picStr.length) {
            NSURL *picURL = [NSURL URLWithString:picStr];
            if (picURL)
                info[@"picURL"] = picURL;
        }

        if (info.count > 1)
            [userInfos addObject:info]; // must have userObj + at least one other field
    }
    NSArray<NSDictionary *> *result = [userInfos copy];
    if (cacheKey.length > 0)
        SPKStoryMentionsSessionCache[cacheKey] = result;
    return result;
}

/// ============ Bottom sheet VC ============

#define kSPKMentionAvatarSize 52.0
#define kSPKMentionRowHeight 72.0

@interface SPKMentionCell : UITableViewCell
@property (nonatomic, strong) UIImageView *avatarView;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *subLabel;
@property (nonatomic, strong) UIButton *followBtn;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@end

@implementation SPKMentionCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.backgroundColor = [SPKUtils SPKColor_InstagramBackground];
        self.selectedBackgroundView = [UIView new];
        self.selectedBackgroundView.backgroundColor = [SPKUtils SPKColor_InstagramPressedBackground];

        self.avatarView = [[UIImageView alloc] init];
        self.avatarView.clipsToBounds = YES;
        self.avatarView.contentMode = UIViewContentModeScaleAspectFill;
        self.avatarView.layer.cornerRadius = kSPKMentionAvatarSize / 2.0;
        self.avatarView.backgroundColor = [SPKUtils SPKColor_InstagramSeparator];
        self.avatarView.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:self.avatarView];

        self.nameLabel = [[UILabel alloc] init];
        self.nameLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
        self.nameLabel.textColor = [SPKUtils SPKColor_InstagramPrimaryText];
        self.nameLabel.translatesAutoresizingMaskIntoConstraints = NO;

        self.subLabel = [[UILabel alloc] init];
        self.subLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightRegular];
        self.subLabel.textColor = [SPKUtils SPKColor_InstagramSecondaryText];
        self.subLabel.translatesAutoresizingMaskIntoConstraints = NO;

        self.followBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        self.followBtn.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
        self.followBtn.layer.cornerRadius = 8.0;
        self.followBtn.clipsToBounds = YES;
        self.followBtn.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:self.followBtn];

        self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
        self.spinner.hidesWhenStopped = YES;
        self.spinner.translatesAutoresizingMaskIntoConstraints = NO;
        [self.followBtn addSubview:self.spinner];

        UIStackView *textStack = [[UIStackView alloc] initWithArrangedSubviews:@[ self.nameLabel, self.subLabel ]];
        textStack.axis = UILayoutConstraintAxisVertical;
        textStack.spacing = 2;
        textStack.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:textStack];

        [NSLayoutConstraint activateConstraints:@[
            [self.avatarView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor
                                                          constant:16],
            [self.avatarView.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [self.avatarView.widthAnchor constraintEqualToConstant:kSPKMentionAvatarSize],
            [self.avatarView.heightAnchor constraintEqualToConstant:kSPKMentionAvatarSize],

            [textStack.leadingAnchor constraintEqualToAnchor:self.avatarView.trailingAnchor
                                                    constant:12],
            [textStack.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [textStack.trailingAnchor constraintLessThanOrEqualToAnchor:self.followBtn.leadingAnchor
                                                               constant:-10],

            [self.followBtn.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor
                                                          constant:-16],
            [self.followBtn.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
            [self.followBtn.widthAnchor constraintGreaterThanOrEqualToConstant:88],
            [self.followBtn.heightAnchor constraintEqualToConstant:32],

            [self.spinner.centerXAnchor constraintEqualToAnchor:self.followBtn.centerXAnchor],
            [self.spinner.centerYAnchor constraintEqualToAnchor:self.followBtn.centerYAnchor],
        ]];
    }
    return self;
}

@end
@interface SPKStoryMentionsVC : UIViewController <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) NSArray<NSDictionary *> *userInfos;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSString *currentUsername;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSDictionary *> *friendshipStatuses;
@property (nonatomic, weak) UIView *storyOverlayView; // for resuming playback on dismiss
@end

@implementation SPKStoryMentionsVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [SPKUtils SPKColor_InstagramBackground];
    self.title = @"Mentions";

    // Resolve current user to hide the Follow button for yourself
    @try {
        id window = [[UIApplication sharedApplication] keyWindow];
        if ([window respondsToSelector:@selector(userSession)])
            self.currentUsername = ((IGUserSession *)[window valueForKey:@"userSession"]).user.username;
    } @catch (__unused id e) {
    }

    // Table view (stretching under navigation bar)
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.backgroundColor = [UIColor clearColor];
    self.tableView.separatorColor = [SPKUtils SPKColor_InstagramSeparator];
    self.tableView.separatorInset = UIEdgeInsetsMake(0.0, 80.0, 0.0, 0.0);
    self.tableView.rowHeight = kSPKMentionRowHeight;
    self.tableView.estimatedRowHeight = 0;
    self.tableView.estimatedSectionHeaderHeight = 0;
    self.tableView.estimatedSectionFooterHeight = 0;
    self.tableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentAutomatic;
    self.tableView.contentInset = UIEdgeInsetsMake(0, 0, 12, 0);
    self.tableView.scrollIndicatorInsets = UIEdgeInsetsMake(0, 0, 12, 0);
    self.tableView.showsVerticalScrollIndicator = NO;
    [self.view addSubview:self.tableView];

    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];

    // Bulk-fetch friendship statuses in one round trip
    SPKStoryMentionsEnsureSessionCaches();
    self.friendshipStatuses = [NSMutableDictionary dictionary];
    NSMutableArray<NSString *> *missingPKs = [NSMutableArray array];
    for (NSDictionary *info in self.userInfos) {
        NSString *pk = SPKMentionUserPK(info[@"userObj"]);
        if (!pk.length)
            continue;
        NSDictionary *cachedStatus = SPKStoryMentionsFriendshipStatusCache[pk];
        if (cachedStatus) {
            self.friendshipStatuses[pk] = cachedStatus;
        } else {
            [missingPKs addObject:pk];
        }
    }
    if (missingPKs.count) {
        __weak typeof(self) weakSelf = self;
        [SPKInstagramAPI fetchFriendshipStatusesForPKs:missingPKs
                                            completion:^(NSDictionary *statuses, NSError *error) {
                                                (void)error;
                                                if (!statuses.count)
                                                    return;
                                                [SPKStoryMentionsFriendshipStatusCache addEntriesFromDictionary:statuses];
                                                [weakSelf.friendshipStatuses addEntriesFromDictionary:statuses];
                                                [weakSelf.tableView reloadData];
                                            }];
    }
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    // Resume story playback when mentions sheet is dismissed
    if (self.storyOverlayView) {
        SPKResumeStoryPlaybackFromOverlaySubview(self.storyOverlayView);

        UIResponder *r = self.storyOverlayView;
        while (r) {
            if ([r isKindOfClass:[UIViewController class]]) {
                SEL sel = NSSelectorFromString(@"tryResumePlayback");
                if ([r respondsToSelector:sel]) {
                    ((void (*)(id, SEL))objc_msgSend)(r, sel);
                    break;
                }
            }
            r = r.nextResponder;
        }
    }
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.userInfos.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *rid = @"SPKMention";
    SPKMentionCell *cell = [tableView dequeueReusableCellWithIdentifier:rid];
    if (!cell) {
        cell = [[SPKMentionCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:rid];
    }

    NSDictionary *info = self.userInfos[indexPath.row];
    NSString *username = info[@"username"] ?: @"Unknown";
    NSString *fullName = info[@"fullName"];
    NSURL *picURL = info[@"picURL"];

    cell.nameLabel.text = username;
    cell.subLabel.text = fullName ?: @"";
    cell.subLabel.hidden = !fullName.length;

    // Default avatar — draw the 24pt glyph at its native size (contentMode Center)
    // so the small asset isn't upscaled and blurred by the avatar's aspect-fill.
    cell.avatarView.contentMode = UIViewContentModeCenter;
    cell.avatarView.image = [SPKAssetUtils instagramIconNamed:@"user_circle" pointSize:24.0 renderingMode:UIImageRenderingModeAlwaysTemplate];
    cell.avatarView.tintColor = [SPKUtils SPKColor_InstagramTertiaryText];

    // Avatar fetch with session cache
    if (picURL) {
        NSString *cacheKey = picURL.absoluteString;
        objc_setAssociatedObject(cell.avatarView, @selector(cellForRowAtIndexPath:), cacheKey, OBJC_ASSOCIATION_COPY_NONATOMIC);

        UIImage *cachedAvatar = cacheKey.length > 0 ? [SPKStoryMentionsAvatarCache objectForKey:cacheKey] : nil;
        if (cachedAvatar) {
            cell.avatarView.contentMode = UIViewContentModeScaleAspectFill;
            cell.avatarView.image = cachedAvatar;
            cell.avatarView.tintColor = nil;
        } else {
            NSURL *url = [picURL copy];
            NSInteger row = indexPath.row;
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                NSData *data = [NSData dataWithContentsOfURL:url];
                if (!data)
                    return;
                UIImage *img = [UIImage imageWithData:data];
                if (!img)
                    return;
                if (cacheKey.length > 0) {
                    [SPKStoryMentionsAvatarCache setObject:img forKey:cacheKey];
                }
                dispatch_async(dispatch_get_main_queue(), ^{
                    UITableViewCell *c = [tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:row inSection:0]];
                    if (!c || ![c isKindOfClass:[SPKMentionCell class]])
                        return;
                    SPKMentionCell *mc = (SPKMentionCell *)c;
                    NSString *boundKey = objc_getAssociatedObject(mc.avatarView, @selector(cellForRowAtIndexPath:));
                    if (mc.avatarView && (!boundKey || [boundKey isEqualToString:cacheKey])) {
                        mc.avatarView.contentMode = UIViewContentModeScaleAspectFill;
                        mc.avatarView.image = img;
                        mc.avatarView.tintColor = nil;
                    }
                });
            });
        }
    }

    // Follow button state
    [cell.followBtn removeTarget:nil action:NULL forControlEvents:UIControlEventTouchUpInside];
    [cell.spinner stopAnimating];
    cell.spinner.color = [SPKUtils SPKColor_InstagramSecondaryText];

    BOOL isMe = self.currentUsername && [username isEqualToString:self.currentUsername];
    if (isMe) {
        cell.followBtn.hidden = YES;
    } else {
        cell.followBtn.hidden = NO;
        id userObj = info[@"userObj"];

        BOOL following = NO;
        NSString *pk = SPKMentionUserPK(userObj);
        NSDictionary *status = pk ? self.friendshipStatuses[pk] : nil;
        if ([status isKindOfClass:[NSDictionary class]]) {
            following = [status[@"following"] boolValue];
        }
        SPKMentionStyleFollowButton(cell.followBtn, following);

        objc_setAssociatedObject(cell.followBtn, "userObj", userObj, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [cell.followBtn addTarget:self action:@selector(spk_followTapped:) forControlEvents:UIControlEventTouchUpInside];
    }

    return cell;
}

#pragma mark - Follow/Unfollow

- (void)spk_followTapped:(UIButton *)sender {
    id userObj = objc_getAssociatedObject(sender, "userObj");
    if (!userObj)
        return;
    NSString *pk = SPKMentionUserPK(userObj);
    if (!pk.length)
        return;

    BOOL currentlyFollowing = [[sender titleForState:UIControlStateNormal] isEqualToString:@"Following"];

    void (^doIt)(void) = ^{
        UIActivityIndicatorView *spinner = nil;
        for (UIView *subview in sender.subviews) {
            if ([subview isKindOfClass:[UIActivityIndicatorView class]]) {
                spinner = (UIActivityIndicatorView *)subview;
                break;
            }
        }
        NSString *savedTitle = [sender titleForState:UIControlStateNormal];
        [sender setTitle:@"" forState:UIControlStateNormal];
        sender.userInteractionEnabled = NO;
        [spinner startAnimating];

        __weak typeof(self) weakSelf = self;
        SPKAPICompletion done = ^(NSDictionary *response, NSError *error) {
            [spinner stopAnimating];
            sender.userInteractionEnabled = YES;
            BOOL ok = (response && [response[@"status"] isEqualToString:@"ok"]);
            if (ok) {
                SPKMentionStyleFollowButton(sender, !currentlyFollowing);
                NSMutableDictionary *s = [weakSelf.friendshipStatuses[pk] mutableCopy] ?: [NSMutableDictionary dictionary];
                s[@"following"] = @(!currentlyFollowing);
                NSDictionary *updatedStatus = [s copy];
                weakSelf.friendshipStatuses[pk] = updatedStatus;
                SPKStoryMentionsEnsureSessionCaches();
                SPKStoryMentionsFriendshipStatusCache[pk] = updatedStatus;
            } else {
                [sender setTitle:savedTitle forState:UIControlStateNormal];
            }
        };

        if (currentlyFollowing)
            [SPKInstagramAPI unfollowUserPK:pk completion:done];
        else
            [SPKInstagramAPI followUserPK:pk completion:done];
    };
    if (!currentlyFollowing && [SPKUtils getBoolPref:@"profile_confirm_follow"]) {
        [SPKUtils showConfirmation:doIt
                             title:@"Follow account"
                           message:@"You start following this account."];
    } else if (currentlyFollowing && [SPKUtils getBoolPref:@"profile_confirm_unfollow"]) {
        [SPKUtils showConfirmation:doIt
                             title:@"Unfollow account"
                           message:@"You stop following this account."];
    } else {
        doIt();
    }
}

#pragma mark - UITableViewDelegate (row tap → profile)

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.row < 0 || indexPath.row >= (NSInteger)self.userInfos.count)
        return;
    NSDictionary *info = self.userInfos[indexPath.row];
    NSString *username = info[@"username"];
    id userObj = info[@"userObj"];
    NSString *pk = SPKMentionUserPK(userObj);
    if (username.length == 0 && !userObj)
        return;

    [SPKUtils openInstagramProfileForUser:userObj pk:pk username:username fromViewController:self];
}

@end

// ============ Presentation entry point ============

extern void SPKPauseStoryPlaybackFromOverlaySubview(UIView *);
extern void SPKResumeStoryPlaybackFromOverlaySubview(UIView *);

void SPKPresentStoryMentionsSheet(UIView *overlayView) {
    NSArray<NSDictionary *> *enriched = SPKStoryMentionsEnriched(overlayView);

    UIViewController *presenter = [SPKUtils nearestViewControllerForView:overlayView];
    if (!presenter)
        return;

    SPKPauseStoryPlaybackFromOverlaySubview(overlayView);

    SPKStoryMentionsVC *vc = [[SPKStoryMentionsVC alloc] init];
    vc.userInfos = enriched;
    vc.storyOverlayView = overlayView;

    UINavigationController *nav = [[SPKChromeNavigationController alloc] initWithRootViewController:vc];
    nav.modalPresentationStyle = UIModalPresentationPageSheet;

    UISheetPresentationController *sheet = nav.sheetPresentationController;

    if (@available(iOS 16.0, *)) {
        CGFloat headerHeight = 56.0;
        CGFloat contentHeight = MAX(1, enriched.count) * kSPKMentionRowHeight;
        CGFloat totalHeight = headerHeight + contentHeight + 40.0;
        UISheetPresentationControllerDetent *customDetent =
            [UISheetPresentationControllerDetent customDetentWithIdentifier:@"custom_fit"
                                                                   resolver:^CGFloat(id<UISheetPresentationControllerDetentResolutionContext> ctx) {
                                                                       return MIN(totalHeight, ctx.maximumDetentValue * 0.85);
                                                                   }];
        sheet.detents = @[ customDetent ];
    } else {
        sheet.detents = @[ UISheetPresentationControllerDetent.mediumDetent ];
    }

    sheet.prefersScrollingExpandsWhenScrolledToEdge = NO;
    sheet.prefersEdgeAttachedInCompactHeight = YES;
    sheet.widthFollowsPreferredContentSizeWhenEdgeAttached = YES;
    sheet.prefersGrabberVisible = YES;

    SPKNotify(kSPKNotificationStoryMentionsSheet, @"Opened story mentions", nil, @"mention", SPKNotificationToneForIconResource(@"mention"));
    [presenter presentViewController:nav animated:YES completion:nil];
}
