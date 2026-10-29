#import <objc/runtime.h>

#import "../../InstagramHeaders.h"
#import "../../Utils.h"

extern "C" void MSHookMessageEx(Class cls, SEL sel, IMP replacement, IMP *result);

static NSString *const kSPKHideAudioUnavailableToastPreferenceKey = @"stories_hide_audio_unavailable_toast";
static NSString *const kSPKAudioUnavailableToastIdentifier = @"audio-go-dark-toast";

static BOOL SPKShouldHideAudioUnavailableToastModel(id model) {
    if (![SPKUtils getBoolPref:kSPKHideAudioUnavailableToastPreferenceKey] || !model)
        return NO;

    SEL identifierSelector = NSSelectorFromString(@"identifier");
    if (![model respondsToSelector:identifierSelector])
        return NO;

    id identifier = ((id (*)(id, SEL))objc_msgSend)(model, identifierSelector);
    return [identifier isKindOfClass:[NSString class]] && [identifier isEqualToString:kSPKAudioUnavailableToastIdentifier];
}

static void (*SPKOriginalShowActionableToast)(id, SEL, id, id, BOOL, double, long long, unsigned long long, unsigned long long, id, id, id, id) = NULL;
static void SPKShowActionableToast(id self,
                                   SEL selector,
                                   id model,
                                   id presentationContext,
                                   BOOL animated,
                                   double duration,
                                   long long priority,
                                   unsigned long long origin,
                                   unsigned long long toastType,
                                   id tapAction,
                                   id tapToastAction,
                                   id presentedHandler,
                                   id dismissedHandler) {
    if (SPKShouldHideAudioUnavailableToastModel(model))
        return;

    if (SPKOriginalShowActionableToast) {
        SPKOriginalShowActionableToast(self,
                                       selector,
                                       model,
                                       presentationContext,
                                       animated,
                                       duration,
                                       priority,
                                       origin,
                                       toastType,
                                       tapAction,
                                       tapToastAction,
                                       presentedHandler,
                                       dismissedHandler);
    }
}

static void (*SPKOriginalShowStoryAudioUnavailableToast)(id, SEL) = NULL;
static void SPKShowStoryAudioUnavailableToast(id self, SEL selector) {
    if ([SPKUtils getBoolPref:kSPKHideAudioUnavailableToastPreferenceKey])
        return;

    if (SPKOriginalShowStoryAudioUnavailableToast)
        SPKOriginalShowStoryAudioUnavailableToast(self, selector);
}

static BOOL SPKHookAudioUnavailableToastMethod(const char *className,
                                                SEL selector,
                                                IMP replacement,
                                                IMP *original) {
    Class cls = objc_getClass(className);
    if (!cls || !class_getInstanceMethod(cls, selector))
        return NO;

    MSHookMessageEx(cls, selector, replacement, original);
    return YES;
}

extern "C" void SPKInstallHideAudioUnavailableToastHooksIfEnabled(void) {
    // Installed regardless of the preference, which is re-read each time a
    // toast shows.
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        BOOL installedCurrentStory = SPKHookAudioUnavailableToastMethod("_TtC30IGStorySectionAudioCoordinator30IGStorySectionAudioCoordinator",
                                                                         NSSelectorFromString(@"showAudioUnavailableToast"),
                                                                         (IMP)SPKShowStoryAudioUnavailableToast,
                                                                         (IMP *)&SPKOriginalShowStoryAudioUnavailableToast);
        // Elsewhere it is an actionable toast matched by its identifier; newer
        // builds move the method to a concrete presenter.
        SEL showAlertSelector = NSSelectorFromString(@"_showAlertWithViewModel:presentationContext:isAnimated:animationDuration:presentationPriority:origin:toastType:tapActionBlock:tapToastBlock:presentedHandler:dismissedHandler:");
        BOOL installedActionablePresenter = SPKHookAudioUnavailableToastMethod("IGActionableConfirmationToastPresenter",
                                                                               showAlertSelector,
                                                                               (IMP)SPKShowActionableToast,
                                                                               (IMP *)&SPKOriginalShowActionableToast);
        if (!installedActionablePresenter)
            installedActionablePresenter = SPKHookAudioUnavailableToastMethod("IGActionableConfirmationToastConcretePresenter",
                                                                              showAlertSelector,
                                                                              (IMP)SPKShowActionableToast,
                                                                              (IMP *)&SPKOriginalShowActionableToast);

        SPKLog(@"Stories", @"Audio unavailable toast hooks installed currentStory=%@ actionablePresenter=%@",
               installedCurrentStory ? @"YES" : @"NO",
               installedActionablePresenter ? @"YES" : @"NO");
    });
}
