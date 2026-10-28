#import "../../Shared/UI/SPKDialog.h"
#import "SPKDownloadService.h"

#import "../../Utils.h"
#import "../UI/SPKMediaChrome.h"
#import "../UI/SPKNotificationCenter.h"
#import "SPKDownloadPresenter.h"
#import "SPKDownloadScheduler.h"
#import "SPKDownloadsHistoryViewController.h"

@interface SPKDownloadService ()
@property (nonatomic, strong) SPKDownloadScheduler *scheduler;
@property (nonatomic, strong) SPKDownloadPresenter *presenter;
@end

@implementation SPKDownloadService

+ (instancetype)shared {
    static SPKDownloadService *service;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        service = [SPKDownloadService new];
    });
    return service;
}

- (instancetype)init {
    if (!(self = [super init]))
        return nil;
    _scheduler = [SPKDownloadScheduler new];
    _presenter = [SPKDownloadPresenter new];
    _scheduler.presenter = _presenter;
    _presenter.cancelAllActiveHandler = ^{
        [SPKDownloadService confirmCancelAllActive];
    };
    __weak typeof(self) weakSelf = self;
    _presenter.cancelHandlerForActiveJob = ^(NSString *jobID) {
        [weakSelf confirmCancelForJobID:jobID];
    };
    _presenter.openHistoryForJobID = ^(NSString *jobID) {
        (void)jobID;
        [SPKDownloadService presentDownloadsHistorySheet];
    };
    return self;
}

+ (void)presentDownloadsHistorySheet {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *presenter = topMostController();
        if ([presenter isKindOfClass:UINavigationController.class] &&
            [((UINavigationController *)presenter).topViewController isKindOfClass:SPKDownloadsHistoryViewController.class]) {
            return;
        }
        SPKDownloadsHistoryViewController *vc = [SPKDownloadsHistoryViewController new];
        UINavigationController *nav = [[SPKChromeNavigationController alloc] initWithRootViewController:vc];
        nav.modalPresentationStyle = UIModalPresentationPageSheet;
        UISheetPresentationController *sheet = nav.sheetPresentationController;
        sheet.prefersGrabberVisible = YES;
        sheet.detents = @[
            UISheetPresentationControllerDetent.mediumDetent,
            UISheetPresentationControllerDetent.largeDetent
        ];
        sheet.prefersScrollingExpandsWhenScrolledToEdge = NO;
        [presenter presentViewController:nav animated:YES completion:nil];
    });
}

+ (void)confirmCancelAllActive {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *presenter = topMostController();
        if (!presenter)
            return;
        [SPKDialog presentFromController:presenter
                                                      title:@"Cancel pending downloads"
                                                    message:@"The log and the captured files for this account are removed."
                                                    actions:@[
                                                        [SPKDialogAction actionWithTitle:@"Keep"
                                                                                    style:SPKDialogActionStyleCancel
                                                                                  handler:nil],
                                                        [SPKDialogAction actionWithTitle:@"Cancel all"
                                                                                    style:SPKDialogActionStyleDestructive
                                                                                  handler:^{
                                                                                      [[SPKDownloadService shared] cancelAllActive];
                                                                                  }],
                                                    ]];
    });
}

- (void)cancelAllActive {
    for (SPKDownloadJob *job in [self.scheduler allJobs]) {
        if (job.state == SPKDownloadStateRunning || job.state == SPKDownloadStateQueued || job.state == SPKDownloadStatePending) {
            [self.scheduler cancelJobID:job.jobID];
        }
    }
}

- (void)submitRequest:(SPKDownloadRequest *)request completion:(SPKDownloadSubmissionCompletion)completion {
    if (request.presentationMode != SPKDownloadPresentationModeQuiet) {
        request.notificationIdentifier = request.notificationIdentifier ?: kSPKNotificationDownloadLibrary;
        [self.presenter prepareForNewJobSubmission];
    }
    [self.scheduler submitRequest:request completion:completion];
}

