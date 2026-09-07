#import "SPKTrimCrop.h"

// Rounds down to an even number >= 2. H.264 (yuv420p) needs even dimensions on
// both axes, and an odd crop origin shifts chroma siting, so both are snapped.
static CGFloat SPKTrimCropEven(CGFloat value, CGFloat minimum) {
    CGFloat rounded = floor(value / 2.0) * 2.0;
    return MAX(rounded, minimum);
}

@implementation SPKTrimCrop

+ (instancetype)cropWithNormalizedRect:(CGRect)normalizedRect
                      rotationQuarters:(NSInteger)rotationQuarters
                              mirrored:(BOOL)mirrored {
    SPKTrimCrop *crop = [self new];
    crop.normalizedRect = normalizedRect;
    crop.rotationQuarters = ((rotationQuarters % 4) + 4) % 4;
    crop.mirrored = mirrored;
    return crop;
}

- (id)copyWithZone:(__unused NSZone *)zone {
    return [SPKTrimCrop cropWithNormalizedRect:self.normalizedRect
                              rotationQuarters:self.rotationQuarters
                                      mirrored:self.mirrored];
}

- (BOOL)isIdentity {
    if (self.rotationQuarters != 0 || self.mirrored)
        return NO;
    CGRect r = self.normalizedRect;
    // Sub-pixel slack: a "full frame" selection that is off by a rounding error
    // isn't worth a re-encode pass.
    const CGFloat epsilon = 0.002;
    return (r.origin.x <= epsilon && r.origin.y <= epsilon &&
            r.size.width >= 1.0 - epsilon && r.size.height >= 1.0 - epsilon);
}

- (CGSize)rotatedSizeForOrientedSize:(CGSize)orientedSize {
    if (self.rotationQuarters % 2 == 1)
        return CGSizeMake(orientedSize.height, orientedSize.width);
    return orientedSize;
}

- (CGRect)pixelRectForOrientedSize:(CGSize)orientedSize {
    CGSize rotated = [self rotatedSizeForOrientedSize:orientedSize];
    if (rotated.width <= 0.0 || rotated.height <= 0.0)
        return CGRectZero;

    CGRect r = CGRectIntersection(self.normalizedRect, CGRectMake(0.0, 0.0, 1.0, 1.0));
    if (CGRectIsNull(r) || CGRectIsEmpty(r))
        r = CGRectMake(0.0, 0.0, 1.0, 1.0);

    CGFloat x = SPKTrimCropEven(r.origin.x * rotated.width, 0.0);
    CGFloat y = SPKTrimCropEven(r.origin.y * rotated.height, 0.0);
    CGFloat w = SPKTrimCropEven(r.size.width * rotated.width, 2.0);
    CGFloat h = SPKTrimCropEven(r.size.height * rotated.height, 2.0);
    // Clamp inside the frame after the even-snapping, which can push the far edge
    // past the boundary on a selection that already reached it.
    w = MIN(w, SPKTrimCropEven(rotated.width - x, 2.0));
    h = MIN(h, SPKTrimCropEven(rotated.height - y, 2.0));
    return CGRectMake(x, y, w, h);
}

- (NSString *)ffmpegFilterForOrientedSize:(CGSize)orientedSize {
    if (self.isIdentity)
        return nil;
    NSMutableArray<NSString *> *filters = [NSMutableArray array];
    // FFmpeg decodes with the container's display matrix already applied, so the
    // frame it hands us is the oriented one — the same space the crop rect is in.
    // transpose=1 is a single 90° clockwise turn.
    for (NSInteger i = 0; i < self.rotationQuarters; i++) {
        [filters addObject:@"transpose=1"];
    }
    if (self.mirrored) {
        [filters addObject:@"hflip"];
    }
    CGRect pixels = [self pixelRectForOrientedSize:orientedSize];
    if (pixels.size.width > 0.0 && pixels.size.height > 0.0) {
        [filters addObject:[NSString stringWithFormat:@"crop=%ld:%ld:%ld:%ld",
                                                      (long)lround(pixels.size.width),
                                                      (long)lround(pixels.size.height),
                                                      (long)lround(pixels.origin.x),
                                                      (long)lround(pixels.origin.y)]];
    }
    return filters.count > 0 ? [filters componentsJoinedByString:@","] : nil;
}

@end
