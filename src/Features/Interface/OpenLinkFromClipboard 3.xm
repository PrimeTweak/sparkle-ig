#import <objc/runtime.h>

#import "../../InstagramHeaders.h"
#import "../../Utils.h"

static NSURL *SPKNormalizedInstagramClipboardURL(NSString *raw) {
    if (raw.length == 0)
        return nil;

    NSString *trimmed = [raw stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (trimmed.length == 0)
        return nil;
    if (![trimmed containsString:@"://"]) {
        trimmed = [@"https://" stringByAppendingString:trimmed];
    }

    NSURL *url = [NSURL URLWithString:trimmed];
    NSString *scheme = url.scheme.lowercaseString ?: @"";
    if ([scheme isEqualToString:@"instagram"]) {
        return url;
    }
    if (![scheme isEqualToString:@"http"] && ![scheme isEqualToString:@"https"]) {
        return nil;
    }

    NSString *host = url.host.lowercaseString ?: @"";
    if (host.length == 0)
        return nil;

    if ([host isEqualToString:@"instagram.com"] ||
        [host hasSuffix:@".instagram.com"] ||
        [host isEqualToString:@"instagr.am"] ||
        [host isEqualToString:@"ig.me"]) {
        return url;
    }

    if ([host containsString:@"instagram"]) {
        NSURLComponents *components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
        components.scheme = @"https";
        components.host = @"www.instagram.com";
        return components.URL;
    }

    return nil;
}

static BOOL SPKCanAttemptOpenInstagramClipboardURL(NSURL *url) {
    if (!url)
        return NO;

    NSString *scheme = url.scheme.lowercaseString ?: @"";
    if ([scheme isEqualToString:@"http"] || [scheme isEqualToString:@"https"]) {
        return url.host.length > 0;
    }

    if ([scheme isEqualToString:@"instagram"]) {
        UIApplication *application = [UIApplication sharedApplication];
        id<UIApplicationDelegate> delegate = application.delegate;
        return [application canOpenURL:url] || [delegate respondsToSelector:@selector(application:openURL:options:)];
    }

    return NO;
}

// Intercept the clipboard link at the moment IG's own long-press handler fires.
// Returns YES if we consumed the gesture (opened a link), NO to let IG open search.
static BOOL SPKHandleExploreLongPressClipboard(void) {
    if (![SPKUtils getBoolPref:@"interface_open_clipboard_link"]) {
        SPKLog(@"Interface", @"[Sparkle] Explore long-press: clipboard-link feature disabled, falling through to search");
        return NO;
    }

    NSString *clipboard = UIPasteboard.generalPasteboard.string;
    NSURL *url = SPKNormalizedInstagramClipboardURL(clipboard);
    if (!SPKCanAttemptOpenInstagramClipboardURL(url)) {
        SPKLog(@"Interface", @"[Sparkle] Explore long-press: clipboard (%@) is not an openable Instagram link, falling through to search", clipboard.length ? clipboard : @"<empty>");
        return NO;
    }

    if (![SPKUtils openInstagramMediaURL:url]) {
        SPKWarnLog(@"Interface", @"[Sparkle] Explore long-press: failed to open %@, falling through to search", url);
        return NO;
    }

    SPKLog(@"Interface", @"[Sparkle] Explore long-press: opened clipboard link %@", url);
    UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [feedback impactOccurred];
    return YES;
}

%group SPKOpenLinkFromClipboardHooks

%hook IGTabBarController

- (void)_exploreButtonLongPressed:(id)gesture {
    // IG's own long-press recognizer fires here (opening search). Only act on the
    // gesture's initial recognition so we don't re-open on every update callback.
    BOOL began = YES;
    if ([gesture isKindOfClass:[UIGestureRecognizer class]]) {
        began = ([(UIGestureRecognizer *)gesture state] == UIGestureRecognizerStateBegan);
    }

    if (began && SPKHandleExploreLongPressClipboard()) {
        return; // consumed: skip IG's search behavior
    }

    %orig;
}

%end

%end

extern "C" void SPKInstallOpenLinkFromClipboardHooksIfEnabled(void) {
    if (![SPKUtils getBoolPref:@"interface_open_clipboard_link"])
        return;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        %init(SPKOpenLinkFromClipboardHooks);
    });
}
