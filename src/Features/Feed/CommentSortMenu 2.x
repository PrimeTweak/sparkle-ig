#import "../../Utils.h"
#import "../../InstagramHeaders.h"
#import "../../Shared/UI/SPKChipGlass.h"
#import "../../Shared/UI/SPKNotificationCenter.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import <math.h>

// Reorders a comment thread by the date each comment was posted.
//
// Instagram 441 ships a comment sorting stack of its own — a menu controller,
// a section controller, "Top comments" and "Most recent" labels, a sticky
// preference and an analytics event — but the entries that fill that menu are
// served by the backend, and an account the backend does not serve gets an
// empty list. Measured on device: IGCommentThread._sortOptions comes back as an
// empty array and sortOrder as nil, so asking Instagram to sort is a dead end.
//
// Sorting locally does not need any of that. Every comment already carries its
// own posting date, so the order can be rebuilt from what is on screen.
//
// Measured in the 441 binary and on a live thread:
//   IGCommentThreadViewController  -objectsForListAdapter:            @24@0:8@16
//                                  -scrollViewWillScrollNearBottom:
//                                             triggeredByManualCheck: v28@0:8@16B24
//                                  ivar _listAdapter -> IGListAdapter
//                                  ivar _collectionView -> UICollectionView
//   IGListAdapter                  -performUpdatesAnimated:completion:
//   IGCommentThread                ivar _moreCommentsAvailableBelow (BOOL)
//   IGCommentGroup                 ivar _parentComment -> IGCommentModel
//                                  (no published accessor; read the ivar)
//   IGCommentModel                 -createdAt -> IGDate, -pk -> NSString
//   IGDate                         -timeIntervalSince1970 (double)
//
// IGCommentModel lives in FBSharedFramework rather than the main executable,
// which is why a dump of the app binary alone does not list it.
//
// The list objects are handed back untouched except for their order: comment
// groups are lifted out, sorted, and dropped back into the very positions they
// occupied. Anything that is not a comment — the caption, separators, the
// "view more" row, the typing indicator — keeps its index, so the thread keeps
// its shape whatever the chosen order.

#pragma mark - Preferences

// Master switch. Read once at launch, so it carries requiresRestart.
static NSString *const kSPKCommentSortEnabledKey = @"feed_comments_sort_menu";

// Current order. Read on every pass, so it takes effect without a restart, and
// stored in the defaults, so it carries from one thread to the next and across
// launches.
static NSString *const kSPKCommentSortModeKey = @"feed_comments_sort_mode";

static NSString *const kSPKCommentSortModeDefault = @"default";
static NSString *const kSPKCommentSortModeNewest = @"newest";
static NSString *const kSPKCommentSortModeOldest = @"oldest";



// Preloading pulls the whole thread in before it is read, because sorting can
// only order what has been loaded and a thread that keeps loading keeps
// reshuffling under the reader.
//
// The pace is set by the network rather than by a fixed wait. Instagram's own
// pagination entry point is the one a scroll fires, and a scroll fires it many
// times a second, so it has to tolerate being called while a page is already in
// flight. Asking on a short tick therefore costs nothing when the answer has
// not arrived yet, and starts the next page the instant it has.
static const NSTimeInterval kSPKCommentSortPreloadTick = 0.06;

// Progress is measured by the comment count. When it stops moving for this many
// ticks the thread is treated as finished, which covers a page that fails, a
// flag that never clears, and a connection that drops.
static const NSUInteger kSPKCommentSortPreloadStallTicks = 25;

// Runaway guard. Not a target: the loop is meant to end on the thread saying it
// has nothing more, or on the stall detector. This is what stops a thread with
// tens of thousands of comments from pulling all of them.
static const NSUInteger kSPKCommentSortPreloadMaxRounds = 200;

static const void *kSPKCommentSortEntryAssocKey = &kSPKCommentSortEntryAssocKey;
static const void *kSPKCommentSortTargetAssocKey = &kSPKCommentSortTargetAssocKey;
static const void *kSPKCommentSortPreloadedAssocKey = &kSPKCommentSortPreloadedAssocKey;

// While a finger is on the list, the order handed back is the one already on
// screen. Pages that land mid gesture are held until it ends, so nothing moves
// under the reader; they appear in one go the moment the list comes to rest.
static const void *kSPKCommentSortFrozenAssocKey = &kSPKCommentSortFrozenAssocKey;
static const void *kSPKCommentSortCacheAssocKey = &kSPKCommentSortCacheAssocKey;
static const void *kSPKCommentSortPendingAssocKey = &kSPKCommentSortPendingAssocKey;

