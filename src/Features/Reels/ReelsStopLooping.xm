#import "../../InstagramHeaders.h"
#import "../../Utils.h"
#import "ReelsAutoScrollDefault.h"
#import <objc/message.h>
#import <objc/runtime.h>

// Looping lives in the video player: a play that starts inside the reels cell's
// play belongs to a reel, so only reels get isLoopingOverride off. The player then
// stops on the last frame, and an ended reel rewinds on its next play.

static NSString *const kSPKReelsStopLoopingPrefKey = @"reels_stop_looping";

static const void *kSPKReelsStopLoopingPlayerAssocKey = &kSPKReelsStopLoopingPlayerAssocKey;
static const void *kSPKReelsStopLoopingEndedAssocKey = &kSPKReelsStopLoopingEndedAssocKey;
static const void *kSPKReelsStopLoopingAppliedAssocKey = &kSPKReelsStopLoopingAppliedAssocKey;

// Main thread only, like every reels playback call.
static NSInteger sSPKReelsStopLoopingCellPlayDepth = 0;
static __weak UIView *sSPKReelsStopLoopingPlayingCell = nil;
static BOOL sSPKReelsStopLoopingSyntheticTap = NO;
static BOOL sSPKReelsStopLoopingInRealTap = NO;
static BOOL sSPKReelsStopLoopingTapToggledPlayback = NO;
// -1 unknown, 0 a tap does something else (mute), 1 a tap pauses.
static NSInteger sSPKReelsStopLoopingObservedTapPauses = -1;

@interface SPKReelsStopLoopingWeakPlayer : NSObject
@property (nonatomic, weak) id player;
@end

@implementation SPKReelsStopLoopingWeakPlayer
@end

// Auto scroll in force wins: an ended reel has to keep going for Instagram to
// advance, so the saved choice is kept but not acted on.
static BOOL SPKReelsStopLoopingEnabled(void) {
    if ([SPKReelsAutoScrollEffectiveMode() isEqualToString:@"on"])
        return NO;
    return [SPKUtils getBoolPref:kSPKReelsStopLoopingPrefKey];
}

static id SPKReelsStopLoopingPlayerForCell(UIView *cell) {
    SPKReelsStopLoopingWeakPlayer *box = objc_getAssociatedObject(cell, kSPKReelsStopLoopingPlayerAssocKey);
    return box.player;
}

static BOOL SPKReelsStopLoopingCellEnded(UIView *cell) {
    return [objc_getAssociatedObject(cell, kSPKReelsStopLoopingEndedAssocKey) boolValue];
}

