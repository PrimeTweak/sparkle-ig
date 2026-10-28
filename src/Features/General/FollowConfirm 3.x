#import "../../InstagramHeaders.h"
#import "../../Utils.h"

#import <objc/message.h>
#import <objc/runtime.h>

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

// IG 442 rebuilt the follow controller in Swift: only a `_user` ivar survives, read
// directly since KVC on a Swift instance throws. Returns -1 when unreadable, which
// suppresses both prompts rather than wording the wrong one.
static NSInteger SPKFollowControllerStatus(id controller) {
    id user = [SPKUtils getIvarForObj:controller name:"_user"];
    if (![user respondsToSelector:@selector(followStatus)]) {
        SPKLog(@"General", @"[Sparkle] Follow confirm: no readable user on %@<%p>",
               NSStringFromClass([controller class]),
               controller);
        return -1;
    }

    return ((IGUser *)user).followStatus;
}

// A confirmed unfollow can cross several hooked layers before the network call, so
// the answer is carried down the stack to keep one prompt per action. Every hop is
// synchronous on the main thread.
static BOOL spk_unfollowConfirmed = NO;

static void SPKConfirmUnfollowElseRestore(void (^perform)(void), void (^restore)(void)) {
    if (spk_unfollowConfirmed || ![SPKUtils getBoolPref:@"profile_confirm_unfollow"]) {
        perform();
        return;
    }

    [SPKUtils
        showConfirmation:^(void) {
            spk_unfollowConfirmed = YES;
            perform();
            spk_unfollowConfirmed = NO;
        }
           cancelHandler:restore
                   title:@"Unfollow account"
                 message:@"You stop following this account."];
}

static void SPKConfirmUnfollow(void (^perform)(void)) {
    SPKConfirmUnfollowElseRestore(perform, nil);
}

// Follow buttons toggle, so the prompt is worded from the account's current state
// rather than from the button that was tapped.
static void SPKConfirmFollowToggle(BOOL isFollowing, void (^perform)(void)) {
    if (isFollowing) {
        SPKConfirmUnfollow(perform);
        return;
    }

    if (![SPKUtils getBoolPref:@"profile_confirm_follow"]) {
        perform();
        return;
    }

    SPKLog(@"General", @"[Sparkle] Confirm follow triggered");
    [SPKUtils showConfirmation:perform
                         title:@"Follow account"
                       message:@"You start following this account."];
}

// Status 2 is the only state in which a tap begins a follow. An account that cannot
// be read keeps the follow wording.
static BOOL SPKUserIsFollowed(id user) {
    if (![user respondsToSelector:@selector(followStatus)])
        return NO;

    return ((IGUser *)user).followStatus != 2;
}

// Some buttons carry their own follow state instead of the account.
static BOOL SPKButtonReportsFollowing(id button) {
    if (![button respondsToSelector:@selector(isFollowing)])
        return NO;

    return ((BOOL (*)(id, SEL))objc_msgSend)(button, @selector(isFollowing));
}

static id SPKObjectForKnownSelector(id target, SEL selector) {
    if (![target respondsToSelector:selector])
        return nil;

    return ((id (*)(id, SEL))objc_msgSend)(target, selector);
}

// Suggested account rows keep the account behind a featured user wrapper.
static id SPKFeaturedUserFromOwner(id owner) {
    return SPKObjectForKnownSelector(SPKObjectForKnownSelector(owner, @selector(userInfo)),
                                     @selector(user));
}

// While following, a tap can open the relationship sheet, whose Unfollow row is
// confirmed where it is selected. IG 448 keeps this flag as a Swift stored Bool,
// read from the ivar when the getter is gone.
static BOOL SPKFollowControllerOpensRelationshipSheet(id controller) {
    if ([controller respondsToSelector:@selector(canShowRelationshipSheetWhenFollowing)])
        return ((id<SPKFollowControlling>)controller).canShowRelationshipSheetWhenFollowing;

    Ivar flag = controller ? class_getInstanceVariable(object_getClass(controller), "canShowRelationshipSheetWhenFollowing") : NULL;
    if (!flag)
        return NO;

    return ((const uint8_t *)(__bridge const void *)controller)[ivar_getOffset(flag)] & 1;
}

// Some surfaces turn the control into a Message button once followed, so a tap opens
// a thread. Read from the controller flag, or from the reply presenter that only
// those surfaces wire up.
static BOOL SPKFollowControllerTapOpensMessage(id controller) {
    if ([controller respondsToSelector:@selector(showMessageButtonWhenFollowing)])
        return ((id<SPKFollowControlling>)controller).showMessageButtonWhenFollowing;

    return [SPKUtils getIvarForObj:controller name:"_directReplyToAuthorPresenter"] != nil ||
           [SPKUtils getIvarForObj:controller name:"directReplyToAuthorPresenter"] != nil;
}

// The Swift controller reaches performUnfollow through Swift dispatch, invisible to a
// swizzle, so both prompts are raised from the tap handlers.
#define CONFIRMFOLLOWTAP(orig)                                                              \
    {                                                                                       \
        NSInteger status = SPKFollowControllerStatus(self);                                 \
                                                                                            \
        if (status == 2) {                                                                  \
            CONFIRMFOLLOW(orig);                                                            \
        } else if (status >= 0 && !SPKFollowControllerOpensRelationshipSheet(self) &&       \
                   !SPKFollowControllerTapOpensMessage(self)) {                             \
            SPKConfirmUnfollow(^(void) {                                                    \
                orig;                                                                       \
            });                                                                             \
        } else {                                                                            \
            return orig;                                                                    \
        }                                                                                   \
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
    SPKConfirmUnfollow(^(void) {
        %orig;
    });
}
%end

