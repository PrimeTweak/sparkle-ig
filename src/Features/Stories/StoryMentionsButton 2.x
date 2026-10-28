#import <objc/message.h>
#import <objc/runtime.h>
#import <substrate.h>

#import "../../AssetUtils.h"
#import "../../InstagramHeaders.h"
#import "../../Shared/Messages/SPKDirectSeenContext.h"
#import "../../Shared/Stories/SPKStoryContext.h"
#import "../../Shared/Stories/SPKStoryDynamicRange.h"
#import "../../Shared/UI/SPKChrome.h"
#import "../../Tweak.h"
#import "../../Utils.h"

#ifdef __cplusplus
extern "C" {
#endif
void SPKApplyButtonStyle(UIButton *button, NSInteger source);
#ifdef __cplusplus
}
#endif

static NSString *const kSPKStoryMentionsBarIconResource = @"mention";
static NSInteger const kSPKActionButtonSourceDirect = 4;
static NSInteger const kSPKStoryMentionsButtonTag = 926002;

extern void SPKPresentStoryMentionsSheet(UIView *overlayView);

static id SPKKVCObject(id target, NSString *key);
static id SPKObjectForSelector(id target, NSString *selectorName);
static id SPKFirstObjectForSelectors(id target, NSArray<NSString *> *selectors);

static inline BOOL SPKStoryMentionsButtonEnabled(void) {
    return [SPKUtils getBoolPref:@"stories_mentions_btn"];
}
static NSArray *SPKArrayFromCollection(id collection) {
    if (!collection ||
        [collection isKindOfClass:[NSDictionary class]] ||
        [collection isKindOfClass:[NSString class]] ||
        [collection isKindOfClass:[NSURL class]]) {
        return nil;
    }

    if ([collection isKindOfClass:[NSArray class]]) {
        return collection;
    }

    if ([collection isKindOfClass:[NSOrderedSet class]]) {
        return [(NSOrderedSet *)collection array];
    }

    if ([collection isKindOfClass:[NSSet class]]) {
        return [(NSSet *)collection allObjects];
    }

    if ([collection conformsToProtocol:@protocol(NSFastEnumeration)]) {
        NSMutableArray *array = [NSMutableArray array];
        for (id item in collection) {
            [array addObject:item];
        }
        return array;
    }

    return nil;
}

