#import "../../Utils.h"

#import <Foundation/Foundation.h>

%group SPKHideTestFlightNagReceipt
%hook NSBundle

- (NSURL *)appStoreReceiptURL {
    NSURL *url = %orig;
    if (self == NSBundle.mainBundle && [url.lastPathComponent isEqualToString:@"sandboxReceipt"]) {
        return [[url URLByDeletingLastPathComponent] URLByAppendingPathComponent:@"receipt"];
    }
    return url;
}

%end
%end

%ctor {
    BOOL shouldInit = YES;
#if SPK_DEV
    shouldInit = [SPKUtils getBoolPref:@"tools_hide_testflight_popup"];
#endif

    if (shouldInit) {
        %init(SPKHideTestFlightNagReceipt);
    }
}

