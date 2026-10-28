#import "../../Utils.h"

#ifdef __cplusplus
extern "C" {
#endif
void SPKMarkDirectThreadSeenAfterReaction(id source);
#ifdef __cplusplus
}
#endif

#pragma mark - Hook group

%group SPKDMInteractionConfirmHooks

// ─── Double-tap like ────────────────────────────────────────────────

%hook IGDirectMessageSectionController

- (void)messageCellDidDoubleTap:(id)cell {
    if (![SPKUtils getBoolPref:@"msgs_confirm_double_tap"]) {
        %orig;
        SPKMarkDirectThreadSeenAfterReaction(self);
        return;
    }

    [SPKUtils
        showConfirmation:^{
            %orig;
            SPKMarkDirectThreadSeenAfterReaction(self);
        }
                   title:@"Confirm Message Double Tap"
                 message:@"A double tap sends a heart to the sender."];
}

%end

// ─── Emoji reaction picker ──────────────────────────────────────────
// When the user long-presses a message and picks an emoji, the call
// chain is:
//
//   IGDirectMessageReactionSelectionViewController
//       -reactionContainerView:didSelectEmojiAtIndex:       ← we hook HERE
//           → internally delegates to IGDirectMessageReactionController
//               -messageReactionSelectionViewController:didToggleEmoji:...
//
// We ONLY hook the picker VC entry point. Hooking the delegate too
// causes a double-prompt because %orig on the picker method cascades
// into the delegate.

%hook IGDirectMessageReactionSelectionViewController

- (void)reactionContainerView:(id)containerView didSelectEmojiAtIndex:(NSInteger)index {
    if (![SPKUtils getBoolPref:@"msgs_confirm_reaction"]) {
        %orig;
        SPKMarkDirectThreadSeenAfterReaction(self);
        return;
    }

    [SPKUtils
        showConfirmation:^{
            %orig;
            SPKMarkDirectThreadSeenAfterReaction(self);
        }
                   title:@"Confirm Message Reaction"
                 message:@"The reaction is sent as soon as you confirm."];
}

%end

%end // group SPKDMInteractionConfirmHooks

#pragma mark - Entry point

extern "C" void SPKInstallDMInteractionConfirmHooksIfEnabled(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        %init(SPKDMInteractionConfirmHooks);
    });
}
