#import "../../InstagramHeaders.h"
#import "../../Utils.h"
#import "../ActionButton/ActionButtonCore.h"
#import "SPKAccountManager.h"

// Keeps SPKAccountManager's cached account in sync with in-app account switches,
// which don't background the app (so the foreground refresh never fires). We set
// the new account BEFORE %orig so the feed/UI that rebuilds during the switch
// already reads the correct per-account namespace, and refresh the action-button
// chrome so its icons reflect the new account immediately.
static void SPKAccountSwitchNotePK(NSString *pk) {
    if (pk.length == 0)
        return;
    [[SPKAccountManager shared] noteSwitchedToAccountPK:pk];
    [[NSNotificationCenter defaultCenter] postNotificationName:SPKActionButtonConfigurationDidChangeNotification object:nil];
}

%hook IGAccountSwitcher

- (long long)switchToUserWithPK:(id)pk
          destinationAppSurface:(id)surface
                 destinationURL:(id)url
                     entryPoint:(long long)point
                    loggingData:(id)data {
    NSString *pkString = [pk isKindOfClass:[NSString class]] ? pk : ([pk respondsToSelector:@selector(stringValue)] ? [pk stringValue] : [pk description]);
    SPKAccountSwitchNotePK(pkString);
    return %orig;
}

- (long long)switchToUser:(id)user
    destinationAppSurface:(id)surface
           destinationURL:(id)url
               entryPoint:(long long)point
              loggingData:(id)data {
    SPKAccountSwitchNotePK([SPKUtils pkFromIGUser:user]);
    return %orig;
}

%end

extern "C" void SPKInstallAccountSwitchHooksIfNeeded(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        %init;
    });
}