static NSString *SPKCommentSortMode(void) {
    NSString *mode = [SPKUtils getStringPref:kSPKCommentSortModeKey];
    if ([mode isEqualToString:kSPKCommentSortModeNewest] ||
        [mode isEqualToString:kSPKCommentSortModeOldest]) {
        return mode;
    }
    return kSPKCommentSortModeDefault;
}

static NSString *SPKCommentSortModeTitle(NSString *mode) {
    if ([mode isEqualToString:kSPKCommentSortModeNewest])
        return @"Newest first";
    if ([mode isEqualToString:kSPKCommentSortModeOldest])
        return @"Oldest first";
    return @"Instagram's order";
}

// One glyph per order, so the control states which one is in force rather than
// only offering to change it. Arrows read at a glance: down for newest on top,
// up for oldest on top, both ways for the order Instagram chose.
static NSString *SPKCommentSortModeSymbol(NSString *mode) {
    if ([mode isEqualToString:kSPKCommentSortModeNewest])
        return @"arrow.down";
    if ([mode isEqualToString:kSPKCommentSortModeOldest])
        return @"arrow.up";
    return @"arrow.up.arrow.down";
}


#pragma mark - Runtime reading

// Reads an object ivar directly. KVC raises on a key the class does not carry,
// and IGCommentGroup publishes no accessor for the comment it holds.
static id SPKCommentSortIvarValue(id object, const char *name) {
    if (!object || !name)
        return nil;
    Ivar ivar = class_getInstanceVariable(object_getClass(object), name);
    if (!ivar)
        return nil;
    const char *encoding = ivar_getTypeEncoding(ivar);
    if (!encoding || (encoding[0] != '@' && encoding[0] != '#'))
        return nil;
    return object_getIvar(object, ivar);
}

// Same idea for a flag. object_getIvar only covers object ivars, so a BOOL is
// read from its offset, and only once the encoding confirms it is one.
static BOOL SPKCommentSortBoolIvar(id object, const char *name, BOOL fallback) {
    if (!object || !name)
        return fallback;
    Ivar ivar = class_getInstanceVariable(object_getClass(object), name);
    if (!ivar)
        return fallback;
    const char *encoding = ivar_getTypeEncoding(ivar);
    if (!encoding || (encoding[0] != 'B' && encoding[0] != 'c'))
        return fallback;
    uint8_t *base = (uint8_t *)(__bridge void *)object;
    return *(base + ivar_getOffset(ivar)) != 0;
}

static id SPKCommentSortSend(id target, SEL selector) {
    if (!target || !selector || ![target respondsToSelector:selector])
        return nil;
    return ((id (*)(id, SEL))objc_msgSend)(target, selector);
}

// The thread model behind a controller, which carries both the comments and the
// flag saying whether more of them are waiting on the server.
static id SPKCommentSortThread(UIViewController *controller) {
    id manager = SPKCommentSortIvarValue(controller, "_threadManager");
    id thread = SPKCommentSortSend(manager, NSSelectorFromString(@"commentThread"));
    if (!thread)
        thread = SPKCommentSortIvarValue(manager, "commentThread");
    return thread;
}

#pragma mark - Sort key

// The posting date of whatever a list object represents, or NAN when the object
// carries no date and therefore must not move.
//
// Two shapes are handled because the adapter is free to hand back either: a
// comment group wrapping its parent comment, or a comment on its own. Reading a
// missing ivar returns nil rather than raising, so an unexpected third shape
// simply falls through to NAN.
static double SPKCommentSortDateForObject(id object) {
    if (!object)
        return NAN;

    id comment = object;
    id parentComment = SPKCommentSortIvarValue(object, "_parentComment");
    if (parentComment)
        comment = parentComment;

    id createdAt = SPKCommentSortSend(comment, NSSelectorFromString(@"createdAt"));
    if (!createdAt)
        return NAN;

    SEL interval = NSSelectorFromString(@"timeIntervalSince1970");
    if (![createdAt respondsToSelector:interval])
        return NAN;

    // objc_msgSend_fpret does not exist on arm64; the plain entry point returns
    // floating point values there.
    return ((double (*)(id, SEL))objc_msgSend)(createdAt, interval);
}

