// Rewrites Instagram's copied share links into a cleaner canonical form.

#import "../../Utils.h"
#import <objc/runtime.h>
#import <substrate.h>

static BOOL SPKShouldSanitizeCopiedShareLinks(void) {
    return [SPKUtils getBoolPref:@"general_strip_share_link_tracking"];
}

// Returns a sanitized replacement ONLY when `string` is a plain Instagram
// share URL that actually changes. Any other text (arbitrary copied text,
// non-IG URLs, empty) returns nil so the original write passes through
// untouched. `sanitizedInstagramShareURL:` already returns nil for anything
// whose scheme isn't http/https or whose host isn't a canonical IG host, so
// this is the whole specificity gate.
static NSString *SPKSanitizedShareStringOrNil(NSString *string) {
    if (![string isKindOfClass:[NSString class]] || string.length == 0)
        return nil;
    NSURL *url = [NSURL URLWithString:string];
    if (!url)
        return nil;
    NSString *sanitized = [SPKUtils sanitizedInstagramShareURL:url].absoluteString;
    if (sanitized.length > 0 && ![sanitized isEqualToString:string])
        return sanitized;
    return nil;
}

static NSURL *SPKSanitizedShareURLOrNil(NSURL *url) {
    if (![url isKindOfClass:[NSURL class]])
        return nil;
    NSURL *sanitized = [SPKUtils sanitizedInstagramShareURL:url];
    if (sanitized.absoluteString.length > 0 && ![sanitized.absoluteString isEqualToString:url.absoluteString])
        return sanitized;
    return nil;
}

// The external share sheet ("Copy link") is the one surface where we can't see
// the value being written: IG 436+ routes every share button through Swift's
// `shareTo:` with an opaque enum and copies to the pasteboard internally. Here
// (and only here) we fall back to polling the clipboard, gated so it only
// rewrites when the clipboard actually changed AND now holds an IG URL.
static void SPKPollClipboardAndSanitize(NSInteger countBefore, int polls, double interval) {
    __block BOOL done = NO;
    for (int i = 0; i < polls; i++) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((interval + (i * interval)) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (done)
                return;
            if ([UIPasteboard generalPasteboard].changeCount == countBefore)
                return;

            NSString *string = [UIPasteboard generalPasteboard].string;
            NSString *sanitized = SPKSanitizedShareStringOrNil(string);
            if (sanitized) {
                [UIPasteboard generalPasteboard].string = sanitized;
            }
            done = YES;
        });
    }
}

static void (*orig_shareTo)(id, SEL, long long);
static void replaced_shareTo(id self, SEL _cmd, long long shareType) {
    if (!SPKShouldSanitizeCopiedShareLinks()) {
        orig_shareTo(self, _cmd, shareType);
        return;
    }
    NSInteger countBefore = [UIPasteboard generalPasteboard].changeCount;
    orig_shareTo(self, _cmd, shareType);
    SPKPollClipboardAndSanitize(countBefore, 30, 0.05);
}

// Direct-write copy surfaces (the profile "..." menu's "Copy Profile URL" row,
// long-press "Copy Link", etc.) write a plain string or URL straight to the
// pasteboard. We hook ONLY those typed setters and rewrite the argument in
// place before it lands. We deliberately do NOT hook the low-level item/object
// funnel (`_setItemsAndSave:options:...`, `setItems:`, `setObjects:`,
// `setValue:forPasteboardType:`, ...): that funnel is what WebKit routes its
// rich item-provider writes through when you copy text in the in-app browser,
// and intercepting it there crashed inside WebKit's data-owner context. Copy
// surfaces we care about never use it, so scoping to `setString:`/`setURL:`
// (and their array forms) makes the rewrite both crash-proof and specific:
// nothing but a plain IG URL write is ever touched.
static void (*orig_setString)(id, SEL, NSString *);
static void replaced_setString(id self, SEL _cmd, NSString *string) {
    if (SPKShouldSanitizeCopiedShareLinks()) {
        NSString *sanitized = SPKSanitizedShareStringOrNil(string);
        if (sanitized)
            string = sanitized;
    }
    orig_setString(self, _cmd, string);
}

