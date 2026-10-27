#import "SPKStoryMentions.h"

#import "../../Utils.h"
#import "SPKStoryContext.h"

#import <objc/message.h>
#import <objc/runtime.h>

static const void *kSPKStoryMentionsCacheKey = &kSPKStoryMentionsCacheKey;

@implementation SPKStoryMention

- (instancetype)initWithPK:(NSString *)pk
                userObject:(id)userObject
                  username:(NSString *)username
                  fullName:(NSString *)fullName
         profilePictureURL:(NSURL *)profilePictureURL {
    self = [super init];
    if (self) {
        _pk = [pk copy];
        _userObject = userObject;
        _username = [username copy];
        _fullName = [fullName copy];
        _profilePictureURL = profilePictureURL;
    }
    return self;
}

@end

// MARK: - Runtime readers

static id SPKStoryMentionsPerformSelector(id target, NSString *selectorName) {
    if (!target || selectorName.length == 0)
        return nil;
    SEL selector = NSSelectorFromString(selectorName);
    if (![target respondsToSelector:selector])
        return nil;
    @try {
        id value = ((id (*)(id, SEL))objc_msgSend)(target, selector);
        return (value == (id)kCFNull) ? nil : value;
    } @catch (__unused NSException *exception) {
        return nil;
    }
}

// Pando-backed models keep their GraphQL fields in a dictionary ivar; plain KVC
// on those keys can hand back NSNull, so read the dictionary directly.
static id SPKStoryMentionsFieldCacheValue(id object, NSString *key) {
    if (!object || key.length == 0)
        return nil;

    static Ivar fieldCacheIvar = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class storableClass = NSClassFromString(@"IGAPIStorableObject");
        if (storableClass)
            fieldCacheIvar = class_getInstanceVariable(storableClass, "_fieldCache");
    });
    if (!fieldCacheIvar)
        return nil;

    Class storableClass = NSClassFromString(@"IGAPIStorableObject");
    if (storableClass && ![object isKindOfClass:storableClass])
        return nil;

    NSDictionary *fieldCache = object_getIvar(object, fieldCacheIvar);
    if (![fieldCache isKindOfClass:[NSDictionary class]])
        return nil;

    id value = fieldCache[key];
    return (!value || [value isKindOfClass:[NSNull class]]) ? nil : value;
}

static NSString *SPKStoryMentionsStringValue(id value) {
    if (!value || value == (id)kCFNull)
        return nil;
    if ([value isKindOfClass:[NSString class]])
        return [(NSString *)value length] > 0 ? value : nil;
    if ([value respondsToSelector:@selector(stringValue)]) {
        NSString *string = [value stringValue];
        return string.length > 0 ? string : nil;
    }
    return nil;
}

/// Reads a user field from the field cache first, then the matching accessors.
static NSString *SPKStoryMentionsUserString(id user, NSString *fieldKey, NSArray<NSString *> *selectorNames) {
    NSString *value = SPKStoryMentionsStringValue(SPKStoryMentionsFieldCacheValue(user, fieldKey));
    if (value.length > 0)
        return value;
    for (NSString *selectorName in selectorNames) {
        value = SPKStoryMentionsStringValue(SPKStoryMentionsPerformSelector(user, selectorName));
        if (value.length > 0)
            return value;
    }
    return nil;
}

static NSString *SPKStoryMentionsUserPK(id user) {
    if (!user)
        return nil;
    NSString *pk = [SPKUtils pkFromIGUser:user];
    if (pk.length > 0)
        return pk;
    pk = SPKStoryMentionsStringValue(SPKStoryMentionsFieldCacheValue(user, @"strong_id__"));
    if (pk.length > 0)
        return pk;
    return SPKStoryMentionsStringValue(SPKStoryMentionsFieldCacheValue(user, @"pk"));
}

static NSArray *SPKStoryMentionsArrayFromCollection(id collection) {
    if (!collection ||
        [collection isKindOfClass:[NSDictionary class]] ||
        [collection isKindOfClass:[NSString class]] ||
        [collection isKindOfClass:[NSURL class]]) {
        return nil;
    }
    if ([collection isKindOfClass:[NSArray class]])
        return collection;
    if ([collection isKindOfClass:[NSOrderedSet class]])
        return [(NSOrderedSet *)collection array];
    if ([collection isKindOfClass:[NSSet class]])
        return [(NSSet *)collection allObjects];
    if ([collection conformsToProtocol:@protocol(NSFastEnumeration)]) {
        NSMutableArray *array = [NSMutableArray array];
        @try {
            for (id item in collection) {
                [array addObject:item];
            }
        } @catch (__unused NSException *exception) {
            return nil;
        }
        return array;
    }
    return nil;
}

