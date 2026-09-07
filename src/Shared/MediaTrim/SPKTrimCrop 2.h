#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// A framing edit for a video: an optional quarter-turn rotation, an optional
/// horizontal mirror, and a crop rectangle.
///
/// Coordinate space: the source's *oriented* frame — what the viewer sees, i.e.
/// after the track's `preferredTransform` (or, for FFmpeg, after its automatic
/// display-matrix rotation). `rotationQuarters` and `mirrored` are applied first,
/// and `normalizedRect` is expressed in that rotated/mirrored space, so a crop is
/// always "the rectangle the user drew over the picture they were looking at".
@interface SPKTrimCrop : NSObject <NSCopying>

/// Crop rectangle, normalized 0..1 in the rotated/mirrored oriented frame.
@property (nonatomic, assign) CGRect normalizedRect;

/// Quarter turns clockwise (0-3) applied before the crop.
@property (nonatomic, assign) NSInteger rotationQuarters;

/// Horizontal mirror applied after the rotation, before the crop.
@property (nonatomic, assign) BOOL mirrored;

/// YES when this describes the untouched full frame, so callers can drop it and
/// keep the plain (cheaper, byte-identical) render path.
@property (nonatomic, readonly) BOOL isIdentity;

+ (instancetype)cropWithNormalizedRect:(CGRect)normalizedRect
                      rotationQuarters:(NSInteger)rotationQuarters
                              mirrored:(BOOL)mirrored;

/// The frame size after the rotation but before the crop, for a source whose
/// oriented render size is `orientedSize` (odd quarter turns swap the axes).
- (CGSize)rotatedSizeForOrientedSize:(CGSize)orientedSize;

/// The crop rectangle in pixels within the rotated frame. Origin and size are
/// snapped to even numbers — H.264 encoders reject odd dimensions.
- (CGRect)pixelRectForOrientedSize:(CGSize)orientedSize;

/// The FFmpeg `-vf` fragment ("transpose=1,hflip,crop=w:h:x:y") for a source with
/// this oriented size, or nil when there is nothing to do.
- (nullable NSString *)ffmpegFilterForOrientedSize:(CGSize)orientedSize;

@end

NS_ASSUME_NONNULL_END
