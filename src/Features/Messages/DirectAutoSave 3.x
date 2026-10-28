#import "../../InstagramHeaders.h"
#import "../../Shared/AutoSave/SPKAutoSave.h"
#import "../../Shared/Messages/SPKDirectAutoSave.h"
#import "../../Shared/UI/SPKNotificationCenter.h"

// Its own group: the DM action button's hooks are gated on `msgs_action_btn`, and
// auto-save must work whether or not that's on.
%group SPKDirectAutoSaveHooks

%hook IGDirectVisualMessageViewerController

// Swiping between visual messages doesn't relayout the controller's view, so a layout
// hook wouldn't fire per item. The controller is the story-player media delegate, so
// these callbacks land on every item change -- the same seam the DM action button uses
// to reconfigure itself.
- (void)storyPlayerMediaViewDidLoad:(id)load loadSource:(id)source networkRequestSummary:(id)summary {
    %orig;
    SPKDirectAutoSaveConsiderController((UIViewController *)self);
}

- (void)storyPlayerMediaViewDidBeginPlayback:(id)playback {
    %orig;
    SPKDirectAutoSaveConsiderController((UIViewController *)self);
}

// Leaving the viewer ends the session. The summary may land a while later -- downloads
// and merges outlive the viewer -- but clearing the seen set now is harmless: the
// Gallery duplicate check still stops anything being saved twice.
- (void)viewDidDisappear:(BOOL)animated {
    %orig;
    SPKAutoSaveSessionDidEnd();
    SPKDirectAutoSaveViewerSessionDidEnd();
}

%end

%end

// Installed unconditionally: SPKDirectAutoSaveConsiderController re-reads the pref on
// every call, so gating the install here would instead mean toggling the feature on
// requires a restart (the installer is dispatch_once).
void SPKInstallDirectAutoSaveHooksIfEnabled(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        SPKAutoSaveRegisterNotificationIdentifier(kSPKNotificationDirectAutoSave);
        SPKAutoSaveStartWatching();
        %init(SPKDirectAutoSaveHooks);
    });
}
