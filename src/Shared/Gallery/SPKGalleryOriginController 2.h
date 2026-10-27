#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class SPKGalleryFile;
@class SPKGallerySaveMetadata;

NS_ASSUME_NONNULL_BEGIN

@interface SPKGalleryOriginController : NSObject

+ (void)populateMetadata:(SPKGallerySaveMetadata *)metadata fromMedia:(id _Nullable)media;
+ (void)populateProfileMetadata:(SPKGallerySaveMetadata *)metadata username:(nullable NSString *)username user:(id _Nullable)user;
+ (BOOL)openOriginalPostForGalleryFile:(SPKGalleryFile *)file;
// Opens the post over `presentingVC` so closing it returns here. `legacyFallback`
// runs only when that is not possible (or Instagram never produced a page to
// redirect) and should do whatever the old behaviour did to reveal the post,
// typically dismissing the presenting screen. It may run asynchronously.
/// `onDismiss` runs when the post is closed and `presentingVC` is live again; it
/// gets no appearance callbacks of its own, since the post sits over it.
+ (BOOL)openOriginalPostForGalleryFile:(SPKGalleryFile *)file
                    fromViewController:(nullable UIViewController *)presentingVC
                        legacyFallback:(nullable void (^)(void))legacyFallback
                             onDismiss:(nullable void (^)(void))onDismiss;
+ (BOOL)openProfileForGalleryFile:(SPKGalleryFile *)file;
+ (BOOL)openProfileForGalleryFile:(SPKGalleryFile *)file fromViewController:(nullable UIViewController *)presentingVC;
// As above, but reports the real outcome. An item with no stored pk has to look
// one up first, so the open finishes a network round trip later than the call
// does: the BOOL variants answer "this was started", which is too early to
// announce. Anything that toasts on success must use this. `completion` runs on
// the main thread, once, whether the work was synchronous or not.
//
// `didLink` means the account was just backfilled onto the item, which already
// posted a toast of its own. A caller that would otherwise announce a plain
// "Opened profile" should stay quiet, so the two do not stack.
+ (void)openProfileForGalleryFile:(SPKGalleryFile *)file
               fromViewController:(nullable UIViewController *)presentingVC
                       completion:(nullable void (^)(BOOL success, BOOL didLink))completion;

@end

NS_ASSUME_NONNULL_END