/// Every tappable-mention collection IG may expose on a story item. Different
/// versions and story types populate different ones, so union them all.
static NSArray *SPKStoryMentionTappables(id media) {
    if (!media)
        return @[];

    NSMutableArray *tappables = [NSMutableArray array];
    for (NSString *selectorName in @[ @"reelMentions", @"storyMentions" ]) {
        NSArray *items = SPKStoryMentionsArrayFromCollection(SPKStoryMentionsPerformSelector(media, selectorName));
        if (items.count > 0)
            [tappables addObjectsFromArray:items];
    }
    for (NSString *fieldKey in @[ @"reel_mentions", @"story_mentions" ]) {
        NSArray *items = SPKStoryMentionsArrayFromCollection(SPKStoryMentionsFieldCacheValue(media, fieldKey));
        if (items.count > 0)
            [tappables addObjectsFromArray:items];
    }
    return tappables;
}

static id SPKStoryMentionUserFromTappable(id tappable) {
    if (!tappable)
        return nil;
    id user = SPKStoryMentionsPerformSelector(tappable, @"user");
    if (user)
        return user;
    user = SPKStoryMentionsFieldCacheValue(tappable, @"user");
    if (user)
        return user;
    @try {
        user = [tappable valueForKey:@"user"];
    } @catch (__unused NSException *exception) {
        user = nil;
    }
    return (user == (id)kCFNull) ? nil : user;
}

// MARK: - Extraction

static NSArray<SPKStoryMention *> *SPKStoryMentionsForMedia(id media) {
    NSArray *tappables = SPKStoryMentionTappables(media);
    if (tappables.count == 0)
        return @[];

    NSString *ownerPK = SPKStoryUserPKFromMediaObject(media);

    NSMutableArray<SPKStoryMention *> *mentions = [NSMutableArray array];
    NSMutableSet<NSString *> *seenIdentities = [NSMutableSet set];

    for (id tappable in tappables) {
        id user = SPKStoryMentionUserFromTappable(tappable);
        if (!user)
            continue;

        NSString *pk = SPKStoryMentionsUserPK(user);
        NSString *username = SPKStoryMentionsUserString(user, @"username", @[ @"username" ]);

        // A tappable with neither identifier can't be deduped or acted on.
        if (pk.length == 0 && username.length == 0)
            continue;

        // The story's own author is repeated as an attribution tappable on
        // reshares; they are not a mention of someone else.
        if (ownerPK.length > 0 && [pk isEqualToString:ownerPK])
            continue;

        NSString *identity = pk.length > 0 ? [@"pk:" stringByAppendingString:pk]
                                           : [@"username:" stringByAppendingString:username.lowercaseString];
        if ([seenIdentities containsObject:identity])
            continue;
        [seenIdentities addObject:identity];

        NSString *fullName = SPKStoryMentionsUserString(user, @"full_name", @[ @"fullName" ]);
        NSString *pictureString = SPKStoryMentionsUserString(user, @"profile_pic_url", @[ @"profilePicURL", @"profilePicUrl" ]);
        NSURL *pictureURL = pictureString.length > 0 ? [NSURL URLWithString:pictureString] : nil;

        [mentions addObject:[[SPKStoryMention alloc] initWithPK:pk
                                                     userObject:user
                                                       username:username
                                                       fullName:fullName
                                              profilePictureURL:pictureURL]];
    }

    return [mentions copy];
}

// MARK: - Public API

NSArray<SPKStoryMention *> *SPKStoryMentionsForOverlay(UIView *overlayView) {
    if (!overlayView)
        return @[];

    SPKStoryContext *context = SPKStoryContextFromOverlay(overlayView);
    id media = context.media;
    if (!media)
        return @[];

    // Called from the overlay's layout pass, so cache against the media identity
    // rather than re-walking the model on every tick. Without a stable
    // identifier we recompute instead of risking a stale list on a recycled
    // overlay.
    NSString *mediaIdentifier = SPKStoryMediaIdentifierForContext(context);
    NSArray *cacheEntry = objc_getAssociatedObject(overlayView, kSPKStoryMentionsCacheKey);
    if (mediaIdentifier.length > 0 && cacheEntry.count == 2 && [cacheEntry.firstObject isEqual:mediaIdentifier])
        return cacheEntry.lastObject;

    NSArray<SPKStoryMention *> *mentions = SPKStoryMentionsForMedia(media);

    if (mediaIdentifier.length > 0) {
        objc_setAssociatedObject(overlayView, kSPKStoryMentionsCacheKey, @[ mediaIdentifier, mentions ], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    } else if (cacheEntry) {
        objc_setAssociatedObject(overlayView, kSPKStoryMentionsCacheKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    return mentions;
}

NSUInteger SPKStoryMentionCountForOverlay(UIView *overlayView) {
    return SPKStoryMentionsForOverlay(overlayView).count;
}
