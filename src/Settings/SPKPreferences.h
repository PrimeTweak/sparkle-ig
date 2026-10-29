#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *const kSPKPrefInterfaceDisableLiquidGlass;
FOUNDATION_EXPORT NSString *const kSPKPrefSparkleAppearance;
FOUNDATION_EXPORT NSString *const kSPKPrefInterfaceLiquidGlassTabBarMode;
FOUNDATION_EXPORT NSString *const kSPKPrefInterfaceScrollEdgeStyle;
// Posted when the scroll edge style changes, so open screens pick it up live.
FOUNDATION_EXPORT NSNotificationName const SPKScrollEdgeStyleDidChangeNotification;
FOUNDATION_EXPORT NSString *const kSPKPrefInstantsDisableCameraControl;

#ifdef __cplusplus
extern "C" {
#endif

NSString *SPKPrefActionButtonConfigKey(NSString *topicKey);
NSString *SPKPrefActionButtonDefaultActionKey(NSString *topicKey);
NSString *SPKPrefActionButtonBulkDownloadKey(NSString *topicKey);
NSString *SPKPrefActionButtonBulkCopyKey(NSString *topicKey);
NSString *SPKPrefNotificationKey(NSString *identifier);
NSString *SPKPrefNotificationHapticKey(NSString *identifier);
NSString *SPKPrefNotificationSectionKey(NSString *sectionIdentifier);

/// YES on iPhone models that have the hardware Camera Control button
/// (iPhone 16/17 families, excluding iPhone 16e which lacks it).
BOOL SPKDeviceHasCameraControl(void);

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END
