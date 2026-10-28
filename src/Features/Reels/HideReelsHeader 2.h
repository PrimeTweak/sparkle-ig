#import <Foundation/Foundation.h>

// Posted when the Hide Reels Header preference changes from settings. The reels viewer builds its
// navigation bar once per session, so bars already on screen are reconciled from this.
FOUNDATION_EXPORT NSNotificationName const SPKHideReelsHeaderDidChangeNotification;