static id SPKKVCObject(id target, NSString *key) {
    if (!target || key.length == 0)
        return nil;

    @try {
        return [target valueForKey:key];
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

static id SPKObjectForSelector(id target, NSString *selectorName) {
    if (!target || selectorName.length == 0)
        return nil;

    SEL selector = NSSelectorFromString(selectorName);
    if (![target respondsToSelector:selector])
        return nil;

    return ((id (*)(id, SEL))objc_msgSend)(target, selector);
}

static id SPKFirstObjectForSelectors(id target, NSArray<NSString *> *selectors) {
    if (!target || selectors.count == 0)
        return nil;
    for (NSString *selectorName in selectors) {
        id value = SPKObjectForSelector(target, selectorName);
        if (value)
            return value;
    }
    return nil;
}

static void SPKPlayButtonTappedHaptic(void) {
    UISelectionFeedbackGenerator *feedback = [UISelectionFeedbackGenerator new];
    [feedback selectionChanged];
}
static UIButton *SPKStorySeenButtonWithTag(UIView *container, NSInteger tag) {
    UIView *existing = [container viewWithTag:tag];
    if ([existing isKindOfClass:SPKChromeButton.class]) {
        return (UIButton *)existing;
    }
    [existing removeFromSuperview];

    SPKChromeButton *button = [[SPKChromeButton alloc] initWithSymbol:@"" pointSize:24.0 diameter:44.0];
    button.tag = tag;
    button.adjustsImageWhenHighlighted = YES;
    button.showsMenuAsPrimaryAction = NO;
    button.clipsToBounds = NO;
    [container addSubview:button];
    return button;
}

static void SPKSetSeenButtonImage(UIButton *button, UIImage *image, NSString *logMessage) {
    UIImage *templatedImage = [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    if ([button isKindOfClass:SPKChromeButton.class]) {
        SPKChromeButton *chromeButton = (SPKChromeButton *)button;
        chromeButton.iconView.image = templatedImage;
        chromeButton.iconTint = UIColor.whiteColor;
        [button setImage:nil forState:UIControlStateNormal];
    } else {
        [button setImage:templatedImage forState:UIControlStateNormal];
    }

    SPKLog(@"Capture", @"%@ tag=%ld button=%@<%p> subviews=%@ imageView=%@<%p> imageSuperview=%@<%p>",
           logMessage,
           (long)button.tag,
           NSStringFromClass(button.class),
           button,
           button.subviews,
           NSStringFromClass(button.imageView.class),
           button.imageView,
           NSStringFromClass(button.imageView.superview.class),
           button.imageView.superview);
}

static id SPKStorySectionControllerFromOverlayView(UIView *overlayView) {
    if (!overlayView)
        return nil;

    NSArray<NSString *> *delegateSelectors = @[ @"mediaOverlayDelegate", @"retryDelegate", @"tappableOverlayDelegate", @"buttonDelegate" ];
    Class sectionControllerClass = NSClassFromString(@"IGStoryFullscreenSectionController");

    for (NSString *selectorName in delegateSelectors) {
        SEL selector = NSSelectorFromString(selectorName);
        if (![overlayView respondsToSelector:selector])
            continue;

        id delegate = ((id (*)(id, SEL))objc_msgSend)(overlayView, selector);
        if (!delegate)
            continue;

        if (!sectionControllerClass || [delegate isKindOfClass:sectionControllerClass]) {
            return delegate;
        }
    }

    return nil;
}

static NSString *SPKStringFromValue(id value) {
    if (!value || value == (id)kCFNull)
        return nil;
    if ([value isKindOfClass:[NSString class]]) {
        NSString *string = (NSString *)value;
        return string.length > 0 ? string : nil;
    }
    if ([value respondsToSelector:@selector(stringValue)]) {
        NSString *string = [value stringValue];
        return string.length > 0 ? string : nil;
    }
    return [[value description] length] > 0 ? [value description] : nil;
}

static id SPKStoryMediaFromAnyObject(id object) {
    if (!object)
        return nil;
    id candidate = SPKFirstObjectForSelectors(object, @[ @"media", @"mediaItem", @"storyItem", @"item", @"model" ]);
    return candidate ?: object;
}

static BOOL SPKResolveStoryContextFromOverlay(UIView *overlayView, id *outMarkTarget, id *outSectionController, id *outMedia) {
    SPKStoryContext *sharedContext = SPKStoryContextFromOverlay(overlayView);
    if (sharedContext) {
        if (outMarkTarget)
            *outMarkTarget = sharedContext.markSeenTarget;
        if (outSectionController)
            *outSectionController = sharedContext.sectionController;
        if (outMedia)
            *outMedia = sharedContext.media;
        return (sharedContext.media != nil);
    }

    if (!overlayView)
        return NO;

    SEL markSelector = NSSelectorFromString(@"fullscreenSectionController:didMarkItemAsSeen:");
    UIViewController *viewerController = [SPKUtils nearestViewControllerForView:overlayView];

    id sectionController = SPKStorySectionControllerFromOverlayView(overlayView);
    id markTarget = nil;
    id sectionDelegate = SPKObjectForSelector(sectionController, @"delegate");
    if (sectionDelegate && [sectionDelegate respondsToSelector:markSelector]) {
        markTarget = sectionDelegate;
    } else if (viewerController && [viewerController respondsToSelector:markSelector]) {
        markTarget = viewerController;
    } else {
        id overlayAncestor = SPKObjectForSelector(overlayView, @"_viewControllerForAncestor");
        if (overlayAncestor && [overlayAncestor respondsToSelector:markSelector]) {
            markTarget = overlayAncestor;
        }
    }

    if (!sectionController && markTarget) {
        sectionController = SPKFirstObjectForSelectors(markTarget, @[ @"currentSectionController" ]);
        if (!sectionController) {
            sectionController = [SPKUtils getIvarForObj:markTarget name:"_currentSectionController"];
        }
    }

    id media = SPKFirstObjectForSelectors(sectionController, @[ @"currentStoryItem", @"currentItem", @"item" ]);
    if (!media)
        media = SPKFirstObjectForSelectors(markTarget, @[ @"currentStoryItem", @"currentItem", @"item" ]);
    if (!media && viewerController)
        media = SPKFirstObjectForSelectors(viewerController, @[ @"currentStoryItem", @"currentItem", @"item" ]);
    media = SPKStoryMediaFromAnyObject(media);

    if (outMarkTarget)
        *outMarkTarget = markTarget;
    if (outSectionController)
        *outSectionController = sectionController;
    if (outMedia)
        *outMedia = media;

    return (media != nil);
}

static NSArray<NSDictionary *> *SPKStoryMentionsForOverlay(UIView *overlayView) {
    id markTarget = nil;
    id sectionController = nil;
    id media = nil;
    if (!SPKResolveStoryContextFromOverlay(overlayView, &markTarget, &sectionController, &media)) {
        return @[];
    }

    id mentionsCollection = SPKObjectForSelector(media, @"reelMentions");
    NSArray *mentions = SPKArrayFromCollection(mentionsCollection);
    if (mentions.count == 0)
        return @[];

    NSMutableArray<NSDictionary *> *userInfos = [NSMutableArray array];
    for (id mention in mentions) {
        id user = SPKKVCObject(mention, @"user");
        if (!user)
            user = SPKObjectForSelector(mention, @"user");
        if (!user)
            continue;

        NSString *username = SPKStringFromValue(SPKKVCObject(user, @"username"));
        if (!username)
            username = SPKStringFromValue(SPKObjectForSelector(user, @"username"));
        NSString *fullName = SPKStringFromValue(SPKKVCObject(user, @"fullName"));
        if (!fullName)
            fullName = SPKStringFromValue(SPKKVCObject(user, @"full_name"));

        NSMutableDictionary *entry = [NSMutableDictionary dictionary];
        if (username.length > 0)
            entry[@"username"] = username;
        if (fullName.length > 0)
            entry[@"fullName"] = fullName;
        if (entry.count > 0)
            [userInfos addObject:entry];
    }

    return userInfos;
}

static void SPKApplyStoryMentionsButtonStyle(UIButton *button) {
    if (!button)
        return;
    SPKApplyButtonStyle(button, kSPKActionButtonSourceDirect);
    SPKStoryApplyDynamicRangeToButton(button);
}

void SPKRemoveStoryMentionsButton(UIView *overlayView) {
    UIButton *mentionsButton = (UIButton *)[overlayView viewWithTag:kSPKStoryMentionsButtonTag];
    [mentionsButton removeFromSuperview];
}

void SPKUpdateStoryMentionsButton(UIView *overlayView, CGFloat x, CGFloat y, CGFloat size) {
    NSArray<NSDictionary *> *storyMentions = SPKStoryMentionsForOverlay(overlayView);
    BOOL showMentionsButton = SPKStoryMentionsButtonEnabled() && storyMentions.count > 0;
    UIButton *mentionsButton = (UIButton *)[overlayView viewWithTag:kSPKStoryMentionsButtonTag];

    if (showMentionsButton && !mentionsButton) {
        mentionsButton = SPKStorySeenButtonWithTag(overlayView, kSPKStoryMentionsButtonTag);
        [mentionsButton addTarget:overlayView action:@selector(spk_storyMentionsButtonTapped:) forControlEvents:UIControlEventTouchUpInside];

        UIImage *mentionsImage = [SPKAssetUtils instagramIconNamed:kSPKStoryMentionsBarIconResource pointSize:24.0];
        SPKSetSeenButtonImage(mentionsButton, mentionsImage, @"Story mentions custom icon assigned");
    } else if (!showMentionsButton && mentionsButton) {
        [mentionsButton removeFromSuperview];
        mentionsButton = nil;
    }

    if (!showMentionsButton || !mentionsButton)
        return;
    SPKApplyStoryMentionsButtonStyle(mentionsButton);
    mentionsButton.frame = CGRectMake(x, y, size, size);
    [overlayView bringSubviewToFront:mentionsButton];
}

%group SPKStoryMentionsButtonHooks

%hook IGStoryFullscreenOverlayView
%new - (void)spk_storyMentionsButtonTapped:(UIButton *)sender {
(void)sender;
SPKPlayButtonTappedHaptic();
SPKPresentStoryMentionsSheet((UIView *)self);
}
%end

%end

void SPKInstallStoryMentionsButtonHooksIfNeeded(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        %init(SPKStoryMentionsButtonHooks);
    });
}
