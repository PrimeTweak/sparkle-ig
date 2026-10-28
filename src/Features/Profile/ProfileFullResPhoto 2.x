#import "../../Utils.h"
#import "../../InstagramHeaders.h"
#import "../../Shared/ActionButton/ActionButtonLookupUtils.h"
#import <objc/runtime.h>

// Loads the profile header's avatar at full resolution.
//
// Instagram serves a small square for the header and keeps the original behind
// hdProfilePicUrlInfo. Expand Photo already reaches for that when the picture is
// opened; this does it for the header itself, where the difference shows on a
// high-density screen.
//
// The swap runs once per view: the image is fetched, cached against the view,
// and reapplied on later layout passes without another request.

static NSString *const kSPKProfileFullResPhotoKey = @"profile_full_res_photo";
static const void *kSPKFullResURLAssocKey = &kSPKFullResURLAssocKey;
static const void *kSPKFullResImageAssocKey = &kSPKFullResImageAssocKey;

static BOOL SPKProfileFullResPhotoEnabled(void) {
    return [SPKUtils getBoolPref:kSPKProfileFullResPhotoKey];
}

static UIImageView *SPKAvatarImageView(UIView *root) {
    if ([root isKindOfClass:[UIImageView class]])
        return (UIImageView *)root;
    for (UIView *sub in root.subviews) {
        UIImageView *found = SPKAvatarImageView(sub);
        if (found)
            return found;
    }
    return nil;
}

static void SPKApplyFullResAvatar(UIView *view, id user) {
    NSURL *url = [SPKUtils getBestProfilePictureURLForUser:user];
    if (!url)
        return;

    UIImage *cached = objc_getAssociatedObject(view, kSPKFullResImageAssocKey);
    NSURL *cachedURL = objc_getAssociatedObject(view, kSPKFullResURLAssocKey);
    UIImageView *target = SPKAvatarImageView(view);
    if (!target)
        return;

    if (cached && [cachedURL.absoluteString isEqualToString:url.absoluteString]) {
        if (target.image != cached)
            target.image = cached;
        return;
    }
    if (cachedURL && [cachedURL.absoluteString isEqualToString:url.absoluteString])
        return;   // already in flight for this URL

    objc_setAssociatedObject(view, kSPKFullResURLAssocKey, url, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    __weak UIView *weakView = view;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        NSData *data = [NSData dataWithContentsOfURL:url];
        UIImage *image = data.length > 0 ? [UIImage imageWithData:data] : nil;
        if (!image)
            return;
        dispatch_async(dispatch_get_main_queue(), ^{
            UIView *strongView = weakView;
            if (!strongView)
                return;
            objc_setAssociatedObject(strongView, kSPKFullResImageAssocKey, image, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            UIImageView *imageView = SPKAvatarImageView(strongView);
            imageView.image = image;
        });
    });
}

%group SPKProfileFullResPhotoHooks

%hook IGProfilePhotoView

- (void)layoutSubviews {
    %orig;
    if (!SPKProfileFullResPhotoEnabled())
        return;
    UIViewController *controller = [SPKUtils nearestViewControllerForView:(UIView *)self];
    if (![controller isKindOfClass:%c(IGProfileViewController)])
        return;
    SPKApplyFullResAvatar((UIView *)self, SPKObjectForSelector(controller, @"user"));
}

%end

%hook IGProfileAvatarView

- (void)layoutSubviews {
    %orig;
    if (!SPKProfileFullResPhotoEnabled())
        return;
    UIViewController *controller = [SPKUtils nearestViewControllerForView:(UIView *)self];
    if (![controller isKindOfClass:%c(IGProfileViewController)])
        return;
    SPKApplyFullResAvatar((UIView *)self, SPKObjectForSelector(controller, @"user"));
}

%end

%end

void SPKInstallProfileFullResPhotoHooksIfEnabled(void) {
    if (!SPKProfileFullResPhotoEnabled())
        return;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        %init(SPKProfileFullResPhotoHooks);
    });
}