// Rebuilds the list in the requested order.
//
// Only the slots already holding a datable object take part: their contents are
// sorted among themselves and written back into those same slots. Every other
// index is left exactly as the adapter produced it, which is what keeps the
// caption pinned to the top and the composer helpers where Instagram put them.
//
// Each date is read once and carried alongside its object rather than being
// read again inside the comparison. A sort asks for the same value on the order
// of n log n times, and every read here is two ivar lookups and two message
// sends; on a thread of several hundred comments that is tens of thousands of
// sends per pass, on the main thread, while a page is landing. Reading up front
// turns that back into one read per comment.
static NSArray *SPKCommentSortReorder(NSArray *objects, NSString *mode) {
    if (objects.count < 2)
        return objects;

    NSUInteger count = objects.count;
    NSMutableArray *sortableIndexes = [NSMutableArray arrayWithCapacity:count];
    NSMutableArray *sortableObjects = [NSMutableArray arrayWithCapacity:count];
    NSMutableArray<NSNumber *> *sortableDates = [NSMutableArray arrayWithCapacity:count];

    for (NSUInteger index = 0; index < count; index++) {
        id object = objects[index];
        double date = SPKCommentSortDateForObject(object);
        if (isnan(date))
            continue;
        [sortableIndexes addObject:@(index)];
        [sortableObjects addObject:object];
        [sortableDates addObject:@(date)];
    }

    if (sortableObjects.count < 2)
        return objects;

    // Positions are sorted rather than the objects, so each object keeps the
    // date already read for it.
    BOOL newestFirst = [mode isEqualToString:kSPKCommentSortModeNewest];
    NSMutableArray<NSNumber *> *order = [NSMutableArray arrayWithCapacity:sortableObjects.count];
    for (NSUInteger position = 0; position < sortableObjects.count; position++)
        [order addObject:@(position)];

    [order sortUsingComparator:^NSComparisonResult(NSNumber *first, NSNumber *second) {
        double firstDate = sortableDates[first.unsignedIntegerValue].doubleValue;
        double secondDate = sortableDates[second.unsignedIntegerValue].doubleValue;
        if (firstDate == secondDate)
            return NSOrderedSame;
        BOOL firstComesFirst = newestFirst ? (firstDate > secondDate) : (firstDate < secondDate);
        return firstComesFirst ? NSOrderedAscending : NSOrderedDescending;
    }];

    NSMutableArray *reordered = [objects mutableCopy];
    for (NSUInteger position = 0; position < order.count; position++) {
        NSUInteger slot = [sortableIndexes[position] unsignedIntegerValue];
        reordered[slot] = sortableObjects[order[position].unsignedIntegerValue];
    }
    return reordered;
}

#pragma mark - Preloading

// Number of comments the thread holds right now, which is the only honest
// measure of whether a page actually arrived.
static NSUInteger SPKCommentSortLoadedCount(id thread) {
    NSArray *comments = SPKCommentSortSend(thread, NSSelectorFromString(@"comments"));
    if (![comments isKindOfClass:[NSArray class]])
        comments = SPKCommentSortIvarValue(thread, "_comments");
    return [comments isKindOfClass:[NSArray class]] ? comments.count : 0;
}

// One tick of the preload loop: ask for more, then look at whether more came.
static void SPKCommentSortPreloadTick(UIViewController *controller,
                                      NSUInteger round,
                                      NSUInteger lastCount,
                                      NSUInteger stalled) {
    if (!controller || round >= kSPKCommentSortPreloadMaxRounds) {
        return;
    }

    id thread = SPKCommentSortThread(controller);
    if (!thread)
        return;

    NSUInteger count = SPKCommentSortLoadedCount(thread);

    // Default YES: an unreadable flag should not end the loop on the first tick,
    // and the stall detector still bounds it.
    if (!SPKCommentSortBoolIvar(thread, "_moreCommentsAvailableBelow", YES)) {
        return;
    }

    NSUInteger nextStalled = (count > lastCount) ? 0 : (stalled + 1);
    if (nextStalled >= kSPKCommentSortPreloadStallTicks) {
        return;
    }

    SEL nearBottom = NSSelectorFromString(@"scrollViewWillScrollNearBottom:triggeredByManualCheck:");
    if (![controller respondsToSelector:nearBottom]) {
        return;
    }

    id collectionView = SPKCommentSortIvarValue(controller, "_collectionView");
    ((void (*)(id, SEL, id, BOOL))objc_msgSend)(controller, nearBottom, collectionView, YES);

    __weak UIViewController *weakController = controller;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kSPKCommentSortPreloadTick * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        UIViewController *strongController = weakController;
        if (strongController)
            SPKCommentSortPreloadTick(strongController, round + 1, count, nextStalled);
    });
}

