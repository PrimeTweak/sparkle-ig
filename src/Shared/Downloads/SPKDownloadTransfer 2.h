#import <Foundation/Foundation.h>

#import "SPKDownloadTypes.h"

NS_ASSUME_NONNULL_BEGIN

typedef void (^SPKDownloadTransferProgressBlock)(int64_t bytesWritten, int64_t totalBytesExpected, double progress);
typedef void (^SPKDownloadTransferCompletionBlock)(NSString *_Nullable stagedPath, NSError *_Nullable error);

@interface SPKDownloadTransfer : NSObject

- (void)downloadURL:(NSURL *)url
          mediaKind:(SPKDownloadMediaKind)mediaKind
      fileExtension:(nullable NSString *)fileExtension
         stagingDir:(NSString *)stagingDir
             itemID:(NSString *)itemID
           progress:(nullable SPKDownloadTransferProgressBlock)progress
         completion:(SPKDownloadTransferCompletionBlock)completion;

- (void)cancel;

@end

NS_ASSUME_NONNULL_END