static void SPKReelsStopLoopingSetCellEnded(UIView *cell, BOOL ended) {
    objc_setAssociatedObject(cell, kSPKReelsStopLoopingEndedAssocKey, ended ? @YES : nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void SPKReelsStopLoopingApplyToPlayer(id player) {
    SEL overrideSetter = NSSelectorFromString(@"setIsLoopingOverride:");
    if (![player respondsToSelector:overrideSetter])
        return;
    ((void (*)(id, SEL, id))objc_msgSend)(player, overrideSetter, @NO);
    objc_setAssociatedObject(player, kSPKReelsStopLoopingAppliedAssocKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void SPKReelsStopLoopingRestorePlayer(id player) {
    SEL overrideSetter = NSSelectorFromString(@"setIsLoopingOverride:");
    if ([player respondsToSelector:overrideSetter])
        ((void (*)(id, SEL, id))objc_msgSend)(player, overrideSetter, nil);
    objc_setAssociatedObject(player, kSPKReelsStopLoopingAppliedAssocKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void SPKReelsStopLoopingWillPlayPlayer(id player) {
    if (!player)
        return;
    BOOL applied = [objc_getAssociatedObject(player, kSPKReelsStopLoopingAppliedAssocKey) boolValue];
    if (!SPKReelsStopLoopingEnabled()) {
        if (applied)
            SPKReelsStopLoopingRestorePlayer(player);
        return;
    }
    UIView *cell = sSPKReelsStopLoopingPlayingCell;
    if (sSPKReelsStopLoopingCellPlayDepth <= 0 || !cell)
        return;

    SPKReelsStopLoopingApplyToPlayer(player);
    SPKReelsStopLoopingWeakPlayer *box = [SPKReelsStopLoopingWeakPlayer new];
    box.player = player;
    objc_setAssociatedObject(cell, kSPKReelsStopLoopingPlayerAssocKey, box, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

// Only a tap that pauses may be replayed: with tap set to mute it would toggle sound.
static BOOL SPKReelsStopLoopingTapPauses(UIView *cell) {
    NSString *tapControl = [SPKUtils getStringPref:@"reels_tap_control"];
    if ([tapControl isEqualToString:@"pause"])
        return YES;
    if ([tapControl isEqualToString:@"mute"])
        return NO;

    id sectionController = [cell respondsToSelector:@selector(delegate)] ? ((id (*)(id, SEL))objc_msgSend)(cell, @selector(delegate)) : nil;
    id configuration = nil;
    if (sectionController) {
        configuration = [SPKUtils getIvarForObj:sectionController name:"playbackControlsTestConfiguration"]
                            ?: [SPKUtils getIvarForObj:sectionController name:"_playbackControlsTestConfiguration"];
    }
    SEL tapToPause = NSSelectorFromString(@"tapToPauseEnabled");
    if ([configuration respondsToSelector:tapToPause])
        return ((BOOL (*)(id, SEL))objc_msgSend)(configuration, tapToPause);
    return sSPKReelsStopLoopingObservedTapPauses == 1;
}

// Replays Instagram's own single tap so the reel enters its native paused state,
// play button included, exactly as if the viewer had tapped to pause.
static void SPKReelsStopLoopingShowPausedState(UIView *cell) {
    if (!cell.window || !SPKReelsStopLoopingCellEnded(cell) || !SPKReelsStopLoopingTapPauses(cell))
        return;
    SEL singleTap = @selector(gestureController:didObserveSingleTap:);
    if (![cell respondsToSelector:singleTap])
        return;
    id gestureController = [SPKUtils getIvarForObj:cell name:"_gestureController"];
    if (!gestureController)
        return;
    id tap = [SPKUtils getIvarForObj:gestureController name:"singleTapRecognizer"]
                 ?: [SPKUtils getIvarForObj:gestureController name:"_singleTapRecognizer"];
    if (![tap isKindOfClass:[UIGestureRecognizer class]])
        return;

    sSPKReelsStopLoopingSyntheticTap = YES;
    ((void (*)(id, SEL, id, id))objc_msgSend)(cell, singleTap, gestureController, tap);
    sSPKReelsStopLoopingSyntheticTap = NO;
}

%group SPKReelsStopLoopingCellHooks

%hook IGSundialViewerVideoCell
- (void)playWithReason:(long long)reason {
    if (sSPKReelsStopLoopingInRealTap)
        sSPKReelsStopLoopingTapToggledPlayback = YES;

    UIView *cell = (UIView *)self;
    if (SPKReelsStopLoopingCellEnded(cell)) {
        SPKReelsStopLoopingSetCellEnded(cell, NO);
        id player = SPKReelsStopLoopingPlayerForCell(cell);
        if (SPKReelsStopLoopingEnabled() && [player respondsToSelector:@selector(seekToTime:preciseTime:)])
            [(IGStatefulVideoPlayer *)player seekToTime:0 preciseTime:YES];
    }

    sSPKReelsStopLoopingCellPlayDepth++;
    sSPKReelsStopLoopingPlayingCell = cell;
    %orig(reason);
    sSPKReelsStopLoopingCellPlayDepth--;
}

- (void)pauseWithReason:(long long)reason {
    if (sSPKReelsStopLoopingInRealTap)
        sSPKReelsStopLoopingTapToggledPlayback = YES;
    %orig(reason);
}

- (void)gestureController:(id)controller didObserveSingleTap:(id)tap {
    if (sSPKReelsStopLoopingSyntheticTap) {
        %orig(controller, tap);
        return;
    }
    // Records what a tap does, for builds where the tap configuration is unreachable.
    sSPKReelsStopLoopingInRealTap = YES;
    sSPKReelsStopLoopingTapToggledPlayback = NO;
    %orig(controller, tap);
    sSPKReelsStopLoopingInRealTap = NO;
    sSPKReelsStopLoopingObservedTapPauses = sSPKReelsStopLoopingTapToggledPlayback ? 1 : 0;
}

- (void)videoViewDidPlayThroughToCompletion:(id)videoView {
    %orig(videoView);
    UIView *cell = (UIView *)self;
    id player = SPKReelsStopLoopingPlayerForCell(cell);
    if (!player || ![objc_getAssociatedObject(player, kSPKReelsStopLoopingAppliedAssocKey) boolValue] || !SPKReelsStopLoopingEnabled())
        return;

    SPKReelsStopLoopingSetCellEnded(cell, YES);
    __weak UIView *weakCell = cell;
    dispatch_async(dispatch_get_main_queue(), ^{
        UIView *strongCell = weakCell;
        if (strongCell)
            SPKReelsStopLoopingShowPausedState(strongCell);
    });
}
%end

%end

%group SPKReelsStopLoopingSwiftPlayerHooks

%hook _TtC21IGVideoPlayerKitSwift13IGVideoPlayer
- (void)playWithReason:(long long)reason callsiteContext:(id)context {
    SPKReelsStopLoopingWillPlayPlayer(self);
    %orig(reason, context);
}
%end

%end

%group SPKReelsStopLoopingStatefulPlayerHooks

%hook IGStatefulVideoPlayer
- (void)playWithReason:(long long)reason callsiteContext:(id)context {
    SPKReelsStopLoopingWillPlayPlayer(self);
    %orig(reason, context);
}
%end

%end

extern "C" void SPKInstallReelsStopLoopingHooksIfNeeded(void) {
    // Installed regardless of the preference so a change applies to the next reel;
    // every hook re-reads the preference at call time.
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if (!NSClassFromString(@"IGSundialViewerVideoCell"))
            return;
        %init(SPKReelsStopLoopingCellHooks);
        BOOL swiftPlayer = objc_getClass("_TtC21IGVideoPlayerKitSwift13IGVideoPlayer") != Nil;
        BOOL statefulPlayer = NSClassFromString(@"IGStatefulVideoPlayer") != Nil;
        if (swiftPlayer)
            %init(SPKReelsStopLoopingSwiftPlayerHooks);
        if (statefulPlayer)
            %init(SPKReelsStopLoopingStatefulPlayerHooks);
        SPKLog(@"StopLooping", @"installed swiftPlayer=%d statefulPlayer=%d", swiftPlayer, statefulPlayer);
    });
}
