#import <Foundation/Foundation.h>

/// Manually Mark Seen keeps viewed Instants in the tray until one is released: consumed PKs
/// are stripped from the stored seen state, the seen sync never reaches the server, and the
/// list is refetched when the viewer closes so the snaps return unseen.

/// YES when the pref is on. Re-read at call time.
FOUNDATION_EXPORT BOOL SPKInstantsManualSeenIsEnabled(void);

/// Records every snap the service announces so the feature knows which PKs to keep unseen.
/// Cheap: PK reads only, no media resolution.
FOUNDATION_EXPORT void SPKInstantsManualSeenNoteServiceMedia(NSArray *mediaList);

/// Strips every protected PK from the persisted seen state, on every service update since
/// Instagram rewrites it as snaps are consumed. While the viewer is open nothing is reloaded:
/// that would push the consumed snap back under the viewer.
FOUNDATION_EXPORT void SPKInstantsManualSeenHoldUnseen(id service);

/// Tells the feature whether the consumption viewer is on screen, which is what decides between
/// the silent write above and an immediate reload.
FOUNDATION_EXPORT void SPKInstantsManualSeenSetViewerOpen(BOOL open);

/// Closes a viewing session: strips anything left over, reloads the seen state, then forces a
/// refetch so the tray picks the Instants back up. This is the only point at which the feature
/// makes snaps reappear, so the viewer plays through to the end and dismisses normally.
FOUNDATION_EXPORT void SPKInstantsManualSeenEndViewerSession(id service);

/// Installs the seen-sync block, so a tray refetch does not come back with the Instants
/// already marked seen server-side.
FOUNDATION_EXPORT void SPKInstallInstantsManualSeenHooksIfEnabled(void);

/// Releases one snap: stops protecting it and marks it seen for real. This is the manual
/// half of the feature, so a held Instant can be cleared deliberately.
FOUNDATION_EXPORT void SPKInstantsManualSeenMarkMediaPK(NSString *mediaPK);

