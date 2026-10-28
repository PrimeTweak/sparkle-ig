// Records IGProfileViewController visits when profile_analyzer_track_visits is on.

#import "../../../Utils.h"
#import "SPKProfileAnalyzerModels.h"
#import "SPKProfileAnalyzerStorage.h"

// 30s per-pk debounce so back-and-forth navigation doesn't inflate the count.
static NSMutableDictionary<NSString *, NSDate *> *spkPAVisitDebounce(void) {
    static NSMutableDictionary *m;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        m = [NSMutableDictionary dictionary];
    });
    return m;
}

%group SPKProfileAnalyzerVisitHooks

%hook IGProfileViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;

    if (![SPKUtils getBoolPref:@"profile_analyzer_track_visits"])
        return;

    id igUser = nil;
    @try {
        igUser = [(id)self valueForKey:@"user"];
    } @catch (__unused NSException *e) {
    }
    if (!igUser)
        return;

    SPKProfileAnalyzerUser *user = [SPKProfileAnalyzerUser userFromIGUserObject:igUser];
    if (!user.pk.length)
        return;
    // Skip when fieldCache hasn't loaded yet — the next viewDidAppear catches it.
    if (!user.username.length)
        return;

    NSString *selfPK = [SPKUtils currentUserPK];
    if (selfPK.length && [user.pk isEqualToString:selfPK])
        return; // ignore own profile

    NSMutableDictionary *deb = spkPAVisitDebounce();
    NSString *key = [NSString stringWithFormat:@"%@>%@", selfPK ?: @"anon", user.pk];
    NSDate *last = deb[key];
    if (last && [[NSDate date] timeIntervalSinceDate:last] < 30.0)
        return;
    deb[key] = [NSDate date];

    [SPKProfileAnalyzerStorage recordVisitForUser:user forUserPK:selfPK];
}

%end

%end

void SPKInstallProfileAnalyzerVisitTrackerHooksIfEnabled(void) {
    if (![SPKUtils getBoolPref:@"profile_analyzer_track_visits"])
        return;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        %init(SPKProfileAnalyzerVisitHooks);
    });
}
