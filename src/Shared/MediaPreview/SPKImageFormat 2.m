#import "SPKImageFormat.h"

SPKImageFormat SPKImageFormatForData(NSData *data) {
    if (data.length < 4)
        return SPKImageFormatUnknown;
    const unsigned char *bytes = data.bytes;
    if (data.length >= 6 && (!memcmp(bytes, "GIF87a", 6) || !memcmp(bytes, "GIF89a", 6))) {
        return SPKImageFormatGIF;
    }
    if (data.length >= 12 && !memcmp(bytes, "RIFF", 4) && !memcmp(bytes + 8, "WEBP", 4)) {
        return SPKImageFormatWebP;
    }
    if (data.length >= 8 && !memcmp(bytes, "\x89PNG\r\n\x1a\n", 8)) {
        return SPKImageFormatPNG;
    }
    if (bytes[0] == 0xff && bytes[1] == 0xd8 && bytes[2] == 0xff) {
        return SPKImageFormatJPEG;
    }
    if (data.length >= 12 && !memcmp(bytes + 4, "ftyp", 4)) {
        return SPKImageFormatMP4;
    }
    return SPKImageFormatUnknown;
}

SPKImageFormat SPKImageFormatForFileURL(NSURL *fileURL) {
    if (!fileURL.isFileURL)
        return SPKImageFormatUnknown;
    NSData *data = [NSData dataWithContentsOfURL:fileURL options:NSDataReadingMappedIfSafe error:nil];
    return SPKImageFormatForData(data);
}

NSString *SPKFileExtensionForImageFormat(SPKImageFormat format) {
    switch (format) {
    case SPKImageFormatJPEG:
        return @"jpg";
    case SPKImageFormatPNG:
        return @"png";
    case SPKImageFormatGIF:
        return @"gif";
    case SPKImageFormatWebP:
        return @"webp";
    case SPKImageFormatMP4:
        return @"mp4";
    default:
        return nil;
    }
}

NSString *SPKMIMETypeForImageFormat(SPKImageFormat format) {
    switch (format) {
    case SPKImageFormatJPEG:
        return @"image/jpeg";
    case SPKImageFormatPNG:
        return @"image/png";
    case SPKImageFormatGIF:
        return @"image/gif";
    case SPKImageFormatWebP:
        return @"image/webp";
    case SPKImageFormatMP4:
        return @"video/mp4";
    default:
        return nil;
    }
}

NSString *SPKFileExtensionForMediaResponse(NSData *data, NSURLResponse *response, NSURL *sourceURL) {
    NSString *detected = SPKFileExtensionForImageFormat(SPKImageFormatForData(data));
    if (detected.length)
        return detected;

    NSString *mime = response.MIMEType.lowercaseString;
    NSDictionary *mimeExtensions = @{
        @"image/gif" : @"gif",
        @"image/webp" : @"webp",
        @"image/jpeg" : @"jpg",
        @"image/jpg" : @"jpg",
        @"image/png" : @"png",
        @"video/mp4" : @"mp4",
    };
    NSString *fromMIME = mimeExtensions[mime];
    if (fromMIME.length)
        return fromMIME;

    NSString *suggested = response.suggestedFilename.pathExtension.lowercaseString;
    if (suggested.length)
        return suggested;
    return sourceURL.pathExtension.lowercaseString;
}
