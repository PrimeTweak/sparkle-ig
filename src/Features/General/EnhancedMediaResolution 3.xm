#import "../../Utils.h"

static NSString *const kSPKEnhancedMediaResolutionDefaultsKey = @"downloads_enhanced_media_resolution";

static const NSInteger kSPKHighResUserAgentWidth = 2064;
static const NSInteger kSPKHighResUserAgentHeight = 2752;
static const CGFloat kSPKHighResUserAgentScale = 3.0;

static BOOL SPKEnhancedMediaResolutionEnabled(void) {
    return [SPKUtils getBoolPref:kSPKEnhancedMediaResolutionDefaultsKey];
}

@interface IGURLRequest : NSMutableURLRequest
@end

/// Replaces `\d{3,4}x\d{3,4}` and `scale=\d+\.\d+` in Instagram's UA.
static NSString *SPKHighResUserAgentStringFromString(NSString *userAgent) {
    if (userAgent.length == 0) {
        return userAgent;
    }

    NSError *error = nil;
    NSRegularExpression *dimensionRegex = [NSRegularExpression regularExpressionWithPattern:@"\\d{3,4}x\\d{3,4}"
                                                                                    options:0
                                                                                      error:&error];
    NSString *dimensionTemplate = [NSString stringWithFormat:@"%ldx%ld",
                                                             (long)kSPKHighResUserAgentWidth,
                                                             (long)kSPKHighResUserAgentHeight];
    NSString *step1 = [dimensionRegex stringByReplacingMatchesInString:userAgent
                                                               options:0
                                                                 range:NSMakeRange(0, userAgent.length)
                                                          withTemplate:dimensionTemplate];

    NSRegularExpression *scaleRegex = [NSRegularExpression regularExpressionWithPattern:@"scale=\\d+\\.\\d+"
                                                                                options:0
                                                                                  error:&error];
    NSString *scaleTemplate = [NSString stringWithFormat:@"scale=%.2f", kSPKHighResUserAgentScale];
    return [scaleRegex stringByReplacingMatchesInString:step1
                                                options:0
                                                  range:NSMakeRange(0, step1.length)
                                           withTemplate:scaleTemplate];
}

static NSString *SPKHighResHeaderValueIfNeeded(NSURLRequest *request, NSString *value, NSString *field) {
    if (!SPKEnhancedMediaResolutionEnabled()) {
        return value;
    }
    if (![value isKindOfClass:[NSString class]] || ![field isKindOfClass:[NSString class]] || field.length == 0) {
        return value;
    }
    if ([field caseInsensitiveCompare:@"User-Agent"] != NSOrderedSame) {
        return value;
    }
    
    // Crucial: Bypass User-Agent spoofing for Direct Messages and Share Sheet.
    // The iPad Pro UA causes the backend to fallback to 750pt Instants.
    if ([request.URL.path containsString:@"direct_v2"] || [request.URL.path containsString:@"banyan"]) {
        return value;
    }
    
    return SPKHighResUserAgentStringFromString(value);
}

%group SPKEnhancedMediaResolutionHooks

%hook NSMutableURLRequest

- (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field {
    %orig(SPKHighResHeaderValueIfNeeded(self, value, field), field);
}

- (void)setAllHTTPHeaderFields:(NSDictionary *)headerFields {
    if (!SPKEnhancedMediaResolutionEnabled() || headerFields.count == 0) {
        %orig(headerFields);
        return;
    }

    NSMutableDictionary *headers = [NSMutableDictionary dictionaryWithDictionary:headerFields];
    for (NSString *key in headerFields) {
        if (![key isKindOfClass:[NSString class]]) {
            continue;
        }
        if ([key caseInsensitiveCompare:@"User-Agent"] != NSOrderedSame) {
            continue;
        }
        id existing = headers[key];
        if ([existing isKindOfClass:[NSString class]]) {
            headers[key] = SPKHighResHeaderValueIfNeeded(self, existing, key);
        }
        break;
    }
    %orig(headers);
}

%end

%hook IGURLRequest

- (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field {
    %orig(SPKHighResHeaderValueIfNeeded(self, value, field), field);
}

%end

%end

extern "C" void SPKInstallEnhancedMediaResolutionHooksIfEnabled(void) {
    if (!SPKEnhancedMediaResolutionEnabled())
        return;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        %init(SPKEnhancedMediaResolutionHooks);
    });
}
