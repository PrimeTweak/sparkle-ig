#import "SPKStrings.h"
#import "DMGifTitle.h"

#import <UIKit/UIKit.h>
#import <objc/message.h>

#import "../../AssetUtils.h"
#import "../../Shared/Giphy/SPKGiphyMetadata.h"
#import "../../Shared/Messages/SPKDirectMenuElement.h"
#import "../../Shared/Messages/SPKDirectReflection.h"
#import "../../Shared/UI/SPKNotificationCenter.h"
#import "../../Utils.h"

/// Direct's menu view model carries the Giphy id but no title, so this pref is
/// itself the consent for the giphy.com lookup — it does not defer to the
/// comments toggle.
static NSString *const kSPKDMGifTitlePref = @"msgs_gif_title";

static NSString *SPKDMGifTitlePlaceholder(void) {
    return SPKL(@"MESSAGES_GIF_TITLE_LOOKUP_PLACEHOLDER");
}
/// The placeholder row carries a subtitle purely so the label exists to be
/// filled with the channel later — a row built without one has no second line
/// to patch, which would force the author inline where it just truncates.
static NSString *SPKDMGifTitleSubtitlePlaceholder(void) {
    return SPKL(@"MESSAGES_GIF_TITLE_TAP_TO_COPY_SUBTITLE");
}

static id sSPKDMGifTitleMenuViewModel = nil;
/// Menus opened for the current long-press, held weakly so a dismissed menu
/// drops out on its own.
static NSHashTable *sSPKDMGifTitleMenuViews = nil;
static BOOL sSPKDMGifTitlePatchPending = NO;

BOOL SPKDMGifTitleEnabled(void) {
    return [SPKUtils getBoolPref:kSPKDMGifTitlePref];
}

void SPKDMGifTitleNoteMenuViewModel(id viewModel) {
    BOOL enabled = SPKDMGifTitleEnabled();
    sSPKDMGifTitleMenuViewModel = enabled ? viewModel : nil;

    // A new long-press: forget the previous menu's views and placeholder state.
    sSPKDMGifTitlePatchPending = NO;
    if (!sSPKDMGifTitleMenuViews)
        sSPKDMGifTitleMenuViews = [NSHashTable weakObjectsHashTable];
    [sSPKDMGifTitleMenuViews removeAllObjects];

    // IG builds the menu more than once per long-press, so the record cannot be
    // consumed by the first build. It stays valid for the rest of this runloop
    // turn — the synchronous menu construction — and no longer, so an unrelated
    // menu opened later never picks up a stale message.
    dispatch_async(dispatch_get_main_queue(), ^{
        sSPKDMGifTitleMenuViewModel = nil;
    });
}

#pragma mark - Model access

