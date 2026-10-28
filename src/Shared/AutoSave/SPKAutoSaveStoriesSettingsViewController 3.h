#import <UIKit/UIKit.h>

#import "SPKAutoSaveSurfaceSettingsViewController.h"

NS_ASSUME_NONNULL_BEGIN

/// Downloads > Auto-Save > Stories.
@interface SPKAutoSaveStoriesSettingsViewController : SPKAutoSaveSurfaceSettingsViewController
@end

/// Downloads > Auto-Save > Messages. View-once / replayable DM media, keyed by chat.
@interface SPKAutoSaveMessagesSettingsViewController : SPKAutoSaveSurfaceSettingsViewController
@end

/// Downloads > Auto-Save > Instants.
@interface SPKAutoSaveInstantsSettingsViewController : SPKAutoSaveSurfaceSettingsViewController
@end

NS_ASSUME_NONNULL_END
