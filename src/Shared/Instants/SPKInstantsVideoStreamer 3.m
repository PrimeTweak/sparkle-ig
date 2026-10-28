#import "SPKInstantsVideoStreamer.h"

#import "../../Utils.h"

#import <UIKit/UIKit.h>

@implementation SPKInstantsVideoStreamer

// All state is guarded by `sLock`. The frame requests arrive on the capture
// callback queue, while arm/stop/restart come from the main thread.
static NSLock *sLock = nil;
static NSURL *sVideoURL = nil;
static AVAssetReader *sReader = nil;
static AVAssetReaderOutput *sOutput = nil;

// `sHeld` is the frame currently due; `sNext` is the peeked frame after it, kept
// so we can tell when it becomes due without losing it.
static CMSampleBufferRef sHeld = NULL;
static CMSampleBufferRef sNext = NULL;

// Camera time of the first frame request, i.e. the origin the video plays from.
static CMTime sEpoch;
// Geometry the current reader was built for; a change rebuilds it.
static int32_t sWidth = 0;
static int32_t sHeight = 0;
static OSType sFormat = 0;
// While NO, the first frame is held as a still preview and the clock is ignored.
static BOOL sPlaying = NO;

+ (void)initialize {
    if (self == [SPKInstantsVideoStreamer class]) {
        sLock = [[NSLock alloc] init];
        sEpoch = kCMTimeInvalid;
    }
}

#pragma mark - Reader lifecycle (call with sLock held)

static void SPKInstantsStreamerReleaseBuffers(void) {
    if (sHeld) {
        CFRelease(sHeld);
        sHeld = NULL;
    }
    if (sNext) {
        CFRelease(sNext);
        sNext = NULL;
    }
}

static void SPKInstantsStreamerTeardownReader(void) {
    [sReader cancelReading];
    sReader = nil;
    sOutput = nil;
    SPKInstantsStreamerReleaseBuffers();
    sEpoch = kCMTimeInvalid;
}

/// Builds the composition that maps the source video into the camera's frame:
/// aspect-fit inside a centered square of side min(w, h), black elsewhere. This
/// mirrors the still-image injector's drawRect so a photo and a video Instant
/// are framed identically.
static AVVideoComposition *SPKInstantsStreamerComposition(AVAsset *asset, AVAssetTrack *track,
                                                          int32_t width, int32_t height) {
    CGSize natural = track.naturalSize;
    CGAffineTransform preferred = track.preferredTransform;
    CGSize rendered = CGSizeApplyAffineTransform(natural, preferred);
    CGSize oriented = CGSizeMake(fabs(rendered.width), fabs(rendered.height));
    if (oriented.width <= 0.0 || oriented.height <= 0.0)
        return nil;

    CGFloat side = MIN((CGFloat)width, (CGFloat)height);
    CGFloat scale = side / MAX(oriented.width, oriented.height);
    CGSize fitted = CGSizeMake(oriented.width * scale, oriented.height * scale);

    // preferredTransform puts the picture upright at `oriented` size with its
    // origin at 0,0; scale it into the square and centre it in the camera frame.
    CGAffineTransform transform = preferred;
    transform = CGAffineTransformConcat(transform, CGAffineTransformMakeScale(scale, scale));
    transform = CGAffineTransformConcat(
        transform, CGAffineTransformMakeTranslation(((CGFloat)width - fitted.width) / 2.0,
                                                    ((CGFloat)height - fitted.height) / 2.0));

    AVMutableVideoCompositionLayerInstruction *layer =
        [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:track];
    [layer setTransform:transform atTime:kCMTimeZero];

    AVMutableVideoCompositionInstruction *instruction = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
    instruction.timeRange = CMTimeRangeMake(kCMTimeZero, asset.duration);
    instruction.layerInstructions = @[ layer ];
    instruction.backgroundColor = [UIColor blackColor].CGColor;

    AVMutableVideoComposition *composition = [AVMutableVideoComposition videoComposition];
    composition.renderSize = CGSizeMake(width, height);
    CMTime frameDuration = track.minFrameDuration;
    if (!CMTIME_IS_NUMERIC(frameDuration) || CMTimeCompare(frameDuration, kCMTimeZero) <= 0) {
        frameDuration = CMTimeMake(1, 30);
    }
    composition.frameDuration = frameDuration;
    composition.instructions = @[ instruction ];
    return composition;
}

/// Returns YES when a reader is ready to serve frames.
static BOOL SPKInstantsStreamerEnsureReader(int32_t width, int32_t height, OSType format) {
    if (sReader && sWidth == width && sHeight == height && sFormat == format)
        return YES;
    if (!sVideoURL)
        return NO;

    SPKInstantsStreamerTeardownReader();
    sWidth = width;
    sHeight = height;
    sFormat = format;

    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:sVideoURL options:nil];
    AVAssetTrack *track = [asset tracksWithMediaType:AVMediaTypeVideo].firstObject;
    if (!track) {
        SPKLog(@"Instants", @"[Sparkle] video streamer: no video track");
        return NO;
    }
    AVVideoComposition *composition = SPKInstantsStreamerComposition(asset, track, width, height);
    if (!composition)
        return NO;

    NSError *error = nil;
    AVAssetReader *reader = [AVAssetReader assetReaderWithAsset:asset error:&error];
    if (!reader) {
        SPKLog(@"Instants", @"[Sparkle] video streamer: reader failed (%@)", error.localizedDescription);
        return NO;
    }
    // The compositor does the scaling, centring and pixel-format conversion, so
    // no per-frame CPU work lands on the capture callback queue.
    AVAssetReaderVideoCompositionOutput *output =
        [AVAssetReaderVideoCompositionOutput assetReaderVideoCompositionOutputWithVideoTracks:@[ track ]
                                                                               videoSettings:@{
                                                                                   (id)kCVPixelBufferPixelFormatTypeKey : @(format)
                                                                               }];
    output.videoComposition = composition;
    output.alwaysCopiesSampleData = NO;
    if (![reader canAddOutput:output]) {
        SPKLog(@"Instants", @"[Sparkle] video streamer: output rejected");
        return NO;
    }
    [reader addOutput:output];
    if (![reader startReading]) {
        SPKLog(@"Instants", @"[Sparkle] video streamer: startReading failed (%@)",
               reader.error.localizedDescription);
        return NO;
    }

    sReader = reader;
    sOutput = output;
    sNext = [output copyNextSampleBuffer];
    SPKLog(@"Instants", @"[Sparkle] video streamer reader built %dx%d fmt=%c%c%c%c firstFrame=%d", width, height,
           (char)((format >> 24) & 0xFF), (char)((format >> 16) & 0xFF), (char)((format >> 8) & 0xFF),
           (char)(format & 0xFF), sNext != NULL);
    return sNext != NULL;
}