static NSString *SPKDMGifTitleTrimmedString(id object, NSString *selectorName) {
    NSString *value = SPKDirectStringValue(SPKDirectValueForSelectorNamed(object, selectorName));
    return [value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
}

/// Two different shapes reach this code.
///
/// The long-press menu is handed an `IGDirectAnimatedMediaMessageViewModel`,
/// whose `mediaModel` (`IGDirectAnimatedMediaViewModel`) carries the Giphy id as
/// `pk` and the channel as `creatorUsername`, but **no title** — that path has
/// to resolve the name over the network like comments do.
///
/// `IGGiphyGIFModel` (reachable as `giphyModel` on the message content model)
/// does carry `title`, so it is preferred wherever it is actually available.
static void SPKDMGifTitleReadModel(id viewModel,
                                   NSString **outTitle,
                                   NSString **outAuthor,
                                   NSString **outIdentifier) {
    id giphyModel = SPKDirectValueForSelectorNamed(viewModel, @"giphyModel");
    if (!giphyModel) {
        for (NSString *name in @[ @"content", @"animatedMedia", @"media", @"message", @"messageContent" ]) {
            id container = SPKDirectValueForSelectorNamed(viewModel, name);
            giphyModel = SPKDirectValueForSelectorNamed(container, @"giphyModel");
            if (giphyModel)
                break;
        }
    }

    NSString *title = SPKDMGifTitleTrimmedString(giphyModel, @"title");
    NSString *author = SPKDMGifTitleTrimmedString(giphyModel, @"verifiedUsername");
    NSString *identifier = SPKDMGifTitleTrimmedString(giphyModel, @"identifier");

    id mediaModel = SPKDirectValueForSelectorNamed(viewModel, @"mediaModel");
    if (mediaModel) {
        if (identifier.length == 0)
            identifier = SPKDMGifTitleTrimmedString(mediaModel, @"pk");
        if (author.length == 0)
            author = SPKDMGifTitleTrimmedString(mediaModel, @"creatorUsername");
    }

    *outTitle = title;
    *outAuthor = author;
    *outIdentifier = identifier;
}

#pragma mark - Rows

static UIImage *SPKDMGifTitleIcon(void) {
    return [SPKAssetUtils instagramIconNamed:@"info" pointSize:24.0];
}

static void SPKDMGifTitleCopy(NSString *title) {
    UIPasteboard.generalPasteboard.string = title;
    SPKNotify(kSPKNotificationCopyGIFTitle, SPKL(@"FEED_COMMENT_ACTIONS_GIF_TITLE_COPIED_TITLE"), nil, @"copy_filled", SPKNotificationToneSuccess);
}

/// Row that displays a known title; tapping copies it.
static id SPKDMGifTitleRow(id templateElement, SPKGiphyMetadata *metadata) {
    NSString *subtitle = metadata.author.length > 0
                             ? [NSString stringWithFormat:@"by %@", metadata.author]
                             : nil;
    NSString *title = metadata.title;
    return SPKDirectPrismMenuElementWithSubtitle(templateElement, title, subtitle, SPKDMGifTitleIcon(), ^{
        SPKDMGifTitleCopy(title);
    });
}

#pragma mark - Filling in the placeholder row

/// Rewrites every label still showing `from` in the menus opened for the current
/// long-press. IG bakes a row's text in at build time, but nothing stops the
/// label from being updated while the menu is on screen.
static void SPKDMGifTitlePatchLabels(UIView *view, NSString *from, NSString *to) {
    if (![view isKindOfClass:UIView.class])
        return;
    if ([view isKindOfClass:UILabel.class]) {
        UILabel *label = (UILabel *)view;
        if ([label.text isEqualToString:from]) {
            // Keep IG's styling: replacing `text` on an attributed label would
            // drop its font and colour.
            NSAttributedString *attributed = label.attributedText;
            if (attributed.length > 0) {
                NSDictionary *attributes = [attributed attributesAtIndex:0 effectiveRange:NULL];
                label.attributedText = [[NSAttributedString alloc] initWithString:to attributes:attributes];
            } else {
                label.text = to;
            }
            [label invalidateIntrinsicContentSize];
            [label.superview setNeedsLayout];
        }
        return;
    }
    for (UIView *subview in view.subviews) {
        SPKDMGifTitlePatchLabels(subview, from, to);
    }
}

static void SPKDMGifTitleFillPlaceholder(NSString *title, NSString *subtitle) {
    for (UIView *view in sSPKDMGifTitleMenuViews) {
        SPKDMGifTitlePatchLabels(view, SPKDMGifTitlePlaceholder(), title);
        if (subtitle.length > 0)
            SPKDMGifTitlePatchLabels(view, SPKDMGifTitleSubtitlePlaceholder(), subtitle);
    }
}

void SPKDMGifTitleRegisterMenuView(id menuView) {
    if (!sSPKDMGifTitlePatchPending || ![menuView isKindOfClass:UIView.class])
        return;
    [sSPKDMGifTitleMenuViews addObject:menuView];
}

/// Row shown while the lookup is in flight. Its text is replaced with the real
/// title as soon as the answer arrives, so the first long-press ends up showing
/// the name too; tapping copies whatever has resolved by then.
static id SPKDMGifTitleLookupRow(id templateElement, NSString *identifier) {
    return SPKDirectPrismMenuElementWithSubtitle(templateElement, SPKDMGifTitlePlaceholder(), SPKDMGifTitleSubtitlePlaceholder(), SPKDMGifTitleIcon(), ^{
        [SPKGiphyMetadataResolver resolveMetadataForGifMediaId:identifier
                                                    completion:^(SPKGiphyMetadata *metadata) {
                                                        if (!metadata) {
                                                            SPKNotify(kSPKNotificationCopyGIFTitle, SPKL(@"MESSAGES_DMGIF_TITLE_GIF_TITLE_UNAVAILABLE_TITLE"), nil, @"info", SPKNotificationToneError);
                                                            return;
                                                        }
                                                        SPKDMGifTitleCopy(metadata.title);
                                                    }];
    });
}

NSArray *SPKDMGifTitleElementsForMenu(NSArray *elements) {
    id viewModel = sSPKDMGifTitleMenuViewModel;
    id templateElement = elements.firstObject;

    if (!viewModel || !templateElement || !SPKDMGifTitleEnabled())
        return @[];

    // IG re-inits the menu with the array we already added to; without this the
    // row lands twice.
    if (SPKDirectMenuContainsSparkleRow(elements))
        return @[];

    NSString *title = nil;
    NSString *author = nil;
    NSString *identifier = nil;
    SPKDMGifTitleReadModel(viewModel, &title, &author, &identifier);

    SPKGiphyMetadata *local = [SPKGiphyMetadata metadataWithTitle:title author:author];
    if (local) {
        id row = SPKDMGifTitleRow(templateElement, local);
        return row ? @[ row ] : @[];
    }

    if (identifier.length == 0)
        return @[];

    // A warm cache means an earlier long-press already resolved this GIF, so show
    // the real title instead of asking for it again.
    SPKGiphyMetadata *cached = [SPKGiphyMetadataResolver cachedMetadataForGifMediaId:identifier];
    if (cached) {
        id row = SPKDMGifTitleRow(templateElement, cached);
        return row ? @[ row ] : @[];
    }

    id row = SPKDMGifTitleLookupRow(templateElement, identifier);
    if (!row)
        return @[];

    // The menu is on screen long before the answer arrives, so resolve now and
    // rewrite the placeholder in place when it lands.
    sSPKDMGifTitlePatchPending = YES;
    [SPKGiphyMetadataResolver resolveMetadataForGifMediaId:identifier completion:^(SPKGiphyMetadata *metadata) {
        NSString *filledTitle = metadata.title ?: SPKL(@"FEED_COMMENT_ACTIONS_TITLE_UNAVAILABLE_TITLE");
        NSString *filledSubtitle = metadata.author.length > 0
                                       ? [NSString stringWithFormat:@"by %@", metadata.author]
                                       : nil;
        SPKDMGifTitleFillPlaceholder(filledTitle, filledSubtitle);
    }];

    return @[ row ];
}
