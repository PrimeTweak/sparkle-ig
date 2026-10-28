#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

#ifdef __cplusplus
extern "C" {
#endif

FOUNDATION_EXPORT BOOL SPKFlexIsBundled(void);
FOUNDATION_EXPORT BOOL SPKFlexIsLoaded(void);
FOUNDATION_EXPORT BOOL SPKFlexLoadIfNeeded(void);
FOUNDATION_EXPORT void SPKFlexShowExplorer(NSString *trigger);
FOUNDATION_EXPORT Class _Nullable SPKFlexWindowClass(void);

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END
