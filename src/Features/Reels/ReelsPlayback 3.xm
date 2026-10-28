#import "../../Utils.h"

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

// * Disable volume/mute button triggering unmutes
%hook IGAudioStatusAnnouncer
- (void)_muteSwitchStateChanged:(id)changed {
    if (![SPKUtils getBoolPref:@"reels_disable_auto_unmute"]) {
        %orig(changed);
    }
}
- (void)_didPressVolumeButton:(id)button {
    if (![SPKUtils getBoolPref:@"reels_disable_auto_unmute"]) {
        %orig(button);
    }
}
- (void)_didUnplugHeadphones:(id)headphones {
    if (![SPKUtils getBoolPref:@"reels_disable_auto_unmute"]) {
        %orig(headphones);
    }
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
    });
}
