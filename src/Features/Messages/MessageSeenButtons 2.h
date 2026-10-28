#import <Foundation/Foundation.h>

// Posted when the manual-seen button placement (`msgs_seen_button_position`)
// changes from the settings sheet, so an open thread can reconcile its nav-bar
// button and composer bubble live instead of waiting for a view reset.
FOUNDATION_EXPORT NSNotificationName const SPKMessageSeenButtonPositionDidChangeNotification;
