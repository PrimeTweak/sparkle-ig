#import <UIKit/UIKit.h>

#import "SPKTrimConfiguration.h"
#import "SPKTrimResult.h"

NS_ASSUME_NONNULL_BEGIN

@class SPKTrimEditorViewController;

/// Full-screen media trim editor: preview + filmstrip scrubber + in/out handles
/// + optional single-frame mode. On confirm it renders a temp file and reports
/// an `SPKTrimResult`. The editor never saves — the caller routes the result.
@interface SPKTrimEditorViewController : UIViewController

@property (nonatomic, copy, nullable) void (^completion)(SPKTrimResult *_Nullable result);

- (instancetype)initWithConfiguration:(SPKTrimConfiguration *)configuration;

/// Convenience: build, present full-screen from `presenter`, and report the
/// result (nil on cancel) via `completion`.
+ (void)presentWithConfiguration:(SPKTrimConfiguration *)configuration
                            from:(UIViewController *)presenter
                      completion:(nullable void (^)(SPKTrimResult *_Nullable result))completion;

@end

NS_ASSUME_NONNULL_END