#pragma mark - Public

+ (void)startWithVideoURL:(NSURL *)videoURL {
    if (!videoURL)
        return;
    [sLock lock];
    sVideoURL = videoURL;
    sPlaying = NO;
    SPKInstantsStreamerTeardownReader();
    [sLock unlock];
    SPKLog(@"Instants", @"[Sparkle] video streamer armed: %@", videoURL.lastPathComponent);
}

+ (void)stop {
    [sLock lock];
    sVideoURL = nil;
    sPlaying = NO;
    SPKInstantsStreamerTeardownReader();
    [sLock unlock];
}

+ (BOOL)isArmed {
    [sLock lock];
    BOOL armed = (sVideoURL != nil);
    [sLock unlock];
    return armed;
}

+ (void)play {
    [sLock lock];
    if (sVideoURL && !sPlaying) {
        // The paused reader is already sitting on frame 0 (holding it is what the
        // still preview does), so playback just starts consuming from where it
        // is. Rebuilding here instead would stall the capture queue ~90ms right
        // as the take begins, which is exactly the part we must not miss.
        sEpoch = kCMTimeInvalid;
        sPlaying = YES;
        SPKLog(@"Instants", @"[Sparkle] video streamer playing");
    }
    [sLock unlock];
}

+ (void)pause {
    [sLock lock];
    if (sVideoURL && sPlaying) {
        SPKInstantsStreamerTeardownReader();
        sPlaying = NO;
        SPKLog(@"Instants", @"[Sparkle] video streamer holding first frame");
    }
    [sLock unlock];
}

+ (CVPixelBufferRef)copyPixelBufferForCameraTime:(CMTime)cameraTime
                                           width:(int32_t)width
                                          height:(int32_t)height
                                          format:(OSType)format {
    if (width <= 0 || height <= 0)
        return NULL;

    [sLock lock];
    if (!sVideoURL) {
        [sLock unlock];
        return NULL;
    }
    if (!SPKInstantsStreamerEnsureReader(width, height, format)) {
        [sLock unlock];
        return NULL;
    }
    if (!sPlaying) {
        // Held as a still preview: serve the first frame and never advance, so a
        // take starts at the video's beginning rather than mid-playback.
        if (!sHeld && sNext) {
            sHeld = sNext;
            sNext = [sOutput copyNextSampleBuffer];
        }
        CVPixelBufferRef first = sHeld ? CMSampleBufferGetImageBuffer(sHeld) : NULL;
        if (first) {
            CVPixelBufferRetain(first);
        }
        [sLock unlock];
        return first;
    }

    if (!CMTIME_IS_NUMERIC(cameraTime)) {
        [sLock unlock];
        return NULL;
    }
    if (!CMTIME_IS_NUMERIC(sEpoch)) {
        sEpoch = cameraTime;
    }

    CMTime target = CMTimeSubtract(cameraTime, sEpoch);
    // One line per served second of playback: enough to tell "never started" from
    // "started but stuck on one frame" without flooding the log at frame rate.
    static int64_t sLoggedSecond = -1;
    int64_t second = (int64_t)CMTimeGetSeconds(target);
    if (second != sLoggedSecond) {
        sLoggedSecond = second;
        SPKLog(@"Instants", @"[Sparkle] video streamer serving t=%llds", second);
    }
    // Advance while the peeked frame is due, holding the last one that was.
    while (sNext && CMTimeCompare(CMSampleBufferGetPresentationTimeStamp(sNext), target) <= 0) {
        if (sHeld) {
            CFRelease(sHeld);
        }
        sHeld = sNext;
        sNext = [sOutput copyNextSampleBuffer];
    }

    if (!sNext) {
        // Ran off the end: loop by rebuilding and re-anchoring to now, so the
        // feed keeps moving the way a camera would rather than freezing. Serve
        // the new first frame in the same call, so no live frame slips through.
        SPKInstantsStreamerTeardownReader();
        if (!SPKInstantsStreamerEnsureReader(width, height, format)) {
            [sLock unlock];
            return NULL;
        }
        sEpoch = cameraTime;
        if (sNext) {
            sHeld = sNext;
            sNext = [sOutput copyNextSampleBuffer];
        }
    }
    if (!sHeld) {
        [sLock unlock];
        return NULL;
    }

    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sHeld);
    if (pixelBuffer) {
        CVPixelBufferRetain(pixelBuffer);
    }
    [sLock unlock];
    return pixelBuffer;
}

@end
