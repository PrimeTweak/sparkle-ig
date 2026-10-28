#import "SPKGiphyMetadata.h"

#import "../../Utils.h"

static NSString *const kSPKGiphyLogCategory = @"Giphy";
/// Giphy formats oEmbed titles differently for GIFs and stickers:
///   "Happy Dance GIF by Some Channel - Find & Share on GIPHY"
///   "Kermit Dancing Sticker by Fuzzy Wobble for iOS & Android | GIPHY"
/// Stripped longest-first, repeatedly, since the sticker form stacks two tails.
static NSArray<NSString *> *SPKGiphyBoilerplateSuffixes(void) {
    static NSArray<NSString *> *suffixes;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        suffixes = @[ @" - Find & Share on GIPHY", @" for iOS & Android", @" | GIPHY", @" on GIPHY" ];
    });
    return suffixes;
}

/// How long a failed lookup is remembered before we let it hit the network again.
static const NSTimeInterval kSPKGiphyFailureCooldown = 60.0;
static const NSTimeInterval kSPKGiphyRequestTimeout = 8.0;

@interface SPKGiphyMetadata ()
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy, nullable) NSString *author;
@end

@implementation SPKGiphyMetadata

+ (instancetype)metadataWithTitle:(NSString *)title author:(NSString *)author {
    NSCharacterSet *whitespace = NSCharacterSet.whitespaceAndNewlineCharacterSet;
    NSString *trimmedTitle = [title stringByTrimmingCharactersInSet:whitespace];
    if (trimmedTitle.length == 0)
        return nil;

    NSString *trimmedAuthor = [author stringByTrimmingCharactersInSet:whitespace];
    SPKGiphyMetadata *metadata = [self new];
    metadata.title = trimmedTitle;
    metadata.author = trimmedAuthor.length > 0 ? trimmedAuthor : nil;
    return metadata;
}

@end

@implementation SPKGiphyMetadataResolver

#pragma mark - Shared state

/// Serialises the cache, the failure log and the in-flight completion table.
+ (dispatch_queue_t)stateQueue {
    static dispatch_queue_t queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        queue = dispatch_queue_create("com.sparkle.giphy.metadata", DISPATCH_QUEUE_SERIAL);
    });
    return queue;
}

+ (NSCache<NSString *, SPKGiphyMetadata *> *)cache {
    static NSCache *cache;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cache = [NSCache new];
        cache.countLimit = 200;
    });
    return cache;
}

+ (NSMutableDictionary<NSString *, NSDate *> *)failureDates {
    static NSMutableDictionary *dates;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dates = [NSMutableDictionary dictionary];
    });
    return dates;
}

+ (NSMutableDictionary<NSString *, NSMutableArray *> *)pendingCompletions {
    static NSMutableDictionary *pending;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        pending = [NSMutableDictionary dictionary];
    });
    return pending;
}

+ (NSURLSession *)session {
    static NSURLSession *session;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
        configuration.timeoutIntervalForRequest = kSPKGiphyRequestTimeout;
        configuration.HTTPShouldSetCookies = NO;
        configuration.HTTPCookieStorage = nil;
        session = [NSURLSession sessionWithConfiguration:configuration];
    });
    return session;
}

#pragma mark - Public

+ (SPKGiphyMetadata *)cachedMetadataForGifMediaId:(NSString *)gifMediaId {
    if (gifMediaId.length == 0)
        return nil;

    __block SPKGiphyMetadata *metadata = nil;
    dispatch_sync([self stateQueue], ^{
        metadata = [[self cache] objectForKey:gifMediaId];
    });
    return metadata;
}

+ (void)resolveMetadataForGifMediaId:(NSString *)gifMediaId
                          completion:(void (^)(SPKGiphyMetadata *_Nullable))completion {
    if (!completion)
        return;

    void (^finish)(SPKGiphyMetadata *) = ^(SPKGiphyMetadata *metadata) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(metadata);
        });
    };

    if (gifMediaId.length == 0) {
        finish(nil);
        return;
    }

    NSURL *url = [self oEmbedURLForGifMediaId:gifMediaId];
    if (!url) {
        finish(nil);
        return;
    }

    dispatch_async([self stateQueue], ^{
        SPKGiphyMetadata *cached = [[self cache] objectForKey:gifMediaId];
        if (cached) {
            finish(cached);
            return;
        }

        NSDate *failedAt = [self failureDates][gifMediaId];
        if (failedAt && [[NSDate date] timeIntervalSinceDate:failedAt] < kSPKGiphyFailureCooldown) {
            finish(nil);
            return;
        }

        // Coalesce: a lookup already in flight for this id adopts the new caller
        // rather than firing a second request.
        NSMutableArray *waiting = [self pendingCompletions][gifMediaId];
        if (waiting) {
            [waiting addObject:[finish copy]];
            return;
        }
        [self pendingCompletions][gifMediaId] = [NSMutableArray arrayWithObject:[finish copy]];

        [self startRequestForGifMediaId:gifMediaId url:url];
    });
}

