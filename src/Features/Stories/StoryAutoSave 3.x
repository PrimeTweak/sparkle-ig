#import "../../InstagramHeaders.h"
#import "../../Shared/AutoSave/SPKAutoSave.h"
#import "../../Shared/Stories/SPKStoryAutoSave.h"
#import "../../Shared/UI/SPKNotificationCenter.h"
#import "../../App/SPKPerfMeter.h"

// Auto-save rides the same overlay layout pass the story action button uses, but
// installs its own hook: the action button's group is gated on `stories_action_btn`,
// and auto-save has to work whether or not that button is enabled.
%group SPKStoryAutoSaveHooks

%hook IGStoryFullscreenOverlayView
- (void)layoutSubviews {
    %orig;
    SPK_PERF_SCOPE(@"StoryAutoSave.layoutSubviews");
    SPKStoryAutoSaveConsiderOverlay((UIView *)self);
}
%end

// Leaving the viewer ends the session. The summary may land a while later -- downloads
// and merges outlive the viewer -- but clearing the seen set now is harmless: the
// Gallery duplicate check still stops anything being saved twice.
%hook IGStoryViewerViewController
- (void)viewDidDisappear:(BOOL)animated {
    %orig;
    SPKAutoSaveSessionDidEnd();
    SPKStoryAutoSaveViewerSessionDidEnd();
}
%end

%end

// Installed unconditionally: SPKStoryAutoSaveConsiderOverlay re-reads the pref on
// every call, so gating the install here would instead mean toggling the feature on
// did nothing until IG was restarted.
void SPKInstallStoryAutoSaveHooksIfEnabled(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        SPKAutoSaveRegisterNotificationIdentifier(kSPKNotificationStoryAutoSave);
        SPKAutoSaveStartWatching();
        %init(SPKStoryAutoSaveHooks);
    });
}
