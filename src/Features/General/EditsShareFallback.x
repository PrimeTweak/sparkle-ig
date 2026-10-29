// Edits shares a video through a Meta app group that a re-signed Instagram cannot
// read, so the handoff fails without any UI. An explanation replaces that silence;
// a readable handoff (stock entitlements) is left alone.

#import "../../InstagramHeaders.h"
#import "../../Shared/UI/SPKDialog.h"
#import "../../Utils.h"

#import <UIKit/UIKit.h>

typedef struct __SecTask *SecTaskRef;
extern SecTaskRef SecTaskCreateFromSelf(CFAllocatorRef allocator);
extern CFTypeRef SecTaskCopyValueForEntitlement(SecTaskRef task, CFStringRef entitlement, CFErrorRef *error);

// A cold launch can deliver the same URL through both hooks.
static BOOL spk_editsShareAlertPending = NO;

// Group container lookups get a private stand-in from the sideload shim, so only
// the signed application-groups entitlement tells whether the read can succeed.
static BOOL SPKEditsShareHandoffIsReadable(void) {
    static BOOL entitled = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        SecTaskRef task = SecTaskCreateFromSelf(kCFAllocatorDefault);
        if (!task)
            return;
        id groups = CFBridgingRelease(SecTaskCopyValueForEntitlement(task, CFSTR("com.apple.security.application-groups"), NULL));
        CFRelease(task);
        entitled = [groups isKindOfClass:[NSArray class]] && [(NSArray *)groups containsObject:@"group.com.facebook.family"];
    });
    return entitled;
}

static void SPKEditsSharePresentAlert(void) {
    // On a cold launch the URL arrives before there is anything to present from.
    if ([UIApplication sharedApplication].applicationState != UIApplicationStateActive) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            SPKEditsSharePresentAlert();
        });
        return;
    }
    spk_editsShareAlertPending = NO;
    [SPKDialog presentFromController:topMostController()
                               title:@"Can't share from Edits"
                             message:@"Edits passes the video through storage that only the App Store version of Instagram can read. Save the video to Photos in Edits, then post it from Instagram."
                             actions:@[ [SPKDialogAction actionWithTitle:@"OK" style:SPKDialogActionStyleDefault handler:nil] ]];
}

// YES when the URL is an Edits handoff this process cannot read.
static BOOL SPKEditsShareInterceptURL(NSURL *url) {
    if (![url isKindOfClass:[NSURL class]] ||
        ![url.scheme.lowercaseString isEqualToString:@"instagram"] ||
        ![url.host.lowercaseString isEqualToString:@"basel_share"] ||
        SPKEditsShareHandoffIsReadable()) {
        return NO;
    }
    if (!spk_editsShareAlertPending) {
        spk_editsShareAlertPending = YES;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            SPKEditsSharePresentAlert();
        });
    }
    return YES;
}

%group SPKEditsShareFallback

%hook IGAppCoordinator

// Warm opens: the scene delegate forwards its URL contexts here.
- (BOOL)application:(id)application openURL:(NSURL *)url options:(id)options {
    if (SPKEditsShareInterceptURL(url))
        return YES;
    return %orig;
}

- (void)scene:(UIScene *)scene willConnectToSession:(id)session options:(UISceneConnectionOptions *)options window:(id)window {
    %orig;
    if (![options isKindOfClass:[UISceneConnectionOptions class]])
        return;
    for (UIOpenURLContext *context in options.URLContexts) {
        SPKEditsShareInterceptURL(context.URL);
    }
}

%end

%end

void SPKInstallEditsShareFallbackHooksIfNeeded(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if (objc_getClass("IGAppCoordinator")) {
            %init(SPKEditsShareFallback);
        }
    });
}