#pragma mark - Networking

+ (NSURL *)oEmbedURLForGifMediaId:(NSString *)gifMediaId {
    NSCharacterSet *allowed = [NSCharacterSet URLPathAllowedCharacterSet];
    NSString *escapedId = [gifMediaId stringByAddingPercentEncodingWithAllowedCharacters:allowed];
    if (escapedId.length == 0)
        return nil;

    NSURLComponents *components = [NSURLComponents componentsWithString:@"https://giphy.com/services/oembed"];
    components.queryItems = @[
        [NSURLQueryItem queryItemWithName:@"url"
                                    value:[NSString stringWithFormat:@"https://giphy.com/gifs/%@", escapedId]]
    ];
    return components.URL;
}

+ (void)startRequestForGifMediaId:(NSString *)gifMediaId url:(NSURL *)url {
    NSURLSessionDataTask *task = [[self session]
          dataTaskWithURL:url
        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            SPKGiphyMetadata *metadata = nil;
            NSInteger statusCode = [response isKindOfClass:NSHTTPURLResponse.class]
                                       ? [(NSHTTPURLResponse *)response statusCode]
                                       : 0;
            if (!error && statusCode == 200 && data.length > 0) {
                metadata = [self metadataFromResponseData:data];
            }
            if (!metadata) {
                SPKLog(kSPKGiphyLogCategory, @"Lookup failed for %@ (status %ld, error %@)",
                       gifMediaId, (long)statusCode, error.localizedDescription);
            }
            [self completeGifMediaId:gifMediaId withMetadata:metadata];
        }];
    [task resume];
}

+ (void)completeGifMediaId:(NSString *)gifMediaId withMetadata:(SPKGiphyMetadata *)metadata {
    dispatch_async([self stateQueue], ^{
        if (metadata) {
            [[self cache] setObject:metadata forKey:gifMediaId];
            [[self failureDates] removeObjectForKey:gifMediaId];
        } else {
            [self failureDates][gifMediaId] = [NSDate date];
        }

        NSArray *waiting = [self pendingCompletions][gifMediaId];
        [[self pendingCompletions] removeObjectForKey:gifMediaId];
        for (void (^block)(SPKGiphyMetadata *) in waiting) {
            block(metadata);
        }
    });
}

#pragma mark - Parsing

+ (SPKGiphyMetadata *)metadataFromResponseData:(NSData *)data {
    id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if (![json isKindOfClass:NSDictionary.class])
        return nil;

    NSString *rawTitle = [json objectForKey:@"title"];
    if (![rawTitle isKindOfClass:NSString.class])
        return nil;

    NSString *author = [json objectForKey:@"author_name"];
    if (![author isKindOfClass:NSString.class])
        author = nil;
    author = [author stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];

    NSString *title = [self cleanedTitle:rawTitle author:author];
    if (title.length == 0)
        return nil;

    SPKGiphyMetadata *metadata = [SPKGiphyMetadata new];
    metadata.title = title;
    // "GIPHY" is Giphy's own house account rather than a real uploader, but it
    // is still who posted the GIF, so it is reported like any other channel.
    metadata.author = author.length > 0 ? author : nil;
    return metadata;
}

/// Everything after the name is boilerplate, or the author we show separately.
+ (NSString *)cleanedTitle:(NSString *)rawTitle author:(NSString *)author {
    NSString *title = [rawTitle stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (title.length == 0)
        return nil;

    for (BOOL stripped = YES; stripped;) {
        stripped = NO;
        for (NSString *suffix in SPKGiphyBoilerplateSuffixes()) {
            if ([title hasSuffix:suffix] && title.length > suffix.length) {
                title = [title substringToIndex:title.length - suffix.length];
                stripped = YES;
                break;
            }
        }
    }

    if (author.length > 0) {
        NSString *authorSuffix = [NSString stringWithFormat:@" by %@", author];
        if ([title hasSuffix:authorSuffix]) {
            title = [title substringToIndex:title.length - authorSuffix.length];
        }
    }

    for (NSString *suffix in @[ @" GIF", @" Sticker" ]) {
        if ([title hasSuffix:suffix] && title.length > suffix.length) {
            title = [title substringToIndex:title.length - suffix.length];
            break;
        }
    }

    title = [title stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    // Stripping can leave nothing when the whole title was boilerplate (an
    // untitled upload); the raw string is still better than no row at all.
    return title.length > 0 ? title : [rawTitle stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
}

@end
