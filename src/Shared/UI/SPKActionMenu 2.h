#pragma once

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

// SPKActionMenu — the action button's menu, drawn by Sparkle instead of UIKit.
//
// It exists because a native UIMenu hands us no control over the three things
// that make a menu look like ours: there is no hairline between sibling rows,
// the row height is UIKit's, and the leading margin is a fixed column that
// ignores the image we pass (measured: shrinking the glyph from 22 pt to 18 pt
// moved the title by zero pixels).
//
// Same anatomy as SPKToggleMenu (convention v1.2): icon left, 44 pt rows,
// 14 pt margin, a hairline between every row. Two things it adds:
//
//   · SUBMENUS. A node with children swaps the menu to that level, headed by a
//     row carrying the submenu's name and a chevron that goes back.
//   · ADAPTIVE WIDTH. Titles here are long ("Save Audio to Gallery"), so the
//     menu measures its widest row instead of sitting at a fixed 262 pt.

@interface SPKActionMenuNode : NSObject

/// A row that performs something. `handler` runs after the menu closes.
/// A nil handler makes the row a read-only line (the profile's Followers /
/// Following info rows): dimmed, and it ignores taps.
+ (instancetype)leafWithTitle:(NSString *)title
                        image:(nullable UIImage *)image
                      handler:(nullable dispatch_block_t)handler;

/// A row that opens a level of its own.
+ (instancetype)branchWithTitle:(NSString *)title
                          image:(nullable UIImage *)image
                       children:(NSArray<SPKActionMenuNode *> *)children;

@property (nonatomic, copy, readonly) NSString *title;
@property (nonatomic, strong, readonly, nullable) UIImage *image;
@property (nonatomic, copy, readonly, nullable) dispatch_block_t handler;
@property (nonatomic, copy, readonly, nullable) NSArray<SPKActionMenuNode *> *children;

@end

@interface SPKActionMenu : NSObject

/// Opens the menu under `anchorView`, or above it when there is no room below.
+ (void)presentNodes:(NSArray<SPKActionMenuNode *> *)nodes
            fromView:(UIView *)anchorView
           onDismiss:(void (^_Nullable)(void))onDismiss;

@end

NS_ASSUME_NONNULL_END
