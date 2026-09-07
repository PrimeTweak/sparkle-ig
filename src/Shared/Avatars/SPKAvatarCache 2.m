#import "SPKAvatarCache.h"
#import "../../Networking/SPKInstagramAPI.h"
#import "../SPKStoragePaths.h"

static NSTimeInterval const kSPKAvatarTTL = 24 * 60 * 60; // refresh at most once per day
static CGFloat const kSPKAvatarPixelSize = 120.0;         // stored square size (pre-scale)
static NSString *const kSPKAvatarMigrationKey = @"spk_avatar_cache_migrated_v1";

// Fresh-URL resolution hits IG's private API (users/<pk>/info/), which is
// rate-limited — so cap concurrency and space the calls out. CDN image GETs are
// unthrottled (a different host that tolerates bursts).
static NSUInteger const kSPKMaxConcurrentResolves = 3;
static NSTimeInterval const kSPKResolveSpacing = 0.35;

static UIImage *SPKAvatarSquareImage(UIImage *image);

@interface SPKAvatarCache ()
@property (nonatomic, strong) NSCache<NSString *, UIImage *> *memoryCache;
@property (nonatomic, strong) dispatch_queue_t ioQueue;
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, strong) NSMutableSet<NSString *> *inflight;
// PKs whose fresh-URL resolution already failed this session — avoids hammering
// users/<pk>/info/ for private/deleted/unresolvable users. Cleared on purge.
@property (nonatomic, strong) NSMutableSet<NSString *> *resolveFailed;
// Throttle state for API resolutions (all touched only on ioQueue).
@property (nonatomic, strong) NSMutableArray *pendingResolves;
@property (nonatomic, assign) NSUInteger activeResolveCount;
@property (nonatomic, assign) NSTimeInterval lastResolveFire;
@end

@implementation SPKAvatarCache

+ (instancetype)shared {
    static SPKAvatarCache *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [SPKAvatarCache new];
    });
    return instance;
}

- (instancetype)init {
    if ((self = [super init])) {
        _memoryCache = [NSCache new];
        // Tuned for long analyzer lists — smaller limits evict visible rows
        // mid-scroll so revisits show grey placeholders.
        _memoryCache.countLimit = 512;
        _ioQueue = dispatch_queue_create("com.sparkle.avatars", DISPATCH_QUEUE_SERIAL);
        _inflight = [NSMutableSet set];
        _resolveFailed = [NSMutableSet set];
        _pendingResolves = [NSMutableArray array];
        NSURLSessionConfiguration *cfg = [NSURLSessionConfiguration defaultSessionConfiguration];
        cfg.timeoutIntervalForRequest = 20;
        cfg.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
        _session = [NSURLSession sessionWithConfiguration:cfg];
        [self migrateLegacyDirectoriesIfNeeded];
    }
    return self;
}

#pragma mark - Legacy cleanup

// The avatar cache used to live per-feature under ProfileAnalyzer/avatars and
// DeletedMessages/avatars, keyed the same way (<pk>.jpg, grp_<id>.jpg). Migrate
// those files into the shared store on first launch so already-cached avatars —
// especially group photos, whose CDN URLs can't be re-resolved — survive the
// move, then remove the now-empty legacy dirs.
- (void)migrateLegacyDirectoriesIfNeeded {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults boolForKey:kSPKAvatarMigrationKey])
        return;
    dispatch_async(self.ioQueue, ^{
        NSFileManager *fm = [NSFileManager defaultManager];
        NSString *dest = SPKAvatarDir();
        NSArray<NSString *> *legacyDirs = @[
            [[SPKStoragePaths profileAnalyzerDirectory] stringByAppendingPathComponent:@"avatars"],
            [[SPKStoragePaths deletedMessagesDirectory] stringByAppendingPathComponent:@"avatars"],
        ];
        for (NSString *legacy in legacyDirs) {
            for (NSString *name in [fm contentsOfDirectoryAtPath:legacy error:nil] ?: @[]) {
                NSString *src = [legacy stringByAppendingPathComponent:name];
                NSString *dst = [dest stringByAppendingPathComponent:name];
                if (![fm fileExistsAtPath:dst])
                    [fm moveItemAtPath:src toPath:dst error:nil];
            }
            [fm removeItemAtPath:legacy error:nil];
        }
        [defaults setBool:YES forKey:kSPKAvatarMigrationKey];
    });
}

#pragma mark - Paths

static NSString *SPKAvatarDir(void) {
    return [SPKStoragePaths avatarCacheDirectory];
}

