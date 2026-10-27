#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, SPKDeletedMessageKind) {
    SPKDeletedMessageKindUnknown = 0,
    SPKDeletedMessageKindText,
    SPKDeletedMessageKindPhoto,
    SPKDeletedMessageKindVideo,
    SPKDeletedMessageKindVoice,
    SPKDeletedMessageKindGif,
    SPKDeletedMessageKindSticker,
    SPKDeletedMessageKindShare,
    SPKDeletedMessageKindLink,
    SPKDeletedMessageKindAudioShare,
    SPKDeletedMessageKindReaction,
    SPKDeletedMessageKindOther,
};

FOUNDATION_EXPORT NSString *SPKDeletedMessageKindToString(SPKDeletedMessageKind kind);
FOUNDATION_EXPORT SPKDeletedMessageKind SPKDeletedMessageKindFromString(NSString *_Nullable s);
FOUNDATION_EXPORT NSString *SPKDeletedMessageKindLocalizedName(SPKDeletedMessageKind kind);
FOUNDATION_EXPORT NSString *SPKDeletedMessageKindSymbol(SPKDeletedMessageKind kind);
// Variant that returns the filled glyph for photo/video/voice/gif when
// `filled` is YES; other kinds are unaffected (they have no filled variant).
FOUNDATION_EXPORT NSString *SPKDeletedMessageKindSymbolFilled(SPKDeletedMessageKind kind, BOOL filled);

// Human label for a Share subtype string ("reel"→"Reel", "post"→"Post",
// "story"→"Story", "profile"→"Profile", "note"→"Note", "location"→"Location",
// "audio"→"Audio"). Returns "Shared post" for nil/unknown/generic. Used to label
// Share-kind messages by the actual content type instead of a generic "Share".
FOUNDATION_EXPORT NSString *SPKDeletedMessageShareSubtypeName(NSString *_Nullable subtype);
// Icon glyph for a Share subtype, falling back to the generic share glyph.
FOUNDATION_EXPORT NSString *SPKDeletedMessageShareSubtypeSymbol(NSString *_Nullable subtype);

@interface SPKDeletedMessage : NSObject

@property (nonatomic, copy) NSString *messageId;
@property (nonatomic, copy) NSString *threadId;
@property (nonatomic, copy, nullable) NSString *threadTitle;
// YES when this message belongs to a group thread (captured from the open
// thread's metadata). Grouping also falls back to a multi-sender heuristic.
@property (nonatomic, assign) BOOL isGroup;
// Group's custom photo URL when one is set (else nil — group has no photo).
@property (nonatomic, copy, nullable) NSString *threadPhotoURL;

@property (nonatomic, copy) NSString *senderPk;
@property (nonatomic, copy, nullable) NSString *senderUsername;
@property (nonatomic, copy, nullable) NSString *senderFullName;
@property (nonatomic, copy, nullable) NSString *senderProfilePicURL;

@property (nonatomic, strong) NSDate *sentAt;
@property (nonatomic, strong) NSDate *capturedAt;
@property (nonatomic, strong) NSDate *deletedAt;

@property (nonatomic, assign) SPKDeletedMessageKind kind;
@property (nonatomic, copy, nullable) NSString *text;
@property (nonatomic, copy, nullable) NSString *previewText;

@property (nonatomic, copy, nullable) NSString *mediaURL;
@property (nonatomic, copy, nullable) NSString *mediaPath; // relative under media root
@property (nonatomic, copy, nullable) NSString *thumbnailURL;
@property (nonatomic, copy, nullable) NSString *thumbnailPath;
@property (nonatomic, copy, nullable) NSString *mediaMimeType;
@property (nonatomic, assign) NSInteger viewMode; // -1 when not ephemeral / unknown
@property (nonatomic, copy, nullable) NSString *stagedMediaPath;
@property (nonatomic, copy, nullable) NSString *stagedThumbnailPath;
@property (nonatomic, strong, nullable) NSDate *mediaURLStaleAt;

@property (nonatomic, assign) double durationSeconds; // voice/video
@property (nonatomic, strong, nullable) NSArray<NSNumber *> *waveform;
@property (nonatomic, assign) CGFloat width;
@property (nonatomic, assign) CGFloat height;

// Server id of the message this one was a reply to (when applicable).
// Captured best-effort from metadata / KVC probes.
@property (nonatomic, copy, nullable) NSString *replyToMessageId;

// Reaction unsends only: the emoji that was removed, and a short preview of the
// message it was reacting to (when resolvable).
@property (nonatomic, copy, nullable) NSString *reactionEmoji;
@property (nonatomic, copy, nullable) NSString *reactionTargetPreview;

// Share-kind messages only: the shared content's subtype ("reel"/"post"/"story"/
// "profile"/"note"/"location"/"audio") and the author handle of the shared post,
// so the log can label it by what it actually is and show the author.
@property (nonatomic, copy, nullable) NSString *shareSubtype;
@property (nonatomic, copy, nullable) NSString *shareAuthor;

+ (instancetype)messageFromJSONDict:(NSDictionary *)dict;
- (NSDictionary *)toJSONDict;

@end

// Convenience aggregate built on read for the top VC. Represents either a single
// sender (1:1 chats, keyed by senderPk) or a whole group thread (keyed by
// threadId, isGroup == YES) where messages span several senders.
@interface SPKDeletedMessageGroup : NSObject
@property (nonatomic, copy) NSString *senderPk;
@property (nonatomic, copy, nullable) NSString *senderUsername;
@property (nonatomic, copy, nullable) NSString *senderFullName;
@property (nonatomic, copy, nullable) NSString *senderProfilePicURL;
@property (nonatomic, assign) BOOL isPinned;
@property (nonatomic, assign) BOOL isBlocked;
// Group-thread fields. isGroup distinguishes a thread-keyed entry from a
// sender-keyed one; threadTitle is the resolved (or generated) group name.
@property (nonatomic, assign) BOOL isGroup;
@property (nonatomic, copy, nullable) NSString *threadId;
@property (nonatomic, copy, nullable) NSString *threadTitle;
@property (nonatomic, copy, nullable) NSString *threadPhotoURL;
@property (nonatomic, strong) NSArray<SPKDeletedMessage *> *messages; // newest-first
@property (nonatomic, readonly) NSUInteger count;
@property (nonatomic, readonly, nullable) NSDate *lastDeletedAt;
@property (nonatomic, readonly, nullable) SPKDeletedMessage *latest;
// User-facing title: group name for group threads, else @username / full name.
@property (nonatomic, readonly, copy) NSString *displayName;
// Stable identity used for pin/block flags and deletion. Namespaced for groups
// so a threadId can never collide with a sender PK.
@property (nonatomic, readonly, copy) NSString *flagKey;
@end

NS_ASSUME_NONNULL_END
