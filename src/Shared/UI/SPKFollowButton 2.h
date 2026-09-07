#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, SPKFollowButtonState) {
    SPKFollowButtonStateNotFollowing = 0,
    SPKFollowButtonStateFollowing,
    /// A follow request is pending on a private account.
    SPKFollowButtonStateRequested,
    /// They follow you and you do not follow them.
    SPKFollowButtonStateFollowBack,
};

/// A follow control for Sparkle's own user lists.
///
/// Instagram's follow control is used whenever its class resolves, so Sparkle
/// lists match the app exactly. It is driven as a plain view here: no delegate is
/// attached, so it renders and animates but performs no follow of its own, and
/// the caller keeps ownership of the tap, the network call, and the confirmation
/// preferences. Callers that need Instagram's own follow behaviour should drive
/// its follow controller instead, which requires a real user model.
///
/// Instagram's control is a `UIControl` rather than a `UIButton` and owns its own
/// title rendering, so it is never safe to send it `setTitle:forState:`. Drive it
/// only through this class.
@interface SPKFollowButton : NSObject

/// Instagram's control when available, otherwise a Sparkle-drawn stand-in with
/// the same metrics. Never nil. Add it to a view and constrain it as usual.
+ (UIControl *)button;

/// Renders the follow state. Instagram's control supplies its own localized
/// titles and styling; the stand-in is styled by Sparkle to match.
+ (void)applyState:(SPKFollowButtonState)state toButton:(UIControl *)button;

/// Shows the in-flight treatment while a follow request runs, and suppresses
/// interaction for its duration.
+ (void)setLoading:(BOOL)loading forButton:(UIControl *)button;

/// YES when `button` is Instagram's own control rather than the stand-in.
+ (BOOL)isNativeButton:(UIControl *)button;

/// Maps one entry of a `friendships/show_many/` response, or the
/// `friendship_status` returned by a follow call, onto a button state.
+ (SPKFollowButtonState)stateForFriendshipStatus:(nullable NSDictionary *)status;

/// YES when tapping a button in `state` should tear the relationship down rather
/// than create one, which covers withdrawing a pending request as well as
/// unfollowing.
+ (BOOL)tapUnfollowsFromState:(SPKFollowButtonState)state;

@end

NS_ASSUME_NONNULL_END