// Runs once per thread. Sorting an unsorted order is what makes comments jump,
// so this only runs when an order other than Instagram's is in force.
static void SPKCommentSortStartPreload(UIViewController *controller) {
    if (objc_getAssociatedObject(controller, kSPKCommentSortPreloadedAssocKey))
        return;
    if ([SPKCommentSortMode() isEqualToString:kSPKCommentSortModeDefault])
        return;

    objc_setAssociatedObject(controller, kSPKCommentSortPreloadedAssocKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    SPKCommentSortPreloadTick(controller, 0, 0, 0);
}

#pragma mark - Entry control

@interface SPKCommentSortTarget : NSObject
@property (nonatomic, weak) UIViewController *controller;
@property (nonatomic, weak) UIButton *button;
- (void)cycleSortMode:(UIButton *)sender;
@end

// Keeps the glyph in step with the order actually in force, both when a thread
// opens and after every tap.
static void SPKCommentSortApplySymbol(UIButton *button, NSString *mode) {
    if (!button)
        return;
    // A button applies its own preferred symbol configuration over the one
    // carried by the image, which is why point sizes set on the image alone had
    // no effect and the same arrow measured 16.7 pt whether it was built at
    // 17 pt or at 19 pt.
    //
    // The size is calibrated against Instagram's own send button rather than
    // picked. That button measures 20.3 pt tall with a 2.33 pt stroke, matched
    // exactly by 22 pt at medium weight; this sits one step under it, at
    // roughly 18.5 pt and a 2.12 pt stroke, so the arrow reads a little lighter
    // than the send button beside it without looking thin.
    UIImageSymbolConfiguration *configuration =
        [UIImageSymbolConfiguration configurationWithPointSize:20.0 weight:UIImageSymbolWeightMedium];
    UIImage *symbol = [UIImage systemImageNamed:SPKCommentSortModeSymbol(mode)
                              withConfiguration:configuration];
    [button setImage:symbol forState:UIControlStateNormal];
    [button setPreferredSymbolConfiguration:configuration forImageInState:UIControlStateNormal];
    button.accessibilityValue = SPKCommentSortModeTitle(mode);
}

@implementation SPKCommentSortTarget

// Cycles Instagram's order → newest → oldest → Instagram's order.
//
// A cycling control rather than a popup: the order has three states, the glyph
// already names the one in force, and it keeps the thread free of a menu that
// would cover the comments being reordered.
- (void)cycleSortMode:(UIButton *)sender {
    NSString *current = SPKCommentSortMode();
    NSString *next = kSPKCommentSortModeNewest;
    if ([current isEqualToString:kSPKCommentSortModeNewest])
        next = kSPKCommentSortModeOldest;
    else if ([current isEqualToString:kSPKCommentSortModeOldest])
        next = kSPKCommentSortModeDefault;

    SPKPreferenceSetObject(next, kSPKCommentSortModeKey);
    SPKCommentSortApplySymbol(sender, next);

    UIViewController *controller = self.controller;
    if (!controller)
        return;

    // Asking the adapter to run its update makes it call the data source again,
    // which is where the new order is applied.
    id listAdapter = SPKCommentSortIvarValue(controller, "_listAdapter");
    SEL performUpdates = NSSelectorFromString(@"performUpdatesAnimated:completion:");
    if ([listAdapter respondsToSelector:performUpdates]) {
        ((void (*)(id, SEL, BOOL, id))objc_msgSend)(listAdapter, performUpdates, YES, nil);
    }

    // Leaving Instagram's order needs the pages that sorting will draw from.
    if (![next isEqualToString:kSPKCommentSortModeDefault])
        SPKCommentSortStartPreload(controller);

    SPKNotify(kSPKNotificationCommentSortUnavailable, @"Comment Sorting",
              SPKCommentSortModeTitle(next), @"sort", SPKNotificationToneSuccess);
}

@end

// The sheet's own view, so the control rides along with it.
//
// Comments open in a partial modal sheet that the reader can drag up and down,
// and the thread sits inside it. Anchoring to the window puts the control on
// the media above the sheet and leaves it there while the sheet moves; walking
// the controllers lands on a full screen ancestor for the same reason.
//
// The views are walked instead. Starting at the thread and climbing towards the
// window, the sheet is the highest view still shorter than the window: every
// view above it spans the screen, and the sheet is what carries the grabber,
// the "Comments" title and the send button. A sheet dragged to full height
// stops being shorter, so the last view below the window is kept as a fallback
// and is the right answer in that case too.
static UIView *SPKCommentSortSheetView(UIViewController *controller) {
    UIView *view = [controller isViewLoaded] ? controller.view : nil;
    UIWindow *window = view.window;
    if (!view || !window)
        return nil;

    CGFloat windowHeight = CGRectGetHeight(window.bounds);
    UIView *lastBelowWindow = view;
    UIView *shortest = nil;

    for (UIView *candidate = view; candidate && candidate != window; candidate = candidate.superview) {
        if (candidate.superview == window)
            lastBelowWindow = candidate;
        if (CGRectGetHeight(candidate.bounds) < windowHeight - 1.0)
            shortest = candidate;
    }
    return shortest ?: lastBelowWindow;
}

static void SPKSeatCommentSortEntry(UIViewController *controller) {
    if (objc_getAssociatedObject(controller, kSPKCommentSortEntryAssocKey))
        return;

    UIView *container = SPKCommentSortSheetView(controller);
    if (!container) {
        return;
    }

    SPKCommentSortTarget *target = [SPKCommentSortTarget new];
    target.controller = controller;

    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.tintColor = UIColor.labelColor;
    button.accessibilityLabel = @"Sort comments";
    button.imageView.contentMode = UIViewContentModeScaleAspectFit;
    [button addTarget:target action:@selector(cycleSortMode:) forControlEvents:UIControlEventTouchUpInside];
    SPKCommentSortApplySymbol(button, SPKCommentSortMode());
    target.button = button;

    // A fill under the glass rather than glass alone: on the white comment
    // sheet a clear capsule leaves the glyph with nothing to read against.
    button.backgroundColor = [UIColor.secondarySystemBackgroundColor colorWithAlphaComponent:0.94];
    SPKChipApplyGlass(button, NO, 22.0, nil);
    button.layer.cornerRadius = 22.0;
    button.layer.cornerCurve = kCACornerCurveContinuous;
    button.layer.borderWidth = 0.5;
    button.layer.borderColor = [UIColor.separatorColor colorWithAlphaComponent:0.4].CGColor;
    button.layer.zPosition = 5000.0;

    [container addSubview:button];
    [container bringSubviewToFront:button];

    // Instagram's send button holds the trailing corner of the sheet header, so
    // the control takes the leading side at the same height. Measuring from the
    // safe area keeps it right whether the sheet is partial, where the inset is
    // zero, or raised to full height, where it is not.
    //
    // The side inset mirrors the send button rather than being chosen: that
    // button sits 19.7 pt from the trailing edge, measured on a capture, so the
    // same figure on the leading side puts the two in balance across the title.
    UILayoutGuide *guide = container.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [button.widthAnchor constraintEqualToConstant:44.0],
        [button.heightAnchor constraintEqualToConstant:44.0],
        [button.leadingAnchor constraintEqualToAnchor:guide.leadingAnchor constant:19.7],
        [button.topAnchor constraintEqualToAnchor:guide.topAnchor constant:0.5],
    ]];

    objc_setAssociatedObject(controller, kSPKCommentSortTargetAssocKey, target, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(controller, kSPKCommentSortEntryAssocKey, button, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

}

static void SPKRemoveCommentSortEntry(UIViewController *controller) {
    UIButton *button = objc_getAssociatedObject(controller, kSPKCommentSortEntryAssocKey);
    if (!button)
        return;
    [button removeFromSuperview];
    objc_setAssociatedObject(controller, kSPKCommentSortEntryAssocKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(controller, kSPKCommentSortTargetAssocKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

#pragma mark - Hooks

%group SPKCommentSortHooks

%hook IGCommentThreadViewController

// The data source call that decides the order of the whole thread. Returning a
// reordered copy is enough: the adapter diffs it against what is on screen and
// moves the cells itself.
- (NSArray *)objectsForListAdapter:(id)listAdapter {
    NSArray *objects = %orig;
    if (![objects isKindOfClass:[NSArray class]] || objects.count < 2)
        return objects;

    NSString *mode = SPKCommentSortMode();
    if ([mode isEqualToString:kSPKCommentSortModeDefault])
        return objects;

    // A page arriving mid scroll would otherwise slide the thread under the
    // finger. Handing back what is already displayed makes the adapter see no
    // change at all, so the list holds still until the gesture ends.
    //
    // The scroll view is asked directly rather than trusting a delegate call to
    // arrive: measured on a recording, content still changed during every drag
    // while a flag set from the delegate was supposed to prevent exactly that.
    // Its own dragging state cannot be missed the way a callback can.
    UIScrollView *listView = SPKCommentSortIvarValue(self, "_collectionView");
    BOOL inMotion = [listView isKindOfClass:[UIScrollView class]] &&
                    (listView.isTracking || listView.isDragging || listView.isDecelerating);
    if (inMotion || objc_getAssociatedObject(self, kSPKCommentSortFrozenAssocKey)) {
        NSArray *frozen = objc_getAssociatedObject(self, kSPKCommentSortCacheAssocKey);
        if (frozen.count > 0) {
            // Remember that an update was withheld, so it can be applied once
            // the list comes to rest even if no delegate call announces it.
            objc_setAssociatedObject(self, kSPKCommentSortPendingAssocKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            return frozen;
        }
    }

    NSArray *reordered = SPKCommentSortReorder(objects, mode);
    objc_setAssociatedObject(self, kSPKCommentSortCacheAssocKey, reordered, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    return reordered;
}

// Applies a withheld update once the list is at rest.
//
// The delegate callbacks are hooked as well, but a callback that never arrives
// would leave the thread frozen on stale content; this check cannot be skipped.
static void SPKCommentSortFlushWhenIdle(UIViewController *controller) {
    if (!objc_getAssociatedObject(controller, kSPKCommentSortPendingAssocKey))
        return;

    UIScrollView *listView = SPKCommentSortIvarValue(controller, "_collectionView");
    BOOL inMotion = [listView isKindOfClass:[UIScrollView class]] &&
                    (listView.isTracking || listView.isDragging || listView.isDecelerating);

    if (!inMotion) {
        objc_setAssociatedObject(controller, kSPKCommentSortPendingAssocKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(controller, kSPKCommentSortFrozenAssocKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

        id listAdapter = SPKCommentSortIvarValue(controller, "_listAdapter");
        SEL performUpdates = NSSelectorFromString(@"performUpdatesAnimated:completion:");
        if ([listAdapter respondsToSelector:performUpdates])
            ((void (*)(id, SEL, BOOL, id))objc_msgSend)(listAdapter, performUpdates, NO, nil);
        return;
    }

    __weak UIViewController *weakController = controller;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIViewController *strongController = weakController;
        if (strongController)
            SPKCommentSortFlushWhenIdle(strongController);
    });
}

// Finger down: hold the order still for the length of the gesture.
- (void)scrollViewWillBeginDragging:(id)scrollView {
    %orig;
    objc_setAssociatedObject(self, kSPKCommentSortFrozenAssocKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    SPKCommentSortFlushWhenIdle((UIViewController *)self);
}

// At rest: let go, and fold in whatever arrived while the list was held.
- (void)scrollViewDidEndScrolling:(id)scrollView {
    %orig;
    objc_setAssociatedObject(self, kSPKCommentSortFrozenAssocKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    SPKCommentSortFlushWhenIdle((UIViewController *)self);
}

// Earliest point the thread exists. Preloading from here rather than from the
// appearance callback buys the whole presentation animation, which is where the
// first pages can land before anything is on screen to be moved by them.
- (void)viewDidLoad {
    %orig;
    SPKCommentSortStartPreload((UIViewController *)self);
}

- (void)viewWillAppear:(BOOL)animated {
    %orig;
    SPKCommentSortStartPreload((UIViewController *)self);
}

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    SPKSeatCommentSortEntry((UIViewController *)self);
    SPKCommentSortStartPreload((UIViewController *)self);

    // The sheet is not always laid out on the first pass.
    __weak UIViewController *weakSelf = (UIViewController *)self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIViewController *strongSelf = weakSelf;
        if (strongSelf)
            SPKSeatCommentSortEntry(strongSelf);
    });
}

- (void)viewDidDisappear:(BOOL)animated {
    SPKRemoveCommentSortEntry((UIViewController *)self);
    %orig;
}

%end

%end

void SPKInstallCommentSortMenuHooksIfEnabled(void) {
    BOOL enabled = [SPKUtils getBoolPref:kSPKCommentSortEnabledKey];
    if (!enabled)
        return;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        %init(SPKCommentSortHooks);
    });
}
