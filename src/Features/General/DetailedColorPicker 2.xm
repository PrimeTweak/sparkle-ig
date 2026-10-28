#import "../../InstagramHeaders.h"
#import "../../Utils.h"
#import "../../App/SPKPerfMeter.h"

%group SPKDetailedColorPickerHooks

%hook IGStoryEyedropperToggleButton
- (void)didMoveToWindow {
    %orig;
    SPK_PERF_SCOPE(@"DetailedColorPicker.didMoveToWindow");

    if ([SPKUtils getBoolPref:@"stories_detailed_color_picker"]) {
        [self addLongPressGestureRecognizer];
    }

    return;
}

%new - (void)addLongPressGestureRecognizer {
if ([self.gestureRecognizers count] == 0) {
    SPKLog(@"General", @"[Sparkle] Adding color eyedroppper long press gesture recognizer");

    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
    longPress.minimumPressDuration = 0.25;
    [self addGestureRecognizer:longPress];
}
}
%new - (void)handleLongPress:(UILongPressGestureRecognizer *)sender {
if (sender.state != UIGestureRecognizerStateBegan)
    return;

UIColorPickerViewController *colorPickerController = [[UIColorPickerViewController alloc] init];

colorPickerController.delegate = (id<UIColorPickerViewControllerDelegate>)self; // cast to suppress warnings
colorPickerController.title = @"Select color";
colorPickerController.modalPresentationStyle = UIModalPresentationPopover;
colorPickerController.supportsAlpha = NO;
colorPickerController.selectedColor = self.color;

UIViewController *presentingVC = [SPKUtils nearestViewControllerForView:self];

if (presentingVC != nil) {
    [presentingVC presentViewController:colorPickerController animated:YES completion:nil];
}
}

// UIColorPickerViewControllerDelegate Protocol
%new - (void)colorPickerViewController:(UIColorPickerViewController *)viewController
didSelectColor : (UIColor *)color
                 continuously : (BOOL)continuously {
    SPKLog(@"General", @"[Sparkle] Selected text color: %@", color);

    UIColor *opaque = [color colorWithAlphaComponent:1.0];
    self.color = opaque;

    [self setPushedDown:YES];

    // Trigger change for text color
    id presentingVC = [SPKUtils nearestViewControllerForView:self];

    if ([presentingVC isKindOfClass:%c(IGStoryTextEntryViewController)]) {
        [presentingVC textViewControllerDidUpdateWithColor:color colorSource:0];
    } else if (
        [presentingVC isKindOfClass:SPKResolveIGClass(@"IGStoryPostCaptureDrawing.IGStoryCreationDrawingViewController", @"IGStoryCreationDrawingViewController")] || [presentingVC isKindOfClass:%c(IGDirectThreadViewDrawingViewController)]) {
        [presentingVC drawingControls:nil didSelectColor:color];
    }
};
%end

%hook IGStoryColorPaletteView
- (CGFloat)collectionView:(id)view didSelectItemAtIndexPath:(id)index {
    UIView *colorPickingControls = [self superview];

    if (
        [colorPickingControls isKindOfClass:SPKResolveIGClass(@"IGStoryPostCaptureDrawingControls.IGStoryColorPickingControls", @"IGStoryColorPickingControls")] || [colorPickingControls isKindOfClass:%c(IGDirectThreadColorPickingControls)]) {
        IGStoryEyedropperToggleButton *_eyedropperToggleButton = MSHookIvar<IGStoryEyedropperToggleButton *>(colorPickingControls, "_eyedropperToggleButton");

        if (_eyedropperToggleButton != nil) {
            [_eyedropperToggleButton setPushedDown:NO];
        }
    }

    return %orig;
}
%end

%end

extern "C" void SPKInstallDetailedColorPickerHooksIfEnabled(void) {
    if (![SPKUtils getBoolPref:@"stories_detailed_color_picker"])
        return;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        %init(SPKDetailedColorPickerHooks);
    });
}
