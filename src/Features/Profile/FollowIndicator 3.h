#import <Foundation/Foundation.h>

// Posted when a Following Indicator preference changes from the settings UI so
// the badge can refresh live. The profile settings shortcut presents settings
// as a sheet, which never re-fires the profile's viewDidAppear, so without this
// the look would only update after leaving and re-entering the profile.
FOUNDATION_EXPORT NSNotificationName const SPKFollowIndicatorDidChangeNotification;
