#import "../../Utils.h"
#import "../../InstagramHeaders.h"

// Asks before Instagram opens a link in its in-app browser.
//
// The confirmation shows the resolved address rather than the text that was
// tapped: a shortened link says nothing about where it leads, which is the
// whole reason for asking.

static NSString *const kSPKConfirmOpenLinkKey = @"general_confirm_open_link";

static BOOL SPKConfirmOpenLinkEnabled(void) {
    return [SPKUtils getBoolPref:kSPKConfirmOpenLinkKey];
}

// Set while the confirmed call is replayed, so the hook lets it through instead
// of asking a second time.
static BOOL SPKOpenLinkConfirmed = NO;

static NSURL *SPKURLFromLinkArgument(id url) {
    if ([url isKindOfClass:[NSURL class]])
        return (NSURL *)url;
    if ([url isKindOfClass:[NSString class]])
        return [NSURL URLWithString:(NSString *)url];
    return nil;
}

// Only external destinations are worth a prompt. Instagram routes its own
// screens through the same handler, and asking there would be noise.
static BOOL SPKLinkNeedsConfirmation(NSURL *url) {
    if (!url)
        return NO;
    NSString *scheme = url.scheme.lowercaseString;
    if (![scheme isEqualToString:@"http"] && ![scheme isEqualToString:@"https"])
        return NO;
    NSString *host = url.host.lowercaseString;
    if (!host.length)
        return NO;
    for (NSString *own in @[ @"instagram.com", @"facebook.com", @"threads.net", @"threads.com" ]) {
        if ([host isEqualToString:own] || [host hasSuffix:[@"." stringByAppendingString:own]])
            return NO;
    }
    return YES;
}

%group SPKExternalLinkConfirmHooks

%hook IGURLHandler

+ (void)openURL:(id)url userSession:(id)session completionHandler:(id)handler {
    NSURL *resolved = SPKURLFromLinkArgument(url);
    if (SPKOpenLinkConfirmed || !SPKConfirmOpenLinkEnabled() || !SPKLinkNeedsConfirmation(resolved)) {
        %orig;
        return;
    }

    id capturedURL = url;
    id capturedSession = session;
    id capturedHandler = handler;
    [SPKUtils showConfirmation:^{
        SPKOpenLinkConfirmed = YES;
        [%c(IGURLHandler) openURL:capturedURL userSession:capturedSession completionHandler:capturedHandler];
        SPKOpenLinkConfirmed = NO;
    }
                         title:@"Open this link"
                       message:resolved.absoluteString];
}

%end

%end

void SPKInstallExternalLinkConfirmHooksIfNeeded(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        %init(SPKExternalLinkConfirmHooks);
    });
}
