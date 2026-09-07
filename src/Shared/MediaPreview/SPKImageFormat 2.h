#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, SPKImageFormat) {
    SPKImageFormatUnknown = 0,
    SPKImageFormatJPEG,
    SPKImageFormatPNG,
    SPKImageFormatGIF,
    SPKImageFormatWebP,
    SPKImageFormatMP4,
};

FOUNDATION_EXPORT SPKImageFormat SPKImageFormatForData(NSData *_Nullable data);
FOUNDATION_EXPORT SPKImageFormat SPKImageFormatForFileURL(NSURL *_Nullable fileURL);
FOUNDATION_EXPORT NSString *_Nullable SPKFileExtensionForImageFormat(SPKImageFormat format);
FOUNDATION_EXPORT NSString *_Nullable SPKMIMETypeForImageFormat(SPKImageFormat format);
FOUNDATION_EXPORT NSString *_Nullable SPKFileExtensionForMediaResponse(NSData *_Nullable data,
                                                                       NSURLResponse *_Nullable response,
                                                                       NSURL *_Nullable sourceURL);

NS_ASSUME_NONNULL_END
