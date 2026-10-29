#import "SPKPreferences.h"
#import <sys/sysctl.h>

// A new key rather than an inverted meaning for the old one: interface_liquid_glass
// means "force the glass on", and flipping it would silently make everyone who
// had it enabled start forcing the glass off instead.
NSString *const kSPKPrefInterfaceDisableLiquidGlass = @"interface_disable_liquid_glass";

// Sparkle's own look, everywhere it can be drawn: the action button menu and
// every confirmation the tweak raises. Off falls back to what Instagram and
// iOS draw, so the app wears one style or the other and never a mix.
NSString *const kSPKPrefSparkleAppearance = @"action_button_sparkle_menu";
NSString *const kSPKPrefInterfaceLiquidGlassTabBarMode = @"interface_liquid_glass_tabbar_mode";
NSString *const kSPKPrefInterfaceScrollEdgeStyle = @"interface_scroll_edge_style";
NSNotificationName const SPKScrollEdgeStyleDidChangeNotification = @"SPKScrollEdgeStyleDidChangeNotification";
NSString *const kSPKPrefInstantsDisableCameraControl = @"instants_disable_camera_control";

NSString *SPKPrefActionButtonConfigKey(NSString *topicKey) {
    return [NSString stringWithFormat:@"%@_action_btn_cfg", topicKey ?: @""];
}

NSString *SPKPrefActionButtonDefaultActionKey(NSString *topicKey) {
    return [NSString stringWithFormat:@"%@_action_btn_default_action", topicKey ?: @""];
}

NSString *SPKPrefActionButtonBulkDownloadKey(NSString *topicKey) {
    return [NSString stringWithFormat:@"%@_action_btn_bulk_download_actions", topicKey ?: @""];
}

NSString *SPKPrefActionButtonBulkCopyKey(NSString *topicKey) {
    return [NSString stringWithFormat:@"%@_action_btn_bulk_copy_actions", topicKey ?: @""];
}

NSString *SPKPrefNotificationKey(NSString *identifier) {
    return [NSString stringWithFormat:@"notifs_%@", identifier ?: @""];
}

NSString *SPKPrefNotificationHapticKey(NSString *identifier) {
    return [NSString stringWithFormat:@"notifs_%@_haptic", identifier ?: @""];
}

// One key per section rather than one per notification.
//
// The per-notification keys are still written by SPKPrefNotificationKey and are
// left where they are, unread: keeping them means the finer switches can come
// back without anyone having to set them again.
NSString *SPKPrefNotificationSectionKey(NSString *sectionIdentifier) {
    return [NSString stringWithFormat:@"notifs_section_%@", sectionIdentifier ?: @""];
}

BOOL SPKDeviceHasCameraControl(void) {
    static BOOL hasCameraControl = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        char machine[64] = {0};
        size_t size = sizeof(machine);
        if (sysctlbyname("hw.machine", machine, &size, NULL, 0) != 0 || machine[0] == '\0') {
            return;
        }
        NSString *model = [NSString stringWithUTF8String:machine];

        // Models with the hardware Camera Control button. iPhone 16e (iPhone17,5)
        // is intentionally excluded — it has no Camera Control.
        static NSSet<NSString *> *cameraControlModels;
        cameraControlModels = [NSSet setWithArray:@[
            @"iPhone17,1", // iPhone 16 Pro
            @"iPhone17,2", // iPhone 16 Pro Max
            @"iPhone17,3", // iPhone 16
            @"iPhone17,4", // iPhone 16 Plus
            @"iPhone18,1", // iPhone 17 Pro
            @"iPhone18,2", // iPhone 17 Pro Max
            @"iPhone18,3", // iPhone 17
            @"iPhone18,4", // iPhone Air
        ]];
        hasCameraControl = [cameraControlModels containsObject:model];
    });
    return hasCameraControl;
}
