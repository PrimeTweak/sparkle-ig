#import <objc/runtime.h>
#import <substrate.h>

#import "../../Utils.h"

static NSString *const kSPKDMVoiceMessageConfirmPref = @"msgs_confirm_voice_msg";

typedef void (*SPKDMVoiceNoArgIMP)(id, SEL);
typedef void (*SPKDMVoiceLegacyRecordedIMP)(id, SEL, id, id, id, double, long long);
typedef void (*SPKDMVoiceRecordedIMP)(id, SEL, id, id, id, double, long long, id, id, long long);
typedef void (*SPKDMVoicePreviewSendIMP)(id, SEL, id, id, double, long long, id, id);

static SPKDMVoiceLegacyRecordedIMP orig_threadViewLegacyRecordedAudioClip = NULL;
static SPKDMVoiceRecordedIMP orig_threadViewRecordedAudioClip = NULL;
static SPKDMVoiceRecordedIMP orig_voiceControllerRecordedAudioClip = NULL;
static SPKDMVoicePreviewSendIMP orig_voiceRecordPreviewDidTapSend = NULL;
static SPKDMVoiceNoArgIMP orig_voiceRecordPreviewSendButton = NULL;
static SPKDMVoiceNoArgIMP orig_aiVoiceCompactBarDidTapSend = NULL;

static BOOL sSPKDMVoiceConfirmBypassing = NO;
static BOOL sSPKDMVoiceConfirmVisible = NO;

static BOOL SPKDMShouldConfirmVoiceMessage(void) {
    return [SPKUtils getBoolPref:kSPKDMVoiceMessageConfirmPref];
}

void SPKDMConfirmVoiceMessageIfNeeded(void (^confirmBlock)(void), void (^cancelBlock)(void)) {
    if (sSPKDMVoiceConfirmBypassing || !SPKDMShouldConfirmVoiceMessage()) {
        if (confirmBlock)
            confirmBlock();
        return;
    }

    if (sSPKDMVoiceConfirmVisible)
        return;

    sSPKDMVoiceConfirmVisible = YES;
    SPKLog(@"General", @"[Sparkle] DM audio message confirm triggered");
    [SPKUtils
        showConfirmation:^{
            sSPKDMVoiceConfirmVisible = NO;
            sSPKDMVoiceConfirmBypassing = YES;
            if (confirmBlock)
                confirmBlock();
            sSPKDMVoiceConfirmBypassing = NO;
        }
        cancelHandler:^{
            sSPKDMVoiceConfirmVisible = NO;
            if (cancelBlock)
                cancelBlock();
        }
        title:@"Confirm Sending Voice Message"
        message:@"The recording is sent as soon as you confirm."];
}

static void SPKDMConfirmVoiceMessage(void (^confirmBlock)(void)) {
    SPKDMConfirmVoiceMessageIfNeeded(confirmBlock, nil);
}

static void replaced_threadViewLegacyRecordedAudioClip(id self, SEL _cmd, id controller, id url, id waveform, double duration, long long entryPoint) {
    SPKDMConfirmVoiceMessage(^{
        if (orig_threadViewLegacyRecordedAudioClip) {
            orig_threadViewLegacyRecordedAudioClip(self, _cmd, controller, url, waveform, duration, entryPoint);
        }
    });
}

static void replaced_threadViewRecordedAudioClip(id self, SEL _cmd, id controller, id url, id waveform, double duration, long long entryPoint, id aiVoiceEffectApplied, id aiVoiceEffectType, long long sendButtonTypeTapped) {
    SPKDMConfirmVoiceMessage(^{
        if (orig_threadViewRecordedAudioClip) {
            orig_threadViewRecordedAudioClip(self, _cmd, controller, url, waveform, duration, entryPoint, aiVoiceEffectApplied, aiVoiceEffectType, sendButtonTypeTapped);
        }
    });
}

static void replaced_voiceControllerRecordedAudioClip(id self, SEL _cmd, id controller, id url, id waveform, double duration, long long entryPoint, id aiVoiceEffectApplied, id aiVoiceEffectType, long long sendButtonTypeTapped) {
    SPKDMConfirmVoiceMessage(^{
        if (orig_voiceControllerRecordedAudioClip) {
            orig_voiceControllerRecordedAudioClip(self, _cmd, controller, url, waveform, duration, entryPoint, aiVoiceEffectApplied, aiVoiceEffectType, sendButtonTypeTapped);
        }
    });
}

