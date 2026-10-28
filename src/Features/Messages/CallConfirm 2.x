#import "../../Utils.h"

static NSString *const kSPKAudioCallConfirmKey = @"msgs_confirm_audio_call";
static NSString *const kSPKVideoCallConfirmKey = @"msgs_confirm_video_call";

static BOOL SPKShouldConfirmCall(NSString *key) {
    return [SPKUtils getBoolPref:key];
}

%group SPKCallConfirmHooks

%hook IGDirectThreadCallButtonsCoordinator
// Voice Call
- (void)_didTapAudioButton {
    if (SPKShouldConfirmCall(kSPKAudioCallConfirmKey)) {
        SPKLog(@"General", @"[Sparkle] Call confirm triggered");

        [SPKUtils
            showConfirmation:^(void) {
                %orig;
            }
                       title:@"Start audio call"
                     message:@"The call starts as soon as you confirm."];
    } else {
        return %orig;
    }
}

- (void)_didTapAudioButton:(id)arg1 {
    if (SPKShouldConfirmCall(kSPKAudioCallConfirmKey)) {
        SPKLog(@"General", @"[Sparkle] Call confirm triggered");

        [SPKUtils
            showConfirmation:^(void) {
                %orig;
            }
                       title:@"Start audio call"
                     message:@"The call starts as soon as you confirm."];
    } else {
        return %orig;
    }
}

// Video Call
- (void)_didTapVideoButton {
    if (SPKShouldConfirmCall(kSPKVideoCallConfirmKey)) {
        SPKLog(@"General", @"[Sparkle] Call confirm triggered");

        [SPKUtils
            showConfirmation:^(void) {
                %orig;
            }
                       title:@"Start video call"
                     message:@"The call starts as soon as you confirm."];
    } else {
        return %orig;
    }
}

- (void)_didTapVideoButton:(id)arg1 {
    if (SPKShouldConfirmCall(kSPKVideoCallConfirmKey)) {
        SPKLog(@"General", @"[Sparkle] Call confirm triggered");

        [SPKUtils
            showConfirmation:^(void) {
                %orig;
            }
                       title:@"Start video call"
                     message:@"The call starts as soon as you confirm."];
    } else {
        return %orig;
    }
}
%end

%end

void SPKInstallCallConfirmHooksIfEnabled(void) {
    if (!SPKShouldConfirmCall(kSPKAudioCallConfirmKey) && !SPKShouldConfirmCall(kSPKVideoCallConfirmKey))
        return;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        %init(SPKCallConfirmHooks);
    });
}