// Follow button on discover people page
%hook IGDiscoverPeopleButtonGroupView
- (void)_onFollowButtonTapped:(id)arg1 {
    CONFIRMFOLLOW(%orig);
}
// The Following state of the same button, which ends the follow.
- (void)_onFollowingButtonTapped:(id)arg1 {
    SPKConfirmUnfollow(^(void) {
        %orig;
    });
}
%end

// Suggested for you (home feed & profile) follow button
%hook IGHScrollAYMFCell
- (void)_didTapAYMFActionButton {
    SPKConfirmFollowToggle(SPKUserIsFollowed(SPKFeaturedUserFromOwner(self)), ^(void) {
        %orig;
    });
}
%end
%hook IGHScrollAYMFActionButton
- (void)_didTapTextActionButton {
    SPKConfirmFollowToggle(SPKUserIsFollowed(SPKFeaturedUserFromOwner(self)), ^(void) {
        %orig;
    });
}
%end

// Follow button on reels, which follows and unfollows in place
%hook IGUnifiedVideoFollowButton
- (void)_hackilyHandleOurOwnButtonTaps:(id)arg1 event:(id)arg2 {
    SPKConfirmFollowToggle(SPKButtonReportsFollowing(self), ^(void) {
        %orig;
    });
}
%end

// Follow text on profile (when collapsed into top bar). While following it opens the
// relationship sheet, which confirms its own Unfollow row.
%hook IGProfileViewController
- (void)navigationItemsControllerDidTapHeaderFollowButton:(id)arg1 {
    if (SPKUserIsFollowed(SPKObjectForKnownSelector(self, @selector(user)))) {
        return %orig;
    }

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

// The Swift class that replaced the follow controller (IGFollowing.IGFollowController).
// Builds without it bind nothing here.
%group SPKFollowConfirmSwiftHooks

%hook _TtC11IGFollowing18IGFollowController

// Follow button tapped through a gesture recognizer
- (void)didPressFollowButtonWith:(id)arg1 {
    CONFIRMFOLLOWTAP(%orig);
}

// Follow button tapped as a plain control event
- (void)didPressFollowButtonFromControlEvent {
    CONFIRMFOLLOWTAP(%orig);
}

// For surfaces that still reach this from Objective-C; elsewhere the sheet
// selection hook below catches the unfollow.
- (void)performUnfollow {
    SPKConfirmUnfollow(^(void) {
        %orig;
    });
}

%end

%end

////////////////////////////////////////////////////////

// Relationship sheet row identifiers, unchanged from IG 410 through 442:
// 0 close friends, 1 mute, 2 unfollow, 3 restrict, 5 favorites.
static const NSInteger kSPKFollowSheetUnfollowRow = 2;

// The sheet keeps its rows as boxed identifiers, the only description of a row that
// is not a localized title. Swift builds renamed the store, so both spellings are tried.
static BOOL SPKFollowSheetRowIsUnfollow(id sectionController, NSInteger index) {
    id rows = [SPKUtils getIvarForObj:sectionController name:"rowValues"];
    if (![rows isKindOfClass:[NSArray class]])
        rows = [SPKUtils getIvarForObj:sectionController name:"_rowValues"];

    if (![rows isKindOfClass:[NSArray class]] || index < 0 || (NSUInteger)index >= [rows count]) {
        SPKLog(@"General", @"[Sparkle] Follow confirm: unreadable relationship sheet rows on %@",
               NSStringFromClass([sectionController class]));
        return NO;
    }

    id value = [rows objectAtIndex:(NSUInteger)index];
    return [value respondsToSelector:@selector(integerValue)] &&
           [value integerValue] == kSPKFollowSheetUnfollowRow;
}

// Clears the row through the list adapter's context, the way Instagram does.
static void SPKDeselectSectionControllerRow(id sectionController, NSInteger index) {
    id context = SPKObjectForKnownSelector(sectionController, @selector(collectionContext));
    SEL deselect = @selector(deselectItemAtIndex:sectionController:animated:);
    if (![context respondsToSelector:deselect])
        return;

    ((void (*)(id, SEL, NSInteger, id, BOOL))objc_msgSend)(context, deselect, index, sectionController, NO);
}

// The sheet's Unfollow row runs through Swift internals out of reach, so the
// selection itself is confirmed; the Objective-C list adapter still dispatches here.
%group SPKFollowConfirmSheetHooks

// IGProfileFollowing.IGProfileFollowActionsSectionController
%hook _TtC18IGProfileFollowing39IGProfileFollowActionsSectionController

- (void)didSelectItemAtIndex:(NSInteger)index {
    if (!SPKFollowSheetRowIsUnfollow(self, index)) {
        return %orig;
    }

    SPKConfirmUnfollowElseRestore(
        ^(void) {
            %orig;
        },
        ^(void) {
            // Declining has to clear the selection Instagram's handler would have cleared.
            SPKDeselectSectionControllerRow(self, index);
        });
}

%end

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
        %init(SPKFollowConfirmSwiftHooks);
        %init(SPKFollowConfirmSheetHooks);
        SPKInstallFollowAllConfirmHook();
    });
}
