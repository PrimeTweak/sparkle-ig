#import "../../InstagramHeaders.h"
#import "../../Utils.h"

%group SPKCopyDescriptionHooks

%hook IGCoreTextView
- (void)didMoveToSuperview {
    %orig;

    if ([SPKUtils getBoolPref:@"general_copy_text"]) {
        [self addHandleLongPress];
    }

    return;
}
%new - (void)addHandleLongPress {
UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
longPress.minimumPressDuration = 0.5;
[self addGestureRecognizer:longPress];
}

%new - (void)handleLongPress:(UILongPressGestureRecognizer *)sender {
if (sender.state != UIGestureRecognizerStateBegan)
    return;

// Remove hashtags at end of string
NSRegularExpression *regex =
    [NSRegularExpression regularExpressionWithPattern:@"\\s*(?:#[^\\s]+\\s*)+$"
                                              options:0
                                                error:nil];

NSString *result = [[regex stringByReplacingMatchesInString:self.text
                                                    options:0
                                                      range:NSMakeRange(0, self.text.length)
                                               withTemplate:@""]
    stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

SPKLog(@"General", @"[Sparkle] Copying description");

// Copy text to system clipboard
UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
pasteboard.string = result;

SPKNotify(kSPKNotificationCopyDescription, @"Copied text to clipboard", nil, @"circle_check_filled", SPKNotificationToneSuccess);
}
%end

%end

void SPKInstallCopyDescriptionHooksIfEnabled(void) {
    if (![SPKUtils getBoolPref:@"general_copy_text"])
        return;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        %init(SPKCopyDescriptionHooks);
    });
}
