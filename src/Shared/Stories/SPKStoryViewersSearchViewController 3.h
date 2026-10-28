#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

// Sparkle-native searchable viewer list for one of your own stories. Fetches the
// full viewer list client-side (SPKStoryViewersFetcher) and lets you search it
// by username / name and filter by follow relationship — client-side, so it
// never touches Instagram Plus's server-locked GraphQL viewer search.
//
// Ephemeral: the list lives only while the sheet is open (see the
// forward-compatible model note in SPKStoryViewersFetcher for the eventual
// persistent-archive upgrade).
@interface SPKStoryViewersSearchViewController : UIViewController

- (instancetype)initWithMediaID:(NSString *)mediaID
                          title:(nullable NSString *)title;

// Wraps the VC in Sparkle's chrome navigation controller and presents it from
// the top-most view controller.
+ (void)presentForMediaID:(NSString *)mediaID title:(nullable NSString *)title;

@end

NS_ASSUME_NONNULL_END
