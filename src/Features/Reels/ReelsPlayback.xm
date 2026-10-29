#import "../../Utils.h"
#import <objc/message.h>

// Instagram keeps one sticky sound state for the app: 0 unset, 1 muted, 2 unmuted.
// While it is unset, reels pick sound on or off by themselves, so starting muted
// writes 1 whenever it is unset; a tap on a reel still writes 2 as usual.
static const long long kSPKStickySoundStateUnset = 0;
static const long long kSPKStickySoundStateMuted = 1;
static const long long kSPKStickySoundStateReason = 5; // what Instagram's own mute toggle passes

// The first activation after launch restores the previous session's state, so that
// one is overridden even when set; later ones only fill an unset state.
static BOOL sSPKReelsDidOverrideLaunchSoundState = NO;

static void SPKReelsApplyStartMuted(id announcer) {
    if (![SPKUtils getBoolPref:@"reels_disable_auto_unmute"])
        return;
    SEL getter = @selector(stickySoundState);
    SEL setter = @selector(setStickySoundState:forReason:);
    if (![announcer respondsToSelector:getter] || ![announcer respondsToSelector:setter])
        return;

    long long state = ((long long (*)(id, SEL))objc_msgSend)(announcer, getter);
    BOOL launch = !sSPKReelsDidOverrideLaunchSoundState;
    sSPKReelsDidOverrideLaunchSoundState = YES;
    if (state == kSPKStickySoundStateMuted || (!launch && state != kSPKStickySoundStateUnset))
        return;
    ((void (*)(id, SEL, long long, long long))objc_msgSend)(announcer, setter, kSPKStickySoundStateMuted, kSPKStickySoundStateReason);
}

%group SPKReelsPlaybackHooks

%hook IGSundialPlaybackControlsTestConfiguration
- (id)initWithLauncherSet:(id)set
                     tapToPauseEnabled:(_Bool)tapPauseEnabled
      combineSingleTapPlaybackControls:(_Bool)controls
        isVideoPreviewThumbnailEnabled:(_Bool)previewThumbEnabled
                minScrubberDurationSec:(long long)minSec
         seekResumeScrubberCooldownSec:(double)seekSec
          tapResumeScrubberCooldownSec:(double)tapSec
    persistentScrubberMinVideoDuration:(long long)duration
        isScrubberForShortVideoEnabled:(_Bool)shortScrubberEnabled {
    _Bool userTapPauseEnabled = tapPauseEnabled;
    if ([[SPKUtils getStringPref:@"reels_tap_control"] isEqualToString:@"pause"])
        userTapPauseEnabled = true;
    else if ([[SPKUtils getStringPref:@"reels_tap_control"] isEqualToString:@"mute"])
        userTapPauseEnabled = false;

    long long userMinSec = minSec;
    long long userDuration = duration;
    _Bool userShortScrubberEnabled = shortScrubberEnabled;
    if ([SPKUtils getBoolPref:@"reels_show_scrubber"]) {
        userMinSec = 0;
        userDuration = 0;
        userShortScrubberEnabled = true;
    }

    return %orig(set, userTapPauseEnabled, controls, previewThumbEnabled, userMinSec, seekSec, tapSec, userDuration, userShortScrubberEnabled);
}
%end

%hook IGSundialFeedViewController
- (void)_refreshReelsWithParamsForNetworkRequest:(NSInteger)arg1 userDidPullToRefresh:(BOOL)arg2 {
    if ([SPKUtils getBoolPref:@"reels_prevent_doom_scroll"] && arg2) {
        IGRefreshControl *_refreshControl = MSHookIvar<IGRefreshControl *>(self, "_refreshControl");
        [_refreshControl finishLoading];
        if ([self respondsToSelector:@selector(finishPullToRefreshLoading)]) {
            [self finishPullToRefreshLoading];
        }

        return;
    }

    if ([SPKUtils getBoolPref:@"reels_confirm_refresh"] && arg2) {
        SPKLog(@"General", @"[Sparkle] Reel refresh triggered");

        [SPKUtils
            showConfirmation:^(void) {
                %orig(arg1, arg2);
            }
            cancelHandler:^(void) {
                IGRefreshControl *_refreshControl = MSHookIvar<IGRefreshControl *>(self, "_refreshControl");
                [_refreshControl finishLoading];
                if ([self respondsToSelector:@selector(finishPullToRefreshLoading)]) {
                    [self finishPullToRefreshLoading];
                }
            }
            title:@"Confirm Reels Refresh"
            message:@"The feed reloads and your place in it is lost."];
    } else {
        return %orig(arg1, arg2);
    }
}

- (void)triggerRefreshFromTabTap {
    if ([SPKUtils getBoolPref:@"reels_confirm_refresh"]) {
        [SPKUtils
            showConfirmation:^(void) {
                %orig;
            }
               cancelHandler:nil
                       title:@"Confirm Reels Refresh"
                     message:@"The feed reloads and your place in it is lost."];
    } else {
        %orig;
    }
}
%end

// Volume presses, the ringer switch and unplugging headphones write the sticky
// state themselves and are left alone, so starting muted never locks sound off.
%hook IGAudioStatusAnnouncer
// Where Instagram restores the last session's sound state or resets it.
- (void)_applicationDidBecomeActive {
    %orig;
    SPKReelsApplyStartMuted(self);
}
%end

%end

extern "C" void SPKInstallReelsPlaybackHooksIfNeeded(void) {
    BOOL shouldInstall = ![[SPKUtils getStringPref:@"reels_tap_control"] isEqualToString:@"default"] ||
                         [SPKUtils getBoolPref:@"reels_show_scrubber"] ||
                         [SPKUtils getBoolPref:@"reels_prevent_doom_scroll"] ||
                         [SPKUtils getBoolPref:@"reels_confirm_refresh"] ||
                         [SPKUtils getBoolPref:@"reels_disable_auto_unmute"];
    if (!shouldInstall)
        return;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        %init(SPKReelsPlaybackHooks);

        // Surface hooks install after launch, usually past the first activation.
        if (UIApplication.sharedApplication.applicationState != UIApplicationStateActive)
            return;
        Class announcerClass = NSClassFromString(@"IGAudioStatusAnnouncer");
        SEL shared = NSSelectorFromString(@"sharedInstance");
        if ([announcerClass respondsToSelector:shared])
            SPKReelsApplyStartMuted(((id (*)(id, SEL))objc_msgSend)(announcerClass, shared));
    });
}