static NSString *SPKAvatarPathForPK(NSString *pk) {
    NSString *safe = [pk stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
    if (!safe.length)
        safe = @"anon";
    return [SPKAvatarDir() stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.jpg", safe]];
}

#pragma mark - Public

- (UIImage *)cachedImageForPK:(NSString *)pk {
    if (!pk.length)
        return nil;
    return [self.memoryCache objectForKey:pk];
}

- (void)avatarForPK:(NSString *)pk
          urlString:(NSString *)urlString
         completion:(void (^)(UIImage *_Nullable))completion {
    [self avatarForPK:pk urlString:urlString forceRefresh:NO completion:completion];
}

- (void)avatarForPK:(NSString *)pk
          urlString:(NSString *)urlString
       forceRefresh:(BOOL)forceRefresh
         completion:(void (^)(UIImage *_Nullable))completion {
    if (!pk.length) {
        if (completion)
            completion(nil);
        return;
    }

    if (!forceRefresh) {
        UIImage *warm = [self.memoryCache objectForKey:pk];
        if (warm) {
            if (completion)
                completion(warm);
            return;
        }
    }

    dispatch_async(self.ioQueue, ^{
        NSString *path = SPKAvatarPathForPK(pk);
        NSFileManager *fm = [NSFileManager defaultManager];
        UIImage *diskImage = nil;
        BOOL stale = YES;

        if (!forceRefresh && [fm fileExistsAtPath:path]) {
            diskImage = [UIImage imageWithContentsOfFile:path];
            NSDictionary *attrs = [fm attributesOfItemAtPath:path error:nil];
            NSDate *modified = attrs[NSFileModificationDate];
            if (modified)
                stale = (-[modified timeIntervalSinceNow] > kSPKAvatarTTL);
        }

        if (diskImage) {
            [self.memoryCache setObject:diskImage forKey:pk];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion)
                    completion(diskImage);
            });
        }

        // We can obtain a fresh, unexpired URL for real user PKs via the IG API,
        // so a fetch is worthwhile even when the stored URL is empty/expired.
        BOOL canResolve = [self canResolvePK:pk];
        BOOL needsFetch = (forceRefresh || !diskImage || stale) && (urlString.length > 0 || canResolve);
        if (!needsFetch) {
            if (!diskImage) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (completion)
                        completion(nil);
                });
            }
            return;
        }

        @synchronized(self.inflight) {
            if ([self.inflight containsObject:pk])
                return; // a refresh is already running
            [self.inflight addObject:pk];
        }

        // Only call back with the network image if we didn't already serve a disk
        // copy (avoids a flicker when the stale image was good); a forced refresh
        // always delivers so the fresh image is applied.
        BOOL deliver = forceRefresh || (diskImage == nil);
        __weak typeof(self) weakSelf = self;
        [self networkFetchForPK:pk
                      urlString:urlString
                   allowResolve:canResolve
                     completion:^(UIImage *image) {
                         __strong typeof(weakSelf) strongSelf = weakSelf;
                         if (!strongSelf)
                             return;
                         @synchronized(strongSelf.inflight) {
                             [strongSelf.inflight removeObject:pk];
                         }
                         if (deliver && image) {
                             dispatch_async(dispatch_get_main_queue(), ^{
                                 if (completion)
                                     completion(image);
                             });
                         }
                     }];
    });
}

// Group thread keys ("grp_...") aren't resolvable via users/<pk>/info/; only
// numeric user PKs are.
- (BOOL)canResolvePK:(NSString *)pk {
    if (pk.length == 0)
        return NO;
    for (NSUInteger i = 0; i < pk.length; i++) {
        unichar c = [pk characterAtIndex:i];
        if (c < '0' || c > '9')
            return NO;
    }
    return YES;
}

// Downloads `urlString` and stores it. On failure (expired/blocked URL, or no
// URL at all), re-resolves a fresh CDN URL for the PK and retries once. Calls
// `done` exactly once with the final image (or nil).
- (void)networkFetchForPK:(NSString *)pk
                urlString:(NSString *)urlString
             allowResolve:(BOOL)allowResolve
               completion:(void (^)(UIImage *_Nullable))done {
    NSURL *url = urlString.length > 0 ? [NSURL URLWithString:urlString] : nil;
    if (!url) {
        if (allowResolve)
            [self resolveThenFetchForPK:pk completion:done];
        else if (done)
            done(nil);
        return;
    }

    __weak typeof(self) weakSelf = self;
    [[self.session dataTaskWithURL:url
                 completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
                     __strong typeof(weakSelf) strongSelf = weakSelf;
                     if (!strongSelf) {
                         if (done)
                             done(nil);
                         return;
                     }

                     UIImage *square = nil;
                     NSInteger status = [resp isKindOfClass:[NSHTTPURLResponse class]] ? ((NSHTTPURLResponse *)resp).statusCode : 200;
                     if (!err && data.length && status < 400) {
                         UIImage *raw = [UIImage imageWithData:data];
                         square = SPKAvatarSquareImage(raw);
                     }

                     if (square) {
                         [strongSelf.memoryCache setObject:square forKey:pk];
                         dispatch_async(strongSelf.ioQueue, ^{
                             NSData *jpeg = UIImageJPEGRepresentation(square, 0.9);
                             if (jpeg.length)
                                 [jpeg writeToFile:SPKAvatarPathForPK(pk) atomically:YES];
                         });
                         if (done)
                             done(square);
                     } else if (allowResolve) {
                         // Stored URL is dead — get a fresh one and try again (once).
                         [strongSelf resolveThenFetchForPK:pk completion:done];
                     } else if (done) {
                         done(nil);
                     }
                 }] resume];
}