- (NSArray<SPKDownloadJob *> *)jobsMatchingFilter:(SPKDownloadHistoryFilter)filter {
    NSArray<SPKDownloadJob *> *jobs = [self.scheduler allJobs];
    NSArray *filtered = [jobs filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(SPKDownloadJob *job, NSDictionary *bindings) {
                                  (void)bindings;
                                  switch (filter) {
                                  case SPKDownloadHistoryFilterActive:
                                      return job.state == SPKDownloadStateRunning || job.state == SPKDownloadStateFinalizing;
                                  case SPKDownloadHistoryFilterQueued:
                                      return job.state == SPKDownloadStateQueued || job.state == SPKDownloadStatePending;
                                  case SPKDownloadHistoryFilterFailed:
                                      return job.state == SPKDownloadStateFailed || job.state == SPKDownloadStatePartial || job.state == SPKDownloadStateInterrupted;
                                  case SPKDownloadHistoryFilterRecent:
                                      return job.state == SPKDownloadStateSucceeded || job.state == SPKDownloadStateCancelled;
                                  default:
                                      return YES;
                                  }
                              }]];
    return [filtered sortedArrayUsingComparator:^NSComparisonResult(SPKDownloadJob *a, SPKDownloadJob *b) {
        if (a.updatedAt == b.updatedAt)
            return NSOrderedSame;
        return a.updatedAt < b.updatedAt ? NSOrderedDescending : NSOrderedAscending;
    }];
}

- (SPKDownloadJob *)jobWithID:(NSString *)jobID {
    return [self.scheduler jobWithID:jobID];
}

- (void)cancelJobID:(NSString *)jobID {
    [self.scheduler cancelJobID:jobID];
}
- (void)cancelItemID:(NSString *)itemID inJobID:(NSString *)jobID {
    [self.scheduler cancelItemID:itemID inJobID:jobID];
}
- (void)retryJobID:(NSString *)jobID {
    [self.scheduler retryJobID:jobID];
}
- (void)retryItemID:(NSString *)itemID inJobID:(NSString *)jobID {
    [self.scheduler retryItemID:itemID inJobID:jobID];
}
- (void)clearFinishedHistory {
    [self.scheduler clearFinishedHistory];
}
- (void)removeJobID:(NSString *)jobID {
    [self.scheduler removeJobID:jobID];
}

- (BOOL)hasActiveJobWithHiddenPill {
    for (SPKDownloadJob *job in [self.scheduler allJobs]) {
        if ([self.presenter jobIsActive:job]) {
            if ([self.presenter hasActiveJobWithoutPillForJobID:job.jobID]) {
                return YES;
            }
        }
    }
    return NO;
}

- (void)reshowProgressPill {
    for (SPKDownloadJob *job in [self.scheduler allJobs]) {
        if ([self.presenter jobIsActive:job]) {
            if ([self.presenter hasActiveJobWithoutPillForJobID:job.jobID]) {
                [self.presenter reshowPillForJob:job];
                break;
            }
        }
    }
}

- (void)confirmCancelForJobID:(NSString *)jobID {
    if (!jobID)
        return;
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *presenterHost = topMostController();
        if (!presenterHost)
            return;

        NSUInteger activeCount = 0;
        for (SPKDownloadJob *job in [self.scheduler allJobs]) {
            if ([self.presenter jobIsActive:job]) {
                activeCount++;
            }
        }

        NSMutableArray<SPKDialogAction *> *actions = [NSMutableArray array];

        // Keep at the top, blue bold font
        [actions addObject:[SPKDialogAction actionWithTitle:@"Keep" style:SPKDialogActionStyleCancel handler:nil]];

        if (activeCount > 1) {
            [actions addObject:[SPKDialogAction actionWithTitle:@"Cancel this one"
                                                           style:SPKDialogActionStyleDefault
                                                         handler:^{
                                                             [self cancelJobID:jobID];
                                                         }]];
            [actions addObject:[SPKDialogAction actionWithTitle:@"Cancel all"
                                                           style:SPKDialogActionStyleDestructive
                                                         handler:^{
                                                             [self cancelAllActive];
                                                         }]];
        } else {
            [actions addObject:[SPKDialogAction actionWithTitle:@"Cancel"
                                                           style:SPKDialogActionStyleDestructive
                                                         handler:^{
                                                             [self cancelJobID:jobID];
                                                         }]];
        }

        [SPKDialog presentFromController:presenterHost
                                                      title:@"Cancel this download"
                                                    message:activeCount > 1 ? @"Pick the one you are on, or every download running now." : @"The file stops downloading and what was fetched is discarded."
                                                    actions:actions];
    });
}

@end
