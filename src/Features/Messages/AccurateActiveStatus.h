#import <Foundation/Foundation.h>

FOUNDATION_EXPORT void SPKInstallAccurateActiveStatusHooksIfEnabled(void);

/// Re-applies the active account's current accuracy settings to Instagram's
/// already-created presence scheduler. Safe to call after a settings change,
/// foreground transition, or account switch.
FOUNDATION_EXPORT void SPKRefreshAccurateActiveStatusScheduler(void);

/// A live summary of whether the early scheduler and grace-period hooks were
/// installed and actually exercised during this process.
FOUNDATION_EXPORT NSString *SPKAccurateActiveStatusDiagnosticsText(void);
