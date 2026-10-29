#import <UIKit/UIKit.h>

/// Which Instants page a window shows, answered from the few view instances recorded as they
/// enter a window instead of a tree walk on every header layout pass. Every feature deciding
/// who owns the header's right-hand slot asks through here, so their answers never diverge.

/// The single visibility test for mode detection: the view itself is on a window, not hidden,
/// not faded out, and not collapsed.
FOUNDATION_EXPORT BOOL SPKInstantsModeViewIsVisible(UIView *view);

/// YES when a snap view (`IGQuickSnapImmersiveViewerSingleSnapView`) is visible in `window`.
FOUNDATION_EXPORT BOOL SPKInstantsWindowShowsSnapView(UIWindow *window);

/// YES when the creation camera view (`IGQuickSnapCreationView`) is visible in `window`.
FOUNDATION_EXPORT BOOL SPKInstantsWindowShowsCreationView(UIWindow *window);

/// The visible Instants header button view in `window`, or nil.
FOUNDATION_EXPORT UIView *SPKInstantsVisibleHeaderInWindow(UIWindow *window);

/// Installs the window-entry hooks that keep the registry current. Idempotent; call it from every
/// installer that queries the functions above, before the first query.
FOUNDATION_EXPORT void SPKInstallInstantsModeViewHooks(void);
