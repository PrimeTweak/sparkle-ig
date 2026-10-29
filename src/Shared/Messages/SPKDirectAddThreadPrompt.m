#import "SPKDirectAddThreadPrompt.h"

#import "../../Networking/SPKInstagramAPI.h"
#import "../../Utils.h"
#import "../ActionButton/ActionButtonLookupUtils.h"
#import "../UI/SPKDialog.h"

@implementation SPKDirectAddThreadPromptCopy
@end

static void SPKDirectAddThreadPresentError(UIViewController *host, NSString *title, NSString *message) {
    [SPKDialog presentFromController:host
                               title:title
                             message:message
                             actions:@[ [SPKDialogAction actionWithTitle:@"OK" style:SPKDialogActionStyleCancel handler:nil] ]];
}

// The lists are keyed by thread, and a user never messaged has no thread to key on.
static void SPKDirectAddThreadResolveThread(UIViewController *host,
                                            SPKDirectAddThreadPromptCopy *copy,
                                            NSString *pk,
                                            NSString *username,
                                            NSString *fullName,
                                            NSString *profilePicUrl,
                                            void (^completion)(NSDictionary *entry, NSString *username)) {
    NSString *encodedRecipients = [[NSString stringWithFormat:@"[%@]", pk]
        stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLQueryAllowedCharacterSet];
    [SPKInstagramAPI sendRequestWithMethod:@"GET"
                                      path:[NSString stringWithFormat:@"direct_v2/threads/get_by_participants/?recipient_users=%@", encodedRecipients]
                                      body:nil
                                completion:^(NSDictionary *threadResponse, NSError *threadError) {
                                    NSDictionary *thread = threadResponse[@"thread"];
                                    NSString *threadId = [thread isKindOfClass:[NSDictionary class]]
                                                             ? SPKStringFromValue(thread[@"thread_id"] ?: thread[@"threadId"])
                                                             : nil;
                                    if (threadId.length == 0 || threadError) {
                                        SPKDirectAddThreadPresentError(host, copy.errorTitle,
                                                                       [NSString stringWithFormat:copy.noThreadFormat, username]);
                                        return;
                                    }

                                    NSMutableDictionary *userEntry = [@{@"pk" : pk, @"username" : username, @"fullName" : fullName} mutableCopy];
                                    if (profilePicUrl.length > 0)
                                        userEntry[@"profilePicUrl"] = profilePicUrl;
                                    NSDictionary *entry = @{
                                        @"threadId" : threadId,
                                        @"threadName" : SPKStringFromValue(thread[@"thread_title"]) ?: username,
                                        @"isGroup" : @(NO),
                                        @"users" : @[ userEntry.copy ],
                                    };

                                    NSString *message = fullName.length > 0
                                                            ? [NSString stringWithFormat:@"@%@ (%@)", username, fullName]
                                                            : [@"@" stringByAppendingString:username];
                                    [SPKDialog presentFromController:host
                                                               title:copy.confirmTitle
                                                             message:message
                                                             actions:@[
                                                                 [SPKDialogAction actionWithTitle:@"Cancel"
                                                                                            style:SPKDialogActionStyleCancel
                                                                                          handler:nil],
                                                                 [SPKDialogAction actionWithTitle:@"Add"
                                                                                            style:SPKDialogActionStyleDefault
                                                                                          handler:^{
                                                                                              completion(entry, username);
                                                                                          }],
                                                             ]];
                                }];
}

static void SPKDirectAddThreadLookupUsername(UIViewController *host,
                                             SPKDirectAddThreadPromptCopy *copy,
                                             NSString *rawUsername,
                                             void (^completion)(NSDictionary *entry, NSString *username)) {
    NSString *username = [SPKUtils sanitizedInstagramUsername:rawUsername];
    if (username.length == 0)
        return;

    [SPKInstagramAPI resolveUserForUsername:username
                                 completion:^(NSDictionary *user, NSError *error) {
                                     if (![user isKindOfClass:[NSDictionary class]] || error) {
                                         SPKDirectAddThreadPresentError(host, copy.errorTitle,
                                                                        [NSString stringWithFormat:copy.userNotFoundFormat, username]);
                                         return;
                                     }
                                     NSString *pk = SPKStringFromValue(user[@"pk"] ?: user[@"id"]);
                                     if (pk.length == 0) {
                                         SPKDirectAddThreadPresentError(host, copy.errorTitle, copy.unresolvedUserText);
                                         return;
                                     }
                                     SPKDirectAddThreadResolveThread(host,
                                                                     copy,
                                                                     pk,
                                                                     SPKStringFromValue(user[@"username"]) ?: username,
                                                                     SPKStringFromValue(user[@"full_name"] ?: user[@"fullName"]) ?: @"",
                                                                     SPKStringFromValue(user[@"profile_pic_url"] ?: user[@"profile_pic_url_hd"]),
                                                                     completion);
                                 }];
}

void SPKDirectPresentAddThreadPrompt(UIViewController *host,
                                     SPKDirectAddThreadPromptCopy *copy,
                                     void (^completion)(NSDictionary *entry, NSString *username)) {
    if (!host || !copy || !completion)
        return;
    [SPKDialog presentTextInputFromController:host
                                        title:copy.promptTitle
                                      message:copy.promptMessage
                                  placeholder:@"username"
                                  initialText:nil
                              autocapitalized:NO
                                 confirmTitle:@"Search"
                                  cancelTitle:@"Cancel"
                                 confirmStyle:SPKDialogActionStyleDefault
                                 confirmBlock:^(NSString *text) {
                                     SPKDirectAddThreadLookupUsername(host, copy, text, completion);
                                 }
                                  cancelBlock:nil];
}
