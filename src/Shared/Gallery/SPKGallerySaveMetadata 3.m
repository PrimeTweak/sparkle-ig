#import "SPKGallerySaveMetadata.h"
#import "SPKGalleryFile.h"

@implementation SPKGallerySaveMetadata

- (instancetype)init {
    if ((self = [super init])) {
        _source = (int16_t)SPKGallerySourceFeed;
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
    SPKGallerySaveMetadata *c = [[SPKGallerySaveMetadata allocWithZone:zone] init];
    c.sourceUsername = [self.sourceUsername copy];
    c.sourceUserPK = [self.sourceUserPK copy];
    c.sourceProfileURLString = [self.sourceProfileURLString copy];
    c.sourceMediaPK = [self.sourceMediaPK copy];
    c.sourceMediaCode = [self.sourceMediaCode copy];
    c.sourceMediaURLString = [self.sourceMediaURLString copy];
    c.source = self.source;
    c.isAutoSave = self.isAutoSave;
    c.pixelWidth = self.pixelWidth;
    c.pixelHeight = self.pixelHeight;
    c.durationSeconds = self.durationSeconds;
    c.importFileNameStem = [self.importFileNameStem copy];
    c.customName = [self.customName copy];
    c.importCapturedDate = self.importCapturedDate;
    c.importPostedDate = self.importPostedDate;
    c.sourceFullName = [self.sourceFullName copy];
    return c;
}

- (NSDictionary *)spk_dictionaryRepresentation {
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    void (^setStr)(NSString *, NSString *) = ^(NSString *key, NSString *value) {
        if (value.length) {
            d[key] = value;
        }
    };
    setStr(@"sourceUsername", self.sourceUsername);
    setStr(@"sourceUserPK", self.sourceUserPK);
    setStr(@"sourceProfileURLString", self.sourceProfileURLString);
    setStr(@"sourceMediaPK", self.sourceMediaPK);
    setStr(@"sourceMediaCode", self.sourceMediaCode);
    setStr(@"sourceMediaURLString", self.sourceMediaURLString);
    setStr(@"importFileNameStem", self.importFileNameStem);
    setStr(@"customName", self.customName);
    d[@"source"] = @(self.source);
    if (self.pixelWidth > 0) {
        d[@"pixelWidth"] = @(self.pixelWidth);
    }
    if (self.pixelHeight > 0) {
        d[@"pixelHeight"] = @(self.pixelHeight);
    }
    if (self.durationSeconds > 0.0) {
        d[@"durationSeconds"] = @(self.durationSeconds);
    }
    if (self.importCapturedDate) {
        d[@"importCapturedDate"] = self.importCapturedDate;
    }
    if (self.importPostedDate) {
        d[@"importPostedDate"] = self.importPostedDate;
    }
    return d;
}

+ (instancetype)spk_metadataFromDictionary:(NSDictionary *)dict {
    SPKGallerySaveMetadata *m = [[self alloc] init];
    if (![dict isKindOfClass:[NSDictionary class]]) {
        return m;
    }
    NSString *(^str)(NSString *) = ^NSString *(NSString *key) {
        id v = dict[key];
        return [v isKindOfClass:[NSString class]] ? v : nil;
    };
    m.sourceUsername = str(@"sourceUsername");
    m.sourceUserPK = str(@"sourceUserPK");
    m.sourceProfileURLString = str(@"sourceProfileURLString");
    m.sourceMediaPK = str(@"sourceMediaPK");
    m.sourceMediaCode = str(@"sourceMediaCode");
    m.sourceMediaURLString = str(@"sourceMediaURLString");
    m.importFileNameStem = str(@"importFileNameStem");
    m.customName = str(@"customName");
    if ([dict[@"source"] isKindOfClass:[NSNumber class]]) {
        m.source = (int16_t)[dict[@"source"] intValue];
    }
    if ([dict[@"pixelWidth"] isKindOfClass:[NSNumber class]]) {
        m.pixelWidth = (int32_t)[dict[@"pixelWidth"] intValue];
    }
    if ([dict[@"pixelHeight"] isKindOfClass:[NSNumber class]]) {
        m.pixelHeight = (int32_t)[dict[@"pixelHeight"] intValue];
    }
    if ([dict[@"durationSeconds"] isKindOfClass:[NSNumber class]]) {
        m.durationSeconds = [dict[@"durationSeconds"] doubleValue];
    }
    if ([dict[@"importCapturedDate"] isKindOfClass:[NSDate class]]) {
        m.importCapturedDate = dict[@"importCapturedDate"];
    }
    if ([dict[@"importPostedDate"] isKindOfClass:[NSDate class]]) {
        m.importPostedDate = dict[@"importPostedDate"];
    }
    return m;
}

@end
