#import "SPKDeletedMessagesAvatarView.h"
#import "../../../AssetUtils.h"
#import "../../../Shared/Avatars/SPKAvatarCache.h"
#import "../../../Utils.h"
#import "../../../App/SPKPerfMeter.h"

@interface SPKDeletedMessagesAvatarView ()
@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) UIImageView *placeholderView;
@property (nonatomic, copy) NSString *currentPK;
@property (nonatomic, copy) NSString *currentURL;
// Default placeholder fills ~72% of the circle; the group glyph is pinned to its
// native 24pt so a small asset isn't upscaled.
@property (nonatomic, strong) NSLayoutConstraint *placeholderW;
@property (nonatomic, strong) NSLayoutConstraint *placeholderH;
@property (nonatomic, strong) NSLayoutConstraint *placeholderFixedW;
@property (nonatomic, strong) NSLayoutConstraint *placeholderFixedH;
@end

@implementation SPKDeletedMessagesAvatarView

- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.clipsToBounds = YES;
        self.backgroundColor = [SPKUtils SPKColor_InstagramTertiaryBackground];

        _placeholderView = [UIImageView new];
        _placeholderView.translatesAutoresizingMaskIntoConstraints = NO;
        _placeholderView.contentMode = UIViewContentModeScaleAspectFit;
        _placeholderView.tintColor = [SPKUtils SPKColor_InstagramSecondaryText];
        _placeholderView.image = [SPKAssetUtils instagramIconNamed:@"user_circle" pointSize:44.0 renderingMode:UIImageRenderingModeAlwaysTemplate];
        [self addSubview:_placeholderView];

        _imageView = [UIImageView new];
        _imageView.translatesAutoresizingMaskIntoConstraints = NO;
        _imageView.contentMode = UIViewContentModeScaleAspectFill;
        _imageView.clipsToBounds = YES;
        _imageView.hidden = YES;
        [self addSubview:_imageView];

        _placeholderW = [_placeholderView.widthAnchor constraintEqualToAnchor:self.widthAnchor multiplier:0.72];
        _placeholderH = [_placeholderView.heightAnchor constraintEqualToAnchor:self.heightAnchor multiplier:0.72];
        _placeholderFixedW = [_placeholderView.widthAnchor constraintEqualToConstant:24.0];
        _placeholderFixedH = [_placeholderView.heightAnchor constraintEqualToConstant:24.0];
        _placeholderW.active = YES;
        _placeholderH.active = YES;

        [NSLayoutConstraint activateConstraints:@[
            [_imageView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
            [_imageView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
            [_imageView.topAnchor constraintEqualToAnchor:self.topAnchor],
            [_imageView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
            [_placeholderView.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
            [_placeholderView.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        ]];

        UITapGestureRecognizer *retryTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(spk_retryTapped)];
        [self addGestureRecognizer:retryTap];
        self.userInteractionEnabled = NO;
    }
    return self;
}

- (void)layoutSubviews {
    SPK_PERF_SCOPE(@"SPKDeletedMessagesAvatarView.layoutSubviews");
    [super layoutSubviews];
    self.layer.cornerRadius = self.bounds.size.width / 2.0;
}

// Toggle the placeholder between the default ~72%-of-circle sizing and a fixed
// native 24pt (group glyph — avoid upscaling a small asset).
- (void)setPlaceholderFixed24:(BOOL)fixed {
    self.placeholderW.active = !fixed;
    self.placeholderH.active = !fixed;
    self.placeholderFixedW.active = fixed;
    self.placeholderFixedH.active = fixed;
}

- (void)prepareForReuse {
    self.currentPK = nil;
    self.currentURL = nil;
    self.imageView.image = nil;
    self.imageView.hidden = YES;
    self.placeholderView.hidden = NO;
    // Native 24pt glyph (the asset is 24px — don't upscale it and blur).
    [self setPlaceholderFixed24:YES];
    self.placeholderView.image = [SPKAssetUtils instagramIconNamed:@"user_circle" pointSize:24.0 renderingMode:UIImageRenderingModeAlwaysTemplate];
    [self updateRetryInteraction];
}

- (void)configureAsGroupWithThreadId:(NSString *)threadId photoURL:(NSString *)photoURL {
    // Filesystem-safe cache key (the cache only sanitizes "/", so avoid ":").
    NSString *cacheKey = threadId.length ? [@"grp_" stringByAppendingString:threadId] : nil;
    self.currentPK = cacheKey;
    self.currentURL = photoURL;

    // Native 24pt group glyph placeholder (don't upscale the small asset).
    UIImage *glyph = nil;
    for (NSString *name in @[ @"group", @"people", @"members" ]) {
        glyph = [SPKAssetUtils instagramIconNamed:name pointSize:24.0 renderingMode:UIImageRenderingModeAlwaysTemplate];
        if (glyph)
            break;
    }
    self.placeholderView.image = glyph ?: [SPKAssetUtils instagramIconNamed:@"user_circle" pointSize:24.0 renderingMode:UIImageRenderingModeAlwaysTemplate];
    [self setPlaceholderFixed24:YES];
    self.imageView.hidden = YES;
    self.placeholderView.hidden = NO;
    [self updateRetryInteraction];

    if (!photoURL.length || !cacheKey.length)
        return; // no custom photo — keep glyph

    UIImage *warm = [[SPKAvatarCache shared] cachedImageForPK:cacheKey];
    if (warm) {
        [self applyImage:warm];
        return;
    }

    __weak typeof(self) weakSelf = self;
    NSString *requested = cacheKey;
    [[SPKAvatarCache shared] avatarForPK:cacheKey
                               urlString:photoURL
                              completion:^(UIImage *image) {
                                  __strong typeof(weakSelf) strongSelf = weakSelf;
                                  if (!strongSelf || !image)
                                      return;
                                  if (![strongSelf.currentPK isEqualToString:requested])
                                      return;
                                  [strongSelf applyImage:image];
                              }];
}

- (void)configureWithPK:(NSString *)pk urlString:(NSString *)urlString {
    self.currentPK = pk;
    self.currentURL = urlString;
    // Native 24pt glyph (the asset is 24px — don't upscale it and blur).
    [self setPlaceholderFixed24:YES];
    self.placeholderView.image = [SPKAssetUtils instagramIconNamed:@"user_circle" pointSize:24.0 renderingMode:UIImageRenderingModeAlwaysTemplate];

    UIImage *warm = [[SPKAvatarCache shared] cachedImageForPK:pk];
    if (warm) {
        [self applyImage:warm];
        return;
    }

    self.imageView.hidden = YES;
    self.placeholderView.hidden = NO;
    [self updateRetryInteraction];

    __weak typeof(self) weakSelf = self;
    NSString *requestedPK = pk;
    [[SPKAvatarCache shared] avatarForPK:pk
                               urlString:urlString
                              completion:^(UIImage *image) {
                                  __strong typeof(weakSelf) strongSelf = weakSelf;
                                  if (!strongSelf || !image)
                                      return;
                                  // Guard against cell reuse — only apply if the view still wants this PK.
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

// Only intercept taps (for retry) while the grey placeholder is showing, and
// only for real user avatars — group threads can't be re-resolved, and taps on
// a loaded avatar should fall through to the cell. A retry re-resolves a fresh
// URL, so it's offered even when the stored URL is missing or expired.
- (void)updateRetryInteraction {
    BOOL retryable = self.currentPK.length > 0 && ![self.currentPK hasPrefix:@"grp_"];
    self.userInteractionEnabled = self.imageView.hidden && retryable;
}

- (void)spk_retryTapped {
    NSString *pk = self.currentPK;
    NSString *url = self.currentURL;
    if (!pk.length || [pk hasPrefix:@"grp_"] || !self.imageView.hidden)
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
