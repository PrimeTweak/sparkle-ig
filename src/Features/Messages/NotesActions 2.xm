#import "../../Shared/UI/SPKDialog.h"
#import <QuartzCore/QuartzCore.h>
#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import <substrate.h>

#import "../../AssetUtils.h"
#import "../../Shared/Audio/SPKAudioDownloadCoordinator.h"
#import "../../Shared/Audio/SPKAudioItem.h"
#import "../../Shared/Gallery/SPKGallerySaveMetadata.h"
#import "../../Shared/UI/SPKIGAlertPresenter.h"
#import "../../Shared/UI/SPKNotificationCenter.h"
#import "../../Utils.h"

// Long-press actions on Direct notes (the tray bubbles above the inbox):
//   * Download Audio  — for music / original-audio / listening-now notes.
//   * Copy Note Text  — for text notes.
//
// Modern IG builds open an IGDSPrismMenuView on long press; we inject "Copy text" /
// "Save audio" rows into it, keeping IG's native menu intact.
// The rows are injected at the view level: IG builds the prism menu without routing
// note items through a hookable menu-elements initialiser, so we hook the menu
// view's layout and append our own item views.
//
// IG 410.1.0 is NOT (yet) supported.

#pragma mark - Reflection helpers

static id SPKNotesIvarValue(id object, const char *name) {
    if (!object || !name)
        return nil;
    @try {
        for (Class cls = [object class]; cls && cls != NSObject.class; cls = class_getSuperclass(cls)) {
            Ivar ivar = class_getInstanceVariable(cls, name);
            if (ivar)
                return object_getIvar(object, ivar);
        }
    } @catch (__unused NSException *exception) {
    }
    return nil;
}

