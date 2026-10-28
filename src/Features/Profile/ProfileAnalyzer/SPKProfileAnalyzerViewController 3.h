#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SPKProfileAnalyzerViewController : UIViewController
// Presents the analyzer modally from the top-most controller. Used by the
// notification pill (tap during progress / on completion) to jump straight in.
+ (void)presentFromTop;
@end

NS_ASSUME_NONNULL_END
