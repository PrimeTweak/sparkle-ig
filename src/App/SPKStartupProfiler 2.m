#import "SPKStartupProfiler.h"
#import "../Utils.h"

#if STARTUP_PROFILING

#import <CoreFoundation/CoreFoundation.h>

static CFAbsoluteTime sSPKStartupStartTime;

static BOOL SPKStartupProfilingEnabled(void) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    id override = [defaults objectForKey:@"app_startup_profiling"];
    return override == nil || [defaults boolForKey:@"app_startup_profiling"];
}

__attribute__((constructor)) static void SPKStartupProfilerConstructor(void) {
    sSPKStartupStartTime = CFAbsoluteTimeGetCurrent();
    if (SPKStartupProfilingEnabled()) {
        SPKLog(@"General", @"[Sparkle][startup] +0.000s constructor entry");
    }
}

void SPKStartupMark(NSString *event) {
    if (!SPKStartupProfilingEnabled()) {
        return;
    }

    if (sSPKStartupStartTime <= 0.0) {
        sSPKStartupStartTime = CFAbsoluteTimeGetCurrent();
    }

    NSTimeInterval elapsed = CFAbsoluteTimeGetCurrent() - sSPKStartupStartTime;
    SPKLog(@"General", @"[Sparkle][startup] +%.3fs %@", elapsed, event ?: @"mark");
}

#endif