static void (*orig_setURL)(id, SEL, NSURL *);
static void replaced_setURL(id self, SEL _cmd, NSURL *url) {
    if (SPKShouldSanitizeCopiedShareLinks()) {
        NSURL *sanitized = SPKSanitizedShareURLOrNil(url);
        if (sanitized)
            url = sanitized;
    }
    orig_setURL(self, _cmd, url);
}

static void (*orig_setStrings)(id, SEL, NSArray<NSString *> *);
static void replaced_setStrings(id self, SEL _cmd, NSArray<NSString *> *strings) {
    if (SPKShouldSanitizeCopiedShareLinks() && [strings isKindOfClass:[NSArray class]]) {
        __block BOOL changed = NO;
        NSMutableArray *rewritten = [NSMutableArray arrayWithCapacity:strings.count];
        for (NSString *string in strings) {
            NSString *sanitized = SPKSanitizedShareStringOrNil(string);
            [rewritten addObject:sanitized ?: (string ?: @"")];
            changed = changed || (sanitized != nil);
        }
        if (changed)
            strings = rewritten;
    }
    orig_setStrings(self, _cmd, strings);
}

static void (*orig_setURLs)(id, SEL, NSArray<NSURL *> *);
static void replaced_setURLs(id self, SEL _cmd, NSArray<NSURL *> *urls) {
    if (SPKShouldSanitizeCopiedShareLinks() && [urls isKindOfClass:[NSArray class]]) {
        __block BOOL changed = NO;
        NSMutableArray *rewritten = [NSMutableArray arrayWithCapacity:urls.count];
        for (NSURL *url in urls) {
            NSURL *sanitized = SPKSanitizedShareURLOrNil(url);
            [rewritten addObject:sanitized ?: url];
            changed = changed || (sanitized != nil);
        }
        if (changed)
            urls = rewritten;
    }
    orig_setURLs(self, _cmd, urls);
}

extern "C" void SPKInstallSharedLinkCleanupHooksIfEnabled(void) {
    if (!SPKShouldSanitizeCopiedShareLinks())
        return;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class shareCls = SPKResolveIGClass(@"IGExternalShareOptions.IGExternalShareOptionsViewController", @"IGExternalShareOptionsViewController");
        SEL shareSelector = NSSelectorFromString(@"shareTo:");
        if (shareCls && class_getInstanceMethod(shareCls, shareSelector)) {
            MSHookMessageEx(shareCls, shareSelector, (IMP)replaced_shareTo, (IMP *)&orig_shareTo);
        }

        // `generalPasteboard` returns an instance of this private concrete
        // subclass, which overrides the typed setters; hooking only the public
        // `UIPasteboard` base class is a no-op against it. Fall back to the base
        // class on older iOS where the concrete class doesn't exist.
        Class pasteboardCls = NSClassFromString(@"_UIConcretePasteboard");
        if (!pasteboardCls)
            pasteboardCls = [UIPasteboard class];
        if (!pasteboardCls)
            return;

#define SPK_INSTALL_PASTEBOARD_HOOK(sel, name)                                                   \
    do {                                                                                         \
        SEL selector = sel;                                                                      \
        if (class_getInstanceMethod(pasteboardCls, selector)) {                                  \
            MSHookMessageEx(pasteboardCls, selector, (IMP)replaced_##name, (IMP *)&orig_##name); \
        }                                                                                        \
    } while (0)

        SPK_INSTALL_PASTEBOARD_HOOK(@selector(setString:), setString);
        SPK_INSTALL_PASTEBOARD_HOOK(@selector(setURL:), setURL);
        SPK_INSTALL_PASTEBOARD_HOOK(@selector(setStrings:), setStrings);
        SPK_INSTALL_PASTEBOARD_HOOK(@selector(setURLs:), setURLs);

#undef SPK_INSTALL_PASTEBOARD_HOOK
    });
}