static void replaced_voiceRecordPreviewDidTapSend(id self, SEL _cmd, id url, id waveform, double duration, long long entryPoint, id aiVoiceEffectApplied, id aiVoiceEffectType) {
    SPKDMConfirmVoiceMessage(^{
        if (orig_voiceRecordPreviewDidTapSend) {
            orig_voiceRecordPreviewDidTapSend(self, _cmd, url, waveform, duration, entryPoint, aiVoiceEffectApplied, aiVoiceEffectType);
        }
    });
}

static void replaced_voiceRecordPreviewSendButton(id self, SEL _cmd) {
    SPKDMConfirmVoiceMessage(^{
        if (orig_voiceRecordPreviewSendButton) {
            orig_voiceRecordPreviewSendButton(self, _cmd);
        }
    });
}

static void replaced_aiVoiceCompactBarDidTapSend(id self, SEL _cmd) {
    SPKDMConfirmVoiceMessage(^{
        if (orig_aiVoiceCompactBarDidTapSend) {
            orig_aiVoiceCompactBarDidTapSend(self, _cmd);
        }
    });
}

static void SPKHookDMVoiceInstanceMethod(const char *className, SEL selector, IMP replacement, IMP *original) {
    Class cls = objc_getClass(className);
    if (!cls || !class_getInstanceMethod(cls, selector))
        return;

    MSHookMessageEx(cls, selector, replacement, original);
}

void SPKInstallDMAudioMsgConfirmHooksIfEnabled(void) {
    if (!SPKDMShouldConfirmVoiceMessage())
        return;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        SPKHookDMVoiceInstanceMethod("IGDirectThreadViewController",
                                     @selector(voiceRecordViewController:didRecordAudioClipWithURL:waveform:duration:entryPoint:),
                                     (IMP)replaced_threadViewLegacyRecordedAudioClip,
                                     (IMP *)&orig_threadViewLegacyRecordedAudioClip);
        SPKHookDMVoiceInstanceMethod("IGDirectThreadViewController",
                                     @selector(voiceRecordViewController:didRecordAudioClipWithURL:waveform:duration:entryPoint:aiVoiceEffectApplied:aiVoiceEffectType:sendButtonTypeTapped:),
                                     (IMP)replaced_threadViewRecordedAudioClip,
                                     (IMP *)&orig_threadViewRecordedAudioClip);
        SPKHookDMVoiceInstanceMethod("IGDirectThreadViewVoiceController",
                                     @selector(voiceRecordViewController:didRecordAudioClipWithURL:waveform:duration:entryPoint:aiVoiceEffectApplied:aiVoiceEffectType:sendButtonTypeTapped:),
                                     (IMP)replaced_voiceControllerRecordedAudioClip,
                                     (IMP *)&orig_voiceControllerRecordedAudioClip);
        SPKHookDMVoiceInstanceMethod("_TtC24IGDirectVoiceRecordingUI33IGDirectVoiceRecordViewController",
                                     @selector(voiceRecordPreviewContentViewControllerDidTapSendWithUrl:waveform:duration:entryPoint:aiVoiceEffectApplied:aiVoiceEffectType:),
                                     (IMP)replaced_voiceRecordPreviewDidTapSend,
                                     (IMP *)&orig_voiceRecordPreviewDidTapSend);
        SPKHookDMVoiceInstanceMethod("_TtC29IGDirectVoiceRecordingPreview40IGDirectVoiceRecordPreviewViewController",
                                     @selector(didTapSendButton),
                                     (IMP)replaced_voiceRecordPreviewSendButton,
                                     (IMP *)&orig_voiceRecordPreviewSendButton);
        SPKHookDMVoiceInstanceMethod("_TtC20IGDirectAIVoiceUIKitP33_5754F7617E0D924F9A84EFA352BBD29A21CompactBarContentView",
                                     @selector(didTapSend),
                                     (IMP)replaced_aiVoiceCompactBarDidTapSend,
                                     (IMP *)&orig_aiVoiceCompactBarDidTapSend);
    });
}
