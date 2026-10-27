#import <UIKit/UIKit.h>

#import "SPKDirectSeenContext.h"

NS_ASSUME_NONNULL_BEGIN

/// Builds one feature's rows for a thread's inbox long-press menu, or nil for none. Called on
/// every menu build, so preferences are read here rather than at install time.
typedef NSArray<UIMenuElement *> *_Nullable (^SPKDirectInboxMenuProvider)(SPKDirectThreadContext *context, id viewModel);
typedef UIMenu *_Nullable (^SPKDirectInboxMenuTransformer)(SPKDirectThreadContext *context, id viewModel, UIMenu *menu);

#ifdef __cplusplus
extern "C" {
#endif

/// Registers one feature's rows. A single shared hook wraps the menu of every inbox controller,
/// so features never wrap each other. Lower `order` comes first; the same `identifier` replaces.
void SPKDirectInboxMenuRegisterProvider(NSString *identifier, NSInteger order, SPKDirectInboxMenuProvider provider);

/// Registers a transform of Instagram's own menu, applied before Sparkle's rows are added.
/// Returning nil or an invalid menu leaves the menu untouched.
void SPKDirectInboxMenuRegisterTransformer(NSString *identifier, NSInteger order, SPKDirectInboxMenuTransformer transformer);

/// Installs the shared hook. Idempotent; with nothing registered the menu is returned untouched.
void SPKDirectInboxMenuInstallHooksIfNeeded(void);

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END
