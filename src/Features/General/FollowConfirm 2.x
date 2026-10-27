#import "../../InstagramHeaders.h"
#import "../../Utils.h"

////////////////////////////////////////////////////////

#define CONFIRMFOLLOW(orig)                                                     \
    if ([SPKUtils getBoolPref:@"profile_confirm_follow"]) {                     \
        SPKLog(@"General", @"[Sparkle] Confirm follow triggered");              \
                                                                                \
        [SPKUtils                                                               \
            showConfirmation:^(void) {                                          \
                orig;                                                           \
            }                                                                   \
                       title:@"Follow account"                                  \
                     message:@"You start following this account."]; \
    } else {                                                                    \
        return orig;                                                            \
    }

////////////////////////////////////////////////////////

// Follow button on profile page
%group SPKFollowConfirmHooks

%hook IGFollowController
- (void)_didPressFollowButton {
    // Get user follow status (check if already following user)
    NSInteger UserFollowStatus = self.user.followStatus;

    // Only show confirm dialog if user is not following
    if (UserFollowStatus == 2) {
        CONFIRMFOLLOW(%orig);
    } else {
        return %orig;
    }
}

// Unfollow from profile action sheet
- (void)_performUnfollow {
    if ([SPKUtils getBoolPref:@"profile_confirm_unfollow"]) {
        [SPKUtils
            showConfirmation:^(void) {
                %orig;
            }
                       title:@"Unfollow account"
                     message:@"You stop following this account."];
    } else {
        %orig;
    }
}
%end

// Follow button on discover people page
%hook IGDiscoverPeopleButtonGroupView
- (void)_onFollowButtonTapped:(id)arg1 {
    CONFIRMFOLLOW(%orig);
}
- (void)_onFollowingButtonTapped:(id)arg1 {
    CONFIRMFOLLOW(%orig);
}
%end

// Suggested for you (home feed & profile) follow button
%hook IGHScrollAYMFCell
- (void)_didTapAYMFActionButton {
    CONFIRMFOLLOW(%orig);
}
%end
%hook IGHScrollAYMFActionButton
- (void)_didTapTextActionButton {
    CONFIRMFOLLOW(%orig);
}
%end

// Follow button on reels
%hook IGUnifiedVideoFollowButton
- (void)_hackilyHandleOurOwnButtonTaps:(id)arg1 event:(id)arg2 {
    CONFIRMFOLLOW(%orig);
}
%end

// Follow text on profile (when collapsed into top bar)
%hook IGProfileViewController
- (void)navigationItemsControllerDidTapHeaderFollowButton:(id)arg1 {
    CONFIRMFOLLOW(%orig);
}
%end

// Follow button on suggested friends (in story section)
%hook IGStorySectionController
- (void)followButtonTapped:(id)arg1 cell:(id)arg2 {
    CONFIRMFOLLOW(%orig);
}
%end

// Follow all button in group chats (3+ members) people view
static void (*orig_listSectionController)(id, SEL, id, id);

static void hooked_listSectionController(id self, SEL _cmd, id arg1, id arg2) {
    if ([SPKUtils getBoolPref:@"profile_confirm_follow"]) {

        [SPKUtils
            showConfirmation:^{
                orig_listSectionController(self, _cmd, arg1, arg2);
            }
                       title:@"Follow everyone"
                     message:@"You start following every account in the list."];

        return;
    }

    orig_listSectionController(self, _cmd, arg1, arg2);
}

%end

static void SPKInstallFollowAllConfirmHook(void) {
    Class cls = objc_getClass("IGDirectDetailMembersKit.IGDirectThreadDetailsMembersListViewController");
    if (!cls)
        return;

    MSHookMessageEx(
        cls,
        @selector(listSectionController:didTapHeaderButtonWithViewModel:),
        (IMP)hooked_listSectionController,
        (IMP *)&orig_listSectionController);
}

void SPKInstallFollowConfirmHooksIfNeeded(void) {
    if (![SPKUtils getBoolPref:@"profile_confirm_follow"] && ![SPKUtils getBoolPref:@"profile_confirm_unfollow"])
        return;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        %init(SPKFollowConfirmHooks);
        SPKInstallFollowAllConfirmHook();
    });
}
