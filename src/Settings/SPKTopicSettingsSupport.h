#import <UIKit/UIKit.h>

#import "../Shared/ActionButton/ActionButtonCore.h"
#import "../Shared/ActionButton/SPKActionMenuSection.h"
#import "SPKSetting.h"

// ─────────────────────────────────────────────────────────────────────────────
//  ROW ORDER CONVENTION (v2.2)
//
//  A row is placed by the distance its gesture travels:
//
//     1. switch ............ nothing opens, the effect is immediate
//     2. gate .............. a pack of switches answering ONE question;
//                            the menu opens on the row itself
//     3. value picker ...... menu or stepper, a single answer
//     4. sub-page .......... leaves the screen and comes back
//     5. action ............ something happens now; destructive goes last
//
//  R1 (overrides all) A dependent row sits directly under the row that
//                     controls it, whatever its type.
//  R2                 At equal footing, the scale above.
//  R3 (exception)     A row that IS the subject of its section opens it
//                     (Open FLEX Now, Default Feed). Limited to that case.
//  R4 (invariant)     The closing block — Action Button, then Confirmations,
//                     untitled — never moves: repetition teaches it.
//  R5                 What does not apply does not appear: a dependent row
//                     carries a `hiddenProvider` that removes it while its
//                     master is off, and the master carries
//                     `reloadsTableOnSwitchChange` so the reveal happens in
//                     place. A master that reveals rows announces them in its
//                     help text.
//  R6                 Section order: the page's signature section opens,
//                     destructive sections close, a single-row navigation
//                     section joins the closing block.
//  R7 (under R6)      At equal standing, a section holding a master switch
//                     follows a section whose rows are always shown: the part
//                     of the page whose height varies sits last.
//
//  A gate exists only when its question can be named ("confirm what?",
//  "hide where?"). Otherwise the rows form a section, not a menu.
//  Gate rows read "Off" at zero enabled items; the counter starts at 1.
//  A section header must cover at least two rows in every state; a header
//  repeating the page title is dropped and the section goes untitled.
// ─────────────────────────────────────────────────────────────────────────────

NS_ASSUME_NONNULL_BEGIN

NSDictionary *SPKTopicSection(NSString *header, NSArray *rows, NSString *_Nullable footer);
FOUNDATION_EXPORT CGFloat const SPKSettingsCellIconPointSize;
UIImage *SPKSettingsIcon(NSString *name);
UIImage *SPKSettingsSystemIcon(NSString *name, CGFloat pointSize, UIImageSymbolWeight weight);
SPKSetting *SPKSettingApplyIconTint(SPKSetting *setting, UIColor *_Nullable tintColor);
SPKSetting *SPKSettingApplySelectedMenuIcon(SPKSetting *setting, UIImage *_Nullable fallbackIcon);
SPKSetting *SPKTopicNavigationSetting(NSString *title, NSString *iconName, CGFloat iconSize, NSArray *sections);
/// Wraps a screen's Action Button controls into one navigation row that carries
/// the state in its accessory ("On" / "Off"). Six screens shipped the same
/// three-row section at the top; this puts it behind one row at the bottom.
/// `rows` is whatever that screen had — nothing about the controls changes.
SPKSetting *SPKActionButtonRowSetting(NSString *enabledKey, NSString *_Nullable footer, NSArray<SPKSetting *> *rows);

SPKSetting *SPKActionButtonDefaultActionNavigationSetting(SPKActionButtonSource source);
SPKSetting *SPKActionButtonConfigurationNavigationSetting(SPKActionButtonSource source, NSString *topicTitle, NSArray<NSString *> *supportedActions, NSArray<SPKActionMenuSection *> *defaultSections);
UIMenu *SPKReelsTapControlMenu(void);
UIMenu *SPKMainFeedModeMenu(void);
UIMenu *SPKSeenButtonPositionMenu(void);
UIMenu *SPKLastActiveFormatMenu(void);
UIMenu *SPKLaunchTabMenu(void);
UIMenu *SPKSwipeBetweenTabsMenu(void);
UIMenu *SPKLiquidGlassTabBarStateMenu(void);
UIMenu *SPKSwipeCloseCommentsDirectionMenu(void);
UIMenu *SPKCacheAutoClearMenu(void);
UIMenu *SPKNotificationProgressSubtitleStyleMenu(void);
UIMenu *SPKNotificationPillPositionMenu(void);
UIMenu *SPKMediaVideoQualityMenu(void);
UIMenu *SPKMediaPhotoQualityMenu(void);
UIMenu *SPKAutoSaveDestinationMenu(void);
UIMenu *SPKAutoSaveVideoQualityMenu(void);
UIMenu *SPKAutoSavePhotoQualityMenu(void);
UIMenu *SPKAutoSaveFilterModeMenu(NSString *filterModeKey, NSString *subjectPlural);
UIMenu *SPKStoryAutoSaveFilterModeMenu(void);
UIMenu *SPKGalleryShortcutTargetMenu(void);
UIMenu *SPKCommentSortModeMenu(void);

NS_ASSUME_NONNULL_END