- (void)resolveThenFetchForPK:(NSString *)pk completion:(void (^)(UIImage *_Nullable))done {
    @synchronized(self.resolveFailed) {
        if ([self.resolveFailed containsObject:pk]) {
            if (done)
                done(nil);
            return;
        }
    }
    // Funnel through the throttled scheduler so a screenful of expired avatars
    // doesn't burst-hit the rate-limited users/info endpoint.
    void (^storedDone)(UIImage *) = done ?: ^(UIImage *img) {
        (void)img;
    };
    dispatch_async(self.ioQueue, ^{
        [self.pendingResolves addObject:@[ pk, [storedDone copy] ]];
        [self drainResolveQueue];
    });
}

// Must run on ioQueue.
- (void)drainResolveQueue {
    while (self.activeResolveCount < kSPKMaxConcurrentResolves && self.pendingResolves.count > 0) {
        NSArray *pair = self.pendingResolves.firstObject;
        [self.pendingResolves removeObjectAtIndex:0];
        NSString *pk = pair[0];
        void (^done)(UIImage *) = pair[1];

        self.activeResolveCount += 1;
        NSTimeInterval now = [NSDate date].timeIntervalSinceReferenceDate;
        NSTimeInterval fireAt = MAX(now, self.lastResolveFire + kSPKResolveSpacing);
        self.lastResolveFire = fireAt;
        NSTimeInterval delay = fireAt - now;

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)),
                       dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                           [self performResolveForPK:pk completion:done];
                       });
    }
}

- (void)performResolveForPK:(NSString *)pk completion:(void (^)(UIImage *_Nullable))done {
    __weak typeof(self) weakSelf = self;
    [SPKInstagramAPI resolveProfilePicURLForPK:pk
                                    completion:^(NSString *fresh, NSError *error) {
                                        __strong typeof(weakSelf) strongSelf = weakSelf;
                                        if (!strongSelf) {
                                            if (done)
                                                done(nil);
                                            return;
                                        }
                                        void (^finish)(UIImage *) = ^(UIImage *image) {
                                            dispatch_async(strongSelf.ioQueue, ^{
                                                if (strongSelf.activeResolveCount > 0)
                                                    strongSelf.activeResolveCount -= 1;
                                                [strongSelf drainResolveQueue];
                                            });
                                            if (done)
                                                done(image);
                                        };
                                        if (fresh.length == 0) {
                                            @synchronized(strongSelf.resolveFailed) {
                                                [strongSelf.resolveFailed addObject:pk];
                                            }
                                            finish(nil);
                                            return;
                                        }
                                        [strongSelf networkFetchForPK:pk urlString:fresh allowResolve:NO completion:finish];
                                    }];
}

- (void)invalidatePK:(NSString *)pk {
    if (!pk.length)
        return;
    [self.memoryCache removeObjectForKey:pk];
    @synchronized(self.resolveFailed) {
        [self.resolveFailed removeObject:pk];
    }
    dispatch_async(self.ioQueue, ^{
        [[NSFileManager defaultManager] removeItemAtPath:SPKAvatarPathForPK(pk) error:nil];
    });
}

- (void)purge {
    [self.memoryCache removeAllObjects];
    @synchronized(self.resolveFailed) {
        [self.resolveFailed removeAllObjects];
    }
    dispatch_async(self.ioQueue, ^{
        [[NSFileManager defaultManager] removeItemAtPath:SPKAvatarDir() error:nil];
    });
}

- (unsigned long long)diskSizeBytes {
    return [SPKStoragePaths sizeOfDirectory:SPKAvatarDir()];
}

#pragma mark - Helpers

// Center-crop to a square and downscale so we don't store full-res CDN images.
static UIImage *SPKAvatarSquareImage(UIImage *image) {
    if (!image)
        return nil;
    CGFloat side = MIN(image.size.width, image.size.height);
    if (side <= 0)
        return nil;
    CGRect crop = CGRectMake((image.size.width - side) / 2.0,
                             (image.size.height - side) / 2.0,
                             side, side);

    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat];
    format.scale = 1.0;
    format.opaque = YES;
    CGSize target = CGSizeMake(kSPKAvatarPixelSize, kSPKAvatarPixelSize);
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:target format:format];
    return [renderer imageWithActions:^(__unused UIGraphicsImageRendererContext *ctx) {
        CGImageRef cg = CGImageCreateWithImageInRect(image.CGImage, crop);
        if (cg) {
            UIImage *cropped = [UIImage imageWithCGImage:cg scale:image.scale orientation:image.imageOrientation];
            CGImageRelease(cg);
            [cropped drawInRect:CGRectMake(0, 0, target.width, target.height)];
        } else {
            [image drawInRect:CGRectMake(0, 0, target.width, target.height)];
        }
    }];
}

@end
