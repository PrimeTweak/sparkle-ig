#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Wording for the "add a chat by username" prompt. Every DM thread list shares the
/// flow (username, user, then the 1:1 thread) but names what it adds differently.
@interface SPKDirectAddThreadPromptCopy : NSObject
@property (nonatomic, copy) NSString *promptTitle;
@property (nonatomic, copy) NSString *promptMessage;       // what can and cannot be added
@property (nonatomic, copy) NSString *confirmTitle;
@property (nonatomic, copy) NSString *errorTitle;
@property (nonatomic, copy) NSString *userNotFoundFormat;  // takes the username
@property (nonatomic, copy) NSString *noThreadFormat;      // takes the username
@property (nonatomic, copy) NSString *unresolvedUserText;  // user found, no usable id
@end

#ifdef __cplusplus
extern "C" {
#endif

/// Presents the prompt from `host`; `completion` gets a thread entry in the shape the
/// DM thread lists store, only once the user confirms. Failures present their own alert.
void SPKDirectPresentAddThreadPrompt(UIViewController *host,
                                     SPKDirectAddThreadPromptCopy *copy,
                                     void (^completion)(NSDictionary *entry, NSString *username));

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END
