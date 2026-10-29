#import <UIKit/UIKit.h>

/// Moves the Instants viewer forward by one snap the way a tap does, by replaying a press
/// (began, changed, ended) on the viewer's tap controller with a detached recognizer.
/// `hint` is any view in the viewer's window; returns NO when no snap stack is visible.
FOUNDATION_EXPORT BOOL SPKInstantsAdvanceViewer(UIView *hint);
