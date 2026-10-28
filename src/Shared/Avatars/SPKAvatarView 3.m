#import "SPKAvatarView.h"
#import "../../AssetUtils.h"
#import "../../Utils.h"
#import "SPKAvatarCache.h"

@interface SPKAvatarView ()
@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) UIImageView *placeholderView;
@property (nonatomic, copy) NSString *currentPK;
@property (nonatomic, copy) NSString *currentURL;
@property (nonatomic, assign) BOOL isGroup;
@end

@implementation SPKAvatarView

// Native 24pt glyphs — the assets are 24px, don't upscale and blur them.
static UIImage *SPKAvatarUserGlyph(void) {
    return [SPKAssetUtils instagramIconNamed:@"user_circle" pointSize:24.0 renderingMode:UIImageRenderingModeAlwaysTemplate];
}

static UIImage *SPKAvatarGroupGlyph(void) {
    for (NSString *name in @[ @"group", @"people", @"members" ]) {
        UIImage *glyph = [SPKAssetUtils instagramIconNamed:name pointSize:24.0 renderingMode:UIImageRenderingModeAlwaysTemplate];
        if (glyph)
            return glyph;
    }
    return SPKAvatarUserGlyph();
}

- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.clipsToBounds = YES;
        self.backgroundColor = [SPKUtils SPKColor_InstagramTertiaryBackground];

        _placeholderView = [UIImageView new];
        _placeholderView.translatesAutoresizingMaskIntoConstraints = NO;
        _placeholderView.contentMode = UIViewContentModeScaleAspectFit;
        _placeholderView.tintColor = [SPKUtils SPKColor_InstagramSecondaryText];
        _placeholderView.image = SPKAvatarUserGlyph();
        [self addSubview:_placeholderView];

        _imageView = [UIImageView new];
        _imageView.translatesAutoresizingMaskIntoConstraints = NO;
        _imageView.contentMode = UIViewContentModeScaleAspectFill;
        _imageView.clipsToBounds = YES;
        _imageView.hidden = YES;
        [self addSubview:_imageView];

        [NSLayoutConstraint activateConstraints:@[
            [_imageView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
            [_imageView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
            [_imageView.topAnchor constraintEqualToAnchor:self.topAnchor],
            [_imageView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
            [_placeholderView.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
            [_placeholderView.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
            [_placeholderView.widthAnchor constraintEqualToConstant:24.0],
            [_placeholderView.heightAnchor constraintEqualToConstant:24.0],
        ]];

        UITapGestureRecognizer *retryTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(spk_retryTapped)];
        [self addGestureRecognizer:retryTap];
        self.userInteractionEnabled = NO;
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.layer.cornerRadius = self.bounds.size.width / 2.0;
}

- (void)prepareForReuse {
    self.currentPK = nil;
    self.currentURL = nil;
    self.isGroup = NO;
    self.imageView.image = nil;
    self.imageView.hidden = YES;
    self.placeholderView.image = SPKAvatarUserGlyph();
    self.placeholderView.hidden = NO;
    [self updateRetryInteraction];
}

- (void)configureWithPK:(NSString *)pk urlString:(NSString *)urlString {
    [self configureWithPK:pk urlString:urlString isGroup:NO];
}

- (void)configureWithPK:(NSString *)pk urlString:(NSString *)urlString isGroup:(BOOL)isGroup {
    self.currentPK = pk;
    self.currentURL = urlString;
    self.isGroup = isGroup;
    self.placeholderView.image = isGroup ? SPKAvatarGroupGlyph() : SPKAvatarUserGlyph();

    UIImage *warm = [[SPKAvatarCache shared] cachedImageForPK:pk];
    if (warm) {
        [self applyImage:warm];
        return;
    }

    self.imageView.hidden = YES;
    self.placeholderView.hidden = NO;
    [self updateRetryInteraction];

    if (pk.length == 0)
        return;

    __weak typeof(self) weakSelf = self;
    NSString *requestedPK = pk;
    [[SPKAvatarCache shared] avatarForPK:pk
                               urlString:urlString
                              completion:^(UIImage *image) {
                                  __strong typeof(weakSelf) strongSelf = weakSelf;
                                  if (!strongSelf || !image)
                                      return;
                                  if (![strongSelf.currentPK isEqualToString:requestedPK])
                                      return;
                                  [strongSelf applyImage:image];
                              }];
}

- (void)applyImage:(UIImage *)image {
    self.imageView.image = image;
    self.imageView.hidden = NO;
    self.placeholderView.hidden = YES;
    [self updateRetryInteraction];
}

// Only intercept taps (for retry) while the placeholder is showing — so taps on
// a loaded avatar fall through to the cell. A retry re-resolves a fresh URL, so
// it's offered even when the stored URL is missing or expired. Group avatars
// can't self-heal from a synthetic PK, so retry is 1:1-only.
- (void)updateRetryInteraction {
    self.userInteractionEnabled = self.imageView.hidden && self.currentPK.length > 0 && !self.isGroup;
}

- (void)spk_retryTapped {
    NSString *pk = self.currentPK;
    NSString *url = self.currentURL;
    if (!pk.length || !self.imageView.hidden || self.isGroup)
        return;

    [[SPKAvatarCache shared] invalidatePK:pk];
    __weak typeof(self) weakSelf = self;
    [[SPKAvatarCache shared] avatarForPK:pk
                               urlString:url
                            forceRefresh:YES
                              completion:^(UIImage *image) {
                                  __strong typeof(weakSelf) strongSelf = weakSelf;
                                  if (!strongSelf || !image)
                                      return;
                                  if (![strongSelf.currentPK isEqualToString:pk])
                                      return;
                                  [strongSelf applyImage:image];
                              }];
}

@end
