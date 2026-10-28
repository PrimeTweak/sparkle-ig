#import "SPKDeletedMessagesFilter.h"

@implementation SPKDeletedMessagesFilter

- (instancetype)init {
    if ((self = [super init])) {
        _kinds = [NSMutableSet set];
        _dateRange = SPKDMDateRangeAll;
        _sort = SPKDMSortRecent;
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
    SPKDeletedMessagesFilter *c = [[SPKDeletedMessagesFilter allocWithZone:zone] init];
    c.searchText = self.searchText;
    c.kinds = [self.kinds mutableCopy];
    c.dateRange = self.dateRange;
    c.customStart = self.customStart;
    c.customEnd = self.customEnd;
    c.sort = self.sort;
    return c;
}

- (BOOL)isEmpty {
    return self.searchText.length == 0 && !self.hasKindFilter && self.dateRange == SPKDMDateRangeAll;
}

- (BOOL)hasKindFilter {
    return self.kinds.count > 0;
}

- (BOOL)matchesKind:(SPKDeletedMessageKind)kind {
    if (!self.hasKindFilter)
        return YES;
    return [self.kinds containsObject:@(kind)];
}

- (void)toggleKind:(SPKDeletedMessageKind)kind {
    NSNumber *k = @(kind);
    if ([self.kinds containsObject:k])
        [self.kinds removeObject:k];
    else
        [self.kinds addObject:k];
}

- (void)clearKinds {
    [self.kinds removeAllObjects];
}

#pragma mark - Date helpers

- (NSDate *)effectiveStart {
    if (self.dateRange == SPKDMDateRangeCustom)
        return self.customStart;
    NSCalendar *cal = NSCalendar.currentCalendar;
    NSDate *now = [NSDate date];
    switch (self.dateRange) {
    case SPKDMDateRangeToday:
        return [cal startOfDayForDate:now];
    case SPKDMDateRangeWeek:
        return [cal dateByAddingUnit:NSCalendarUnitDay value:-7 toDate:now options:0];
    case SPKDMDateRangeMonth:
        return [cal dateByAddingUnit:NSCalendarUnitDay value:-30 toDate:now options:0];
    default:
        return nil;
    }
}

- (NSDate *)effectiveEnd {
    if (self.dateRange == SPKDMDateRangeCustom)
        return self.customEnd;
    return nil;
}

- (BOOL)matchKindForMessage:(SPKDeletedMessage *)m {
    return [self matchesKind:m.kind];
}

- (BOOL)matchDateForMessage:(SPKDeletedMessage *)m {
    NSDate *key = m.deletedAt ?: m.capturedAt ?
                                              : m.sentAt;
    if (!key)
        return self.dateRange == SPKDMDateRangeAll;
    NSDate *start = [self effectiveStart];
    NSDate *end = [self effectiveEnd];
    if (start && [key compare:start] == NSOrderedAscending)
        return NO;
    if (end && [key compare:end] == NSOrderedDescending)
        return NO;
    return YES;
}

- (BOOL)matchSearchForMessage:(SPKDeletedMessage *)m {
    NSString *q = self.searchText;
    if (!q.length)
        return YES;
    NSStringCompareOptions opt = NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch;
    NSArray *fields = @[ m.text ?: @"", m.previewText ?: @"",
                         m.senderUsername ?: @"", m.senderFullName ?: @"",
                         m.threadTitle ?: @"" ];
    for (NSString *f in fields) {
        if ([f rangeOfString:q options:opt].location != NSNotFound)
            return YES;
    }
    return NO;
}

#pragma mark - Apply

- (NSArray<SPKDeletedMessage *> *)apply:(NSArray<SPKDeletedMessage *> *)messages {
    NSMutableArray<SPKDeletedMessage *> *out = [NSMutableArray arrayWithCapacity:messages.count];
    for (SPKDeletedMessage *m in messages) {
        if (![self matchKindForMessage:m])
            continue;
        if (![self matchDateForMessage:m])
            continue;
        if (![self matchSearchForMessage:m])
            continue;
        [out addObject:m];
    }
    NSDate * (^key)(SPKDeletedMessage *) = ^NSDate *(SPKDeletedMessage *m) {
        return m.deletedAt ?: m.capturedAt ?
                          : m.sentAt       ?
                                           : [NSDate distantPast];
    };
    if (self.sort == SPKDMSortOldest) {
        [out sortUsingComparator:^(SPKDeletedMessage *a, SPKDeletedMessage *b) {
            return [key(a) compare:key(b)];
        }];
    } else {
        [out sortUsingComparator:^(SPKDeletedMessage *a, SPKDeletedMessage *b) {
            return [key(b) compare:key(a)];
        }];
    }
    return out;
}

- (NSArray<SPKDeletedMessageGroup *> *)applyToGroups:(NSArray<SPKDeletedMessageGroup *> *)groups {
    NSMutableArray<SPKDeletedMessageGroup *> *out = [NSMutableArray arrayWithCapacity:groups.count];
    for (SPKDeletedMessageGroup *g in groups) {
        NSArray *filtered = [self apply:g.messages];
        if (!filtered.count) {
            // Search may still match the sender even when no message body does.
            if (self.searchText.length && !self.hasKindFilter && self.dateRange == SPKDMDateRangeAll) {
                NSStringCompareOptions opt = NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch;
                BOOL hit = ([(g.senderUsername ?: @"") rangeOfString:self.searchText options:opt].location != NSNotFound) || ([(g.senderFullName ?: @"") rangeOfString:self.searchText options:opt].location != NSNotFound) || ([(g.threadTitle ?: @"") rangeOfString:self.searchText options:opt].location != NSNotFound);
                if (!hit)
                    continue;
                filtered = g.messages;
            } else {
                continue;
            }
        }
        SPKDeletedMessageGroup *copy = [SPKDeletedMessageGroup new];
        copy.senderPk = g.senderPk;
        copy.senderUsername = g.senderUsername;
        copy.senderFullName = g.senderFullName;
        copy.senderProfilePicURL = g.senderProfilePicURL;
        copy.isGroup = g.isGroup;
        copy.threadId = g.threadId;
        copy.threadTitle = g.threadTitle;
        copy.threadPhotoURL = g.threadPhotoURL;
        copy.isPinned = g.isPinned;
        copy.isBlocked = g.isBlocked;
        copy.messages = filtered;
        [out addObject:copy];
    }
    if (self.sort == SPKDMSortCountDesc) {
        [out sortUsingComparator:^(SPKDeletedMessageGroup *a, SPKDeletedMessageGroup *b) {
            if (a.isPinned != b.isPinned)
                return a.isPinned ? NSOrderedAscending : NSOrderedDescending;
            if (b.count != a.count)
                return b.count > a.count ? NSOrderedDescending : NSOrderedAscending;
            return [(b.lastDeletedAt ?: [NSDate distantPast]) compare:(a.lastDeletedAt ?: [NSDate distantPast])];
        }];
    } else if (self.sort == SPKDMSortOldest) {
        [out sortUsingComparator:^(SPKDeletedMessageGroup *a, SPKDeletedMessageGroup *b) {
            if (a.isPinned != b.isPinned)
                return a.isPinned ? NSOrderedAscending : NSOrderedDescending;
            return [(a.lastDeletedAt ?: [NSDate distantFuture]) compare:(b.lastDeletedAt ?: [NSDate distantFuture])];
        }];
    } else {
        [out sortUsingComparator:^(SPKDeletedMessageGroup *a, SPKDeletedMessageGroup *b) {
            if (a.isPinned != b.isPinned)
                return a.isPinned ? NSOrderedAscending : NSOrderedDescending;
            return [(b.lastDeletedAt ?: [NSDate distantPast]) compare:(a.lastDeletedAt ?: [NSDate distantPast])];
        }];
    }
    return out;
}

@end
