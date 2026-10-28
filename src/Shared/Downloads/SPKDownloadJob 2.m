#import "SPKDownloadJob.h"
#import "../Account/SPKAccountManager.h"

@interface SPKDownloadJob ()
@property (nonatomic, strong, readwrite) SPKDownloadRequest *request;
@property (nonatomic, strong, readwrite) NSMutableArray<SPKDownloadItem *> *mutableItems;
@end

@implementation SPKDownloadJob

- (instancetype)initWithRequest:(SPKDownloadRequest *)request jobID:(NSString *)jobID {
    if (!(self = [super init]))
        return nil;
    _request = [request copy];
    _jobID = [jobID copy];
    _createdAt = request.createdAt > 0 ? request.createdAt : NSDate.date.timeIntervalSince1970;
    _updatedAt = _createdAt;
    NSMutableArray *items = [NSMutableArray array];
    [request.items enumerateObjectsUsingBlock:^(SPKDownloadItemRequest *itemRequest, NSUInteger idx, BOOL *stop) {
        (void)stop;
        SPKDownloadItemRequest *copy = [itemRequest copy];
        if (copy.index == 0 && idx > 0)
            copy.index = (NSInteger)idx;
        SPKDownloadItem *item = [[SPKDownloadItem alloc] initWithRequest:copy];
        [items addObject:item];
    }];
    _mutableItems = items;
    _title = request.titleOverride;
    // Stamp the initiating account (overridden by fromDictionary for stored jobs).
    _ownerAccountPK = [SPKAccountManager currentAccountPK];
    [self recomputeDerivedState];
    return self;
}

- (NSArray<SPKDownloadItem *> *)items {
    return [self.mutableItems copy];
}

- (void)markActiveItemsInterrupted {
    for (SPKDownloadItem *item in self.mutableItems) {
        if (item.state == SPKDownloadStateQueued || item.state == SPKDownloadStateRunning || item.state == SPKDownloadStateFinalizing || item.state == SPKDownloadStateWaitingForPreflight) {
            item.state = SPKDownloadStateInterrupted;
            item.error = SPKDownloadError(SPKDownloadErrorInterrupted, @"Interrupted when Instagram exited", @"Retry from download history.");
            item.progress = 1.0;
        }
    }
    [self recomputeDerivedState];
}

- (void)replaceItems:(NSArray<SPKDownloadItem *> *)items {
    self.mutableItems = [items mutableCopy];
    [self recomputeDerivedState];
}

- (nullable SPKDownloadItem *)itemWithIdentifier:(NSString *)itemID {
    for (SPKDownloadItem *item in self.mutableItems) {
        if ([item.itemID isEqualToString:itemID])
            return item;
    }
    return nil;
}

- (void)recomputeDerivedState {
    NSMutableArray<NSNumber *> *states = [NSMutableArray array];
    double progressSum = 0;
    for (SPKDownloadItem *item in self.mutableItems) {
        [states addObject:@(item.state)];
        progressSum += item.progress;
    }
    self.state = SPKDownloadDerivedJobState(states);
    self.aggregateProgress = self.mutableItems.count > 0 ? progressSum / (double)self.mutableItems.count : 0;
    switch (self.request.destination) {
    case SPKDownloadDestinationPhotos:
        self.completionAction = @"openPhotos";
        break;
    case SPKDownloadDestinationGallery:
        self.completionAction = @"openGallery";
        break;
    default:
        self.completionAction = nil;
        break;
    }
}

- (id)copyWithZone:(NSZone *)zone {
    SPKDownloadJob *c = [[[self class] allocWithZone:zone] initWithRequest:self.request jobID:self.jobID];
    c.updatedAt = _updatedAt;
    c.state = _state;
    c.aggregateProgress = _aggregateProgress;
    c.title = [_title copy];
    c.detail = [_detail copy];
    c.completionAction = [_completionAction copy];
    c.ownerAccountPK = [_ownerAccountPK copy]; // preserve owner (init re-stamped it)
    NSMutableArray *items = [NSMutableArray array];
    for (SPKDownloadItem *item in self.items) {
        [items addObject:[item copy]];
    }
    [c replaceItems:items];
    return c;
}

- (NSDictionary *)dictionaryRepresentation {
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    d[@"jobID"] = self.jobID ?: @"";
    d[@"createdAt"] = @(self.createdAt);
    d[@"updatedAt"] = @(self.updatedAt);
    d[@"state"] = @(self.state);
    d[@"aggregateProgress"] = @(self.aggregateProgress);
    if (self.title)
        d[@"title"] = self.title;
    if (self.detail)
        d[@"detail"] = self.detail;
    if (self.completionAction)
        d[@"completionAction"] = self.completionAction;
    if (self.ownerAccountPK)
        d[@"ownerAccountPK"] = self.ownerAccountPK;
    d[@"request"] = [self.request dictionaryRepresentation];
    NSMutableArray *items = [NSMutableArray array];
    for (SPKDownloadItem *item in self.items) {
        [items addObject:[item dictionaryRepresentation]];
    }
    d[@"items"] = items;
    return d;
}

+ (instancetype)fromDictionary:(NSDictionary *)dict {
    if (![dict isKindOfClass:NSDictionary.class])
        return nil;
    SPKDownloadRequest *request = [SPKDownloadRequest fromDictionary:dict[@"request"]];
    if (!request)
        return nil;
    NSString *jobID = dict[@"jobID"] ?: NSUUID.UUID.UUIDString;
    SPKDownloadJob *job = [[self alloc] initWithRequest:request jobID:jobID];
    job.updatedAt = [dict[@"updatedAt"] doubleValue];
    job.title = dict[@"title"];
    job.detail = dict[@"detail"];
    job.completionAction = dict[@"completionAction"];
    job.ownerAccountPK = dict[@"ownerAccountPK"]; // nil for legacy/pre-feature jobs (overrides init stamp)
    NSMutableArray *items = [NSMutableArray array];
    NSArray *storedItems = dict[@"items"] ?: @[];
    [storedItems enumerateObjectsUsingBlock:^(NSDictionary *entry, NSUInteger idx, BOOL *stop) {
        (void)stop;
        SPKDownloadItemRequest *itemRequest = idx < request.items.count ? request.items[idx] : nil;
        SPKDownloadItem *item = [SPKDownloadItem fromDictionary:entry request:itemRequest];
        if (item)
            [items addObject:item];
    }];
    if (items.count > 0)
        [job replaceItems:items];
    [job recomputeDerivedState];
    return job;
}

@end
