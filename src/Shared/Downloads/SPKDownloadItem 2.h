#import <Foundation/Foundation.h>

#import "SPKDownloadRequest.h"
#import "SPKDownloadTypes.h"

NS_ASSUME_NONNULL_BEGIN

@interface SPKDownloadItem : NSObject <NSCopying>
@property (nonatomic, copy) NSString *itemID;
@property (nonatomic, assign) NSInteger index;
@property (nonatomic, assign) SPKDownloadState state;
@property (nonatomic, assign) double progress;
@property (nonatomic, assign) int64_t bytesWritten;
@property (nonatomic, assign) int64_t totalBytesExpected;
@property (nonatomic, copy, nullable) NSString *stagedPath;
@property (nonatomic, copy, nullable) NSString *finalPath;
@property (nonatomic, copy, nullable) NSString *photosAssetIdentifier;
@property (nonatomic, strong, nullable) NSError *error;
@property (nonatomic, assign) SPKDownloadMediaKind mediaKind;
@property (nonatomic, copy, nullable) NSString *linkString;
@property (nonatomic, strong, nullable) SPKGallerySaveMetadata *metadata;
@property (nonatomic, assign) BOOL retryable;
@property (nonatomic, copy, nullable) NSString *detail;

@property (nonatomic, strong, readonly) SPKDownloadItemRequest *request;

- (instancetype)initWithRequest:(SPKDownloadItemRequest *)request;
- (NSDictionary *)dictionaryRepresentation;
+ (nullable instancetype)fromDictionary:(NSDictionary *)dict request:(SPKDownloadItemRequest *)request;
@end

@interface SPKDownloadMutableItemSnapshot : SPKDownloadItem
@end

NS_ASSUME_NONNULL_END