static id SPKNotesCall(id object, NSString *selectorName) {
    if (!object || selectorName.length == 0)
        return nil;
    SEL selector = NSSelectorFromString(selectorName);
    if (![object respondsToSelector:selector])
        return nil;
    @try {
        return ((id (*)(id, SEL))objc_msgSend)(object, selector);
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

static BOOL SPKNotesBoolCall(id object, NSString *selectorName) {
    if (!object || selectorName.length == 0)
        return NO;
    SEL selector = NSSelectorFromString(selectorName);
    if (![object respondsToSelector:selector])
        return NO;
    @try {
        return ((BOOL (*)(id, SEL))objc_msgSend)(object, selector);
    } @catch (__unused NSException *exception) {
        return NO;
    }
}

static NSString *SPKNotesTrimmedString(id value) {
    NSString *string = nil;
    if ([value isKindOfClass:NSString.class]) {
        string = value;
    } else if ([value isKindOfClass:NSAttributedString.class]) {
        string = [(NSAttributedString *)value string];
    }
    if (!string.length)
        return nil;
    NSString *trimmed = [string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return trimmed.length > 0 ? trimmed : nil;
}

static BOOL SPKNotesLooksLikeNoteModel(id object) {
    if (!object)
        return NO;
    NSString *name = NSStringFromClass([object class]);
    if (![name containsString:@"Note"])
        return NO;
    return [object respondsToSelector:@selector(text)] &&
           ([object respondsToSelector:NSSelectorFromString(@"pk")] ||
            [object respondsToSelector:NSSelectorFromString(@"noteMusicInfo")] ||
            [object respondsToSelector:NSSelectorFromString(@"noteStyle")]);
}

static id SPKNotesResolveNoteModel(id root, NSUInteger depth, NSMutableSet<NSValue *> *visited) {
    if (!root || depth > 4)
        return nil;
    if (SPKNotesLooksLikeNoteModel(root))
        return root;

    NSValue *identity = [NSValue valueWithNonretainedObject:root];
    if ([visited containsObject:identity])
        return nil;
    [visited addObject:identity];

    for (NSString *selectorName in @[ @"note", @"noteModel", @"trayItem", @"noteTrayItem",
                                      @"item", @"viewModel", @"noteViewModel", @"model" ]) {
        id nested = SPKNotesCall(root, selectorName);
        if (nested && nested != root) {
            id model = SPKNotesResolveNoteModel(nested, depth + 1, visited);
            if (model)
                return model;
        }
    }
    return nil;
}

static NSString *SPKNotesTextForNoteModel(id noteModel, id trayViewModel) {
    NSString *text = SPKNotesTrimmedString(SPKNotesCall(noteModel, @"text"));
    if (text)
        return text;
    return SPKNotesTrimmedString(SPKNotesCall(trayViewModel, @"notesAttributedText"));
}

static BOOL SPKNotesHasAudio(id noteModel, id trayViewModel) {
    if (SPKNotesBoolCall(trayViewModel, @"hasPlayableAudio") ||
        SPKNotesBoolCall(trayViewModel, @"hasMusicNoteOrOriginalAudio")) {
        return YES;
    }
    return SPKNotesBoolCall(noteModel, @"hasMusicInfo") ||
           SPKNotesBoolCall(noteModel, @"isOriginalAudioNote") ||
           SPKNotesBoolCall(noteModel, @"hasListeningNowMusicInfo");
}

static NSString *SPKNotesAuthorUsername(id noteModel) {
    id user = SPKNotesCall(noteModel, @"user");
    NSString *username = SPKNotesTrimmedString(SPKNotesCall(user, @"username"));
    if (username)
        return username;
    return SPKNotesTrimmedString(SPKNotesCall(noteModel, @"artistNameForMusicInfo"));
}

// The note's audio track object. Resolve it via the tray view-model's
// -audioTrackWithUserMap:launcherSet: (nil user map, session launcher set);
// keep the note's music-info accessors as fallbacks for the download coordinator.
static NSArray *SPKNotesAudioCandidates(id trayViewModel, id noteModel) {
    if (!SPKNotesHasAudio(noteModel, trayViewModel))
        return nil;

    NSMutableArray *candidates = [NSMutableArray array];

    @try {
        SEL twoArg = @selector(audioTrackWithUserMap:launcherSet:);
        SEL oneArg = NSSelectorFromString(@"audioTrackWithUserMap:");
        id track = nil;
        if ([trayViewModel respondsToSelector:twoArg]) {
            id session = [SPKUtils activeUserSession];
            id launcherSet = session ? [session valueForKey:@"launcherSet"] : nil;
            track = ((id (*)(id, SEL, id, id))objc_msgSend)(trayViewModel, twoArg, nil, launcherSet);
        } else if ([trayViewModel respondsToSelector:oneArg]) {
            track = ((id (*)(id, SEL, id))objc_msgSend)(trayViewModel, oneArg, nil);
        }
        if (track)
            [candidates addObject:track];
    } @catch (__unused NSException *exception) {
    }

    for (NSString *selectorName in @[ @"musicInfoFromMusicOrListeningNow", @"noteMusicInfo",
                                      @"noteListeningNowMusicInfo" ]) {
        id info = SPKNotesCall(noteModel, selectorName);
        if (info)
            [candidates addObject:info];
    }
    if (noteModel)
        [candidates addObject:noteModel];
    if (trayViewModel && trayViewModel != noteModel)
        [candidates addObject:trayViewModel];
    return candidates.count > 0 ? candidates : nil;
}

#pragma mark - Actions

static void SPKNotesCopyText(NSString *text) {
    if (!text.length)
        return;
    [UIPasteboard generalPasteboard].string = text;
    SPKNotify(kSPKNotificationCopyNoteText, @"Copied note text", nil, @"circle_check_filled", SPKNotificationToneSuccess);
}

static void SPKNotesPresentAudioActions(NSArray *audioCandidates, id noteModel,
                                        UIViewController *presenter, UIView *sourceView) {
    SPKAudioItem *item = nil;
    for (id candidate in audioCandidates) {
        if (!candidate)
            continue;
        item = [SPKAudioDownloadCoordinator audioItemFromMediaObject:candidate source:SPKAudioSourceDMNotes];
        if (item)
            break;
    }
    if (!item) {
        SPKNotify(kSPKNotificationDownloadShare,
                  @"Could not find audio URL",
                  @"Refresh the notes tray and try again if the URL expired.",
                  @"error_filled",
                  SPKNotificationToneError);
        return;
    }

    NSString *username = SPKNotesAuthorUsername(noteModel);
    if (username.length > 0 && !item.artist.length)
        item.artist = username;

    SPKGallerySaveMetadata *metadata = [[SPKGallerySaveMetadata alloc] init];
    metadata.source = (int16_t)[item gallerySource];
    metadata.sourceUsername = username.length > 0 ? username : (item.artist.length > 0 ? item.artist : @"notes");
    metadata.sourceMediaPK = item.mediaIdentifier;
    metadata.sourceMediaURLString = item.sourceURLString ?: item.url.absoluteString;

    UIViewController *host = presenter ?: topMostController();
    [SPKDialog presentFromController:host
                                                        title:@"Note Audio"
                                                      message:nil
                                                      actions:@[
                                                          [SPKDialogAction actionWithTitle:@"Save Audio to Files"
                                                                                      style:SPKDialogActionStyleDefault
                                                                                    handler:^{
                                                                                        [SPKAudioDownloadCoordinator performAction:SPKAudioActionSaveToFiles item:item presenter:host sourceView:sourceView metadata:metadata notificationIdentifier:kSPKNotificationDownloadAudio];
                                                                                    }],
                                                          [SPKDialogAction actionWithTitle:@"Share Audio"
                                                                                      style:SPKDialogActionStyleDefault
                                                                                    handler:^{
                                                                                        [SPKAudioDownloadCoordinator performAction:SPKAudioActionConvertAndShare item:item presenter:host sourceView:sourceView metadata:metadata notificationIdentifier:kSPKNotificationDownloadAudioShare];
                                                                                    }],
                                                          [SPKDialogAction actionWithTitle:@"Save Audio to Gallery"
                                                                                      style:SPKDialogActionStyleDefault
                                                                                    handler:^{
                                                                                        [SPKAudioDownloadCoordinator performAction:SPKAudioActionConvertAndSaveToGallery item:item presenter:host sourceView:sourceView metadata:metadata notificationIdentifier:kSPKNotificationDownloadAudioGallery];
                                                                                    }],
                                                          [SPKDialogAction actionWithTitle:@"Play Audio"
                                                                                      style:SPKDialogActionStyleDefault
                                                                                    handler:^{
                                                                                        [SPKAudioDownloadCoordinator performAction:SPKAudioActionPlay item:item presenter:host sourceView:sourceView metadata:metadata notificationIdentifier:kSPKNotificationPlayAudio];
                                                                                    }],
                                                          [SPKDialogAction actionWithTitle:@"Copy audio URL"
                                                                                      style:SPKDialogActionStyleDefault
                                                                                    handler:^{
                                                                                        [SPKAudioDownloadCoordinator performAction:SPKAudioActionCopyURL item:item presenter:host sourceView:sourceView metadata:metadata notificationIdentifier:kSPKNotificationCopyAudioURL];
                                                                                    }],
                                                          [SPKDialogAction actionWithTitle:@"Cancel"
                                                                                      style:SPKDialogActionStyleCancel
                                                                                    handler:nil]
                                                      ]];
}

// Resolves the note's available actions from its tray view model, appending a
// (title, handler-block) pair per enabled+available action, in display order.
static void SPKNotesBuildActionLists(id trayViewModel, NSMutableArray<NSString *> *titles, NSMutableArray *handlers) {
    BOOL audioEnabled = [SPKUtils getBoolPref:@"msgs_download_notes_audio"] &&
                        [SPKUtils getBoolPref:@"downloads_audio_enabled"];
    BOOL copyEnabled = [SPKUtils getBoolPref:@"msgs_copy_note_text"];

    id noteModel = SPKNotesResolveNoteModel(trayViewModel, 0, [NSMutableSet set]) ?: trayViewModel;
    NSString *text = copyEnabled ? SPKNotesTextForNoteModel(noteModel, trayViewModel) : nil;
    NSArray *audioCandidates = audioEnabled ? SPKNotesAudioCandidates(trayViewModel, noteModel) : nil;

    if (text) {
        NSString *capturedText = text;
        [titles addObject:@"Copy text"];
        [handlers addObject:[^{
                      SPKNotesCopyText(capturedText);
                  } copy]];
    }
    if (audioCandidates) {
        NSArray *capturedAudio = audioCandidates;
        id capturedNote = noteModel;
        [titles addObject:@"Save audio"];
        [handlers addObject:[^{
                      SPKNotesPresentAudioActions(capturedAudio, capturedNote, topMostController(), nil);
                  } copy]];
    }
}

#pragma mark - Prism-menu injection (newer builds)

// The tray long press (via the interaction helper) stashes the note's view model +
// cell and a timestamp; the prism menu view, laid out immediately after, reads them.
static __weak id sSPKNotesTrayViewModel = nil;
static __weak UIView *sSPKNotesPogCell = nil;
static NSTimeInterval sSPKNotesLongPressTime = 0;

static const void *kSPKNotesWrapperKey = &kSPKNotesWrapperKey;
static const void *kSPKNotesExtraHeightKey = &kSPKNotesExtraHeightKey;
static const void *kSPKNotesTapTargetKey = &kSPKNotesTapTargetKey;

static void (*orig_SPKNotesDidLongTap4)(id, SEL, id, id, id, long long) = NULL;
static void (*orig_SPKNotesPrismLayout)(id, SEL) = NULL;
static CGSize (*orig_SPKNotesPrismSizeThatFits)(id, SEL, CGSize) = NULL;
static void (*orig_SPKNotesPrismWillMoveToWindow)(id, SEL, id) = NULL;

// Clears the injection stash once the prism menu has consumed it.
static void SPKNotesConsumeStash(void) {
    sSPKNotesTrayViewModel = nil;
    sSPKNotesPogCell = nil;
}

// Backs the injected "Note actions" row: dismisses the prism menu, then opens the
// Sparkle sheet for the stashed note.
@interface SPKNotesInjectedTapTarget : NSObject <UIGestureRecognizerDelegate>
@property (nonatomic, weak) UIView *menuView;
@property (nonatomic, strong) UIControl *wrapper;
@property (nonatomic, copy) void (^handler)(void);
@end

@implementation SPKNotesInjectedTapTarget
- (void)spk_tap {
    UIView *menuView = self.menuView;
    void (^handler)(void) = self.handler;
    UIWindow *window = menuView.window;
    [menuView removeFromSuperview];
    window.hidden = YES;
    dispatch_async(dispatch_get_main_queue(), ^{
        if (handler)
            handler();
    });
}

// Recognize alongside IG's own menu gestures (otherwise they swallow our tap), but
// only for touches that land on our injected row.
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
    shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return YES;
}
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    return [touch.view isDescendantOfView:self.wrapper];
}
@end

static Class SPKNotesResolveClass(NSString *dotted, NSString *mangled) {
    Class cls = objc_getClass(dotted.UTF8String);
    if (!cls && mangled)
        cls = objc_getClass(mangled.UTF8String);
    if (!cls)
        cls = NSClassFromString(dotted);
    return cls;
}

// Builds one injected prism row (a menu item view wrapped in a tappable UIControl)
// for `title`, positioned in `frame` within `container`, running `handler` on tap.
static UIControl *SPKNotesBuildRow(Class builderClass, Class itemViewClass, UIView *menuView,
                                   NSString *title, BOOL edrEnabled, CGRect frame, void (^handler)(void)) {
    id builder = ((id (*)(id, SEL, id))objc_msgSend)([builderClass alloc], @selector(initWithTitle:), title);
    builder = ((id (*)(id, SEL, id))objc_msgSend)(builder, @selector(withHandler:), ^{
                                                           });
    id menuItem = ((id (*)(id, SEL))objc_msgSend)(builder, @selector(build));
    if (!menuItem)
        return nil;

    UIView *itemView = ((id (*)(id, SEL, id, BOOL, BOOL, BOOL))objc_msgSend)(
        [itemViewClass alloc], @selector(initWithMenuItem:edrEnabled:isHeader:isSubmenu:), menuItem, edrEnabled, NO, NO);
    if (!itemView)
        return nil;

    UIControl *wrapper = [[UIControl alloc] initWithFrame:frame];
    itemView.frame = wrapper.bounds;
    itemView.userInteractionEnabled = NO;
    [wrapper addSubview:itemView];

    SPKNotesInjectedTapTarget *target = [SPKNotesInjectedTapTarget new];
    target.menuView = menuView;
    target.wrapper = wrapper;
    target.handler = handler;
    [wrapper addTarget:target action:@selector(spk_tap) forControlEvents:UIControlEventTouchUpInside];
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:target action:@selector(spk_tap)];
    tap.delegate = target;
    [wrapper addGestureRecognizer:tap];
    // Retain the target for the wrapper's lifetime.
    objc_setAssociatedObject(wrapper, kSPKNotesTapTargetKey, target, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return wrapper;
}

static void SPKNotesPrismLayout(id self, SEL _cmd) {
    if (orig_SPKNotesPrismLayout)
        orig_SPKNotesPrismLayout(self, _cmd);

    if (objc_getAssociatedObject(self, kSPKNotesWrapperKey))
        return; // already injected
    BOOL audioEnabled = [SPKUtils getBoolPref:@"msgs_download_notes_audio"] &&
                        [SPKUtils getBoolPref:@"downloads_audio_enabled"];
    BOOL copyEnabled = [SPKUtils getBoolPref:@"msgs_copy_note_text"];
    if (!audioEnabled && !copyEnabled)
        return;

    id viewModel = sSPKNotesTrayViewModel;
    if (!viewModel)
        return;
    if (CACurrentMediaTime() - sSPKNotesLongPressTime > 3.0)
        return; // stale / not a note menu

    id elementViews = SPKNotesIvarValue(self, "menuElementViews");
    if (![elementViews isKindOfClass:NSArray.class] || [(NSArray *)elementViews count] == 0)
        return;
    UIView *lastItem = [(NSArray *)elementViews lastObject];
    UIView *container = lastItem.superview;
    if (!lastItem || !container)
        return;

    Class builderClass = NSClassFromString(@"IGDSPrismMenuItemBuilder");
    Class itemViewClass = SPKNotesResolveClass(@"IGDSPrismMenu.IGDSPrismMenuItemView",
                                               @"_TtC13IGDSPrismMenu21IGDSPrismMenuItemView");
    if (!builderClass || !itemViewClass)
        return;
    if (![builderClass instancesRespondToSelector:@selector(initWithTitle:)] ||
        ![builderClass instancesRespondToSelector:@selector(withHandler:)] ||
        ![builderClass instancesRespondToSelector:@selector(build)] ||
        ![itemViewClass instancesRespondToSelector:@selector(initWithMenuItem:edrEnabled:isHeader:isSubmenu:)]) {
        return;
    }

    // Resolve the note's available actions up front.
    NSMutableArray<NSString *> *titles = [NSMutableArray array];
    NSMutableArray *handlers = [NSMutableArray array];
    SPKNotesBuildActionLists(viewModel, titles, handlers);
    if (titles.count == 0)
        return;

    BOOL edrEnabled = NO;
    Ivar edrIvar = class_getInstanceVariable([lastItem class], "edrEnabled");
    if (edrIvar)
        edrEnabled = ((char *)(__bridge void *)lastItem)[ivar_getOffset(edrIvar)] & 1;

    CGRect lastFrame = lastItem.frame;
    CGFloat rowHeight = lastFrame.size.height;
    CGFloat y = CGRectGetMaxY(lastFrame);
    NSMutableArray<UIControl *> *wrappers = [NSMutableArray array];
    for (NSUInteger i = 0; i < titles.count; i++) {
        CGRect frame = CGRectMake(lastFrame.origin.x, y, lastFrame.size.width, rowHeight);
        void (^handler)(void) = handlers[i];
        UIControl *wrapper = SPKNotesBuildRow(builderClass, itemViewClass, (UIView *)self,
                                              titles[i], edrEnabled, frame, handler);
        if (!wrapper)
            continue;
        [container addSubview:wrapper];
        [wrappers addObject:wrapper];
        y += rowHeight;
    }
    if (wrappers.count == 0)
        return;

    // Grow the menu (and every ancestor up to it) to fit the extra rows, and stop
    // them clipping the additions.
    CGFloat extra = rowHeight * wrappers.count;
    UIView *menuView = (UIView *)self;
    CGRect menuFrame = menuView.frame;
    menuFrame.size.height += extra;
    menuView.frame = menuFrame;
    menuView.clipsToBounds = NO;
    for (UIView *view = container; view && view != menuView; view = view.superview) {
        CGRect frame = view.frame;
        frame.size.height += extra;
        view.frame = frame;
        view.clipsToBounds = NO;
    }

    objc_setAssociatedObject(self, kSPKNotesWrapperKey, wrappers, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, kSPKNotesExtraHeightKey, @(extra), OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    SPKLog(@"Notes", @"[Sparkle] injected %lu note action row(s) into prism menu", (unsigned long)wrappers.count);
    SPKNotesConsumeStash();
}

static CGSize SPKNotesPrismSizeThatFits(id self, SEL _cmd, CGSize size) {
    CGSize fitted = orig_SPKNotesPrismSizeThatFits ? orig_SPKNotesPrismSizeThatFits(self, _cmd, size) : size;
    NSNumber *extra = objc_getAssociatedObject(self, kSPKNotesExtraHeightKey);
    if (extra)
        fitted.height += extra.doubleValue;
    return fitted;
}

static void SPKNotesPrismWillMoveToWindow(id self, SEL _cmd, id window) {
    if (!window) {
        NSArray<UIView *> *wrappers = objc_getAssociatedObject(self, kSPKNotesWrapperKey);
        for (UIView *wrapper in wrappers)
            [wrapper removeFromSuperview];
        objc_setAssociatedObject(self, kSPKNotesWrapperKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(self, kSPKNotesExtraHeightKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (orig_SPKNotesPrismWillMoveToWindow)
        orig_SPKNotesPrismWillMoveToWindow(self, _cmd, window);
}

// IGDirectNotesTrayCellInteractionHelper long-tap delegate callback (arg2 = view
// model, arg3 = cell). Stashes them for the prism layout hook.
static void SPKNotesDidLongTap(id self, SEL _cmd, id sectionController, id viewModel, id cell, long long position) {
    BOOL audioEnabled = [SPKUtils getBoolPref:@"msgs_download_notes_audio"] &&
                        [SPKUtils getBoolPref:@"downloads_audio_enabled"];
    BOOL copyEnabled = [SPKUtils getBoolPref:@"msgs_copy_note_text"];
    if (audioEnabled || copyEnabled) {
        sSPKNotesTrayViewModel = viewModel;
        sSPKNotesPogCell = [cell isKindOfClass:UIView.class] ? (UIView *)cell : nil;
        sSPKNotesLongPressTime = CACurrentMediaTime();
    }
    if (orig_SPKNotesDidLongTap4)
        orig_SPKNotesDidLongTap4(self, _cmd, sectionController, viewModel, cell, position);
}

#pragma mark - Install

static void SPKNotesInstallPrismViewHooks(void) {
    Class prismViewClass = SPKNotesResolveClass(@"IGDSPrismMenu.IGDSPrismMenuView",
                                                @"_TtC13IGDSPrismMenu17IGDSPrismMenuView");
    if (!prismViewClass)
        return;
    MSHookMessageEx(prismViewClass, @selector(layoutSubviews), (IMP)SPKNotesPrismLayout, (IMP *)&orig_SPKNotesPrismLayout);
    MSHookMessageEx(prismViewClass, @selector(sizeThatFits:), (IMP)SPKNotesPrismSizeThatFits, (IMP *)&orig_SPKNotesPrismSizeThatFits);
    MSHookMessageEx(prismViewClass, @selector(willMoveToWindow:), (IMP)SPKNotesPrismWillMoveToWindow, (IMP *)&orig_SPKNotesPrismWillMoveToWindow);
}

extern "C" void SPKInstallNotesActionsHooksIfEnabled(void) {
    BOOL audioEnabled = [SPKUtils getBoolPref:@"msgs_download_notes_audio"] &&
                        [SPKUtils getBoolPref:@"downloads_audio_enabled"];
    BOOL copyEnabled = [SPKUtils getBoolPref:@"msgs_copy_note_text"];
    if (!audioEnabled && !copyEnabled)
        return;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // Inject into the native prism menu via the interaction helper.
        //
        // NOTE: IG 410.1.0 is not supported. It has no interaction helper and opens
        // an IGActionSheetController (not a prism menu) for the note long press, and
        // resolving/injecting there proved too unreliable — so notes actions are a
        // no-op on 410 until a dependable hook is found.
        Class helperClass = SPKNotesResolveClass(@"IGDirectNotesTrayUISwift.IGDirectNotesTrayCellInteractionHelper",
                                                 @"_TtC24IGDirectNotesTrayUISwift38IGDirectNotesTrayCellInteractionHelper");
        SEL longTap = @selector(traySectionController:didLongTapViewModel:pogCell:itemPosition:);
        if (helperClass && ![helperClass instancesRespondToSelector:longTap]) {
            longTap = NSSelectorFromString(@"traySectionController:didLongTapViewModel:userCellNoteView:itemPosition:");
        }
        if (helperClass && [helperClass instancesRespondToSelector:longTap]) {
            MSHookMessageEx(helperClass, longTap, (IMP)SPKNotesDidLongTap, (IMP *)&orig_SPKNotesDidLongTap4);
            SPKNotesInstallPrismViewHooks();
        }
    });
}
