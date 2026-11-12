#import "UIUtil.h"
#import "Prefs.h"

UIWindow *TSKeyWindow(void) {
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;
        if (scene.activationState != UISceneActivationStateForegroundActive &&
            scene.activationState != UISceneActivationStateForegroundInactive) {
            continue;
        }
        UIWindowScene *windowScene = (UIWindowScene *)scene;
        for (UIWindow *window in windowScene.windows) {
            if (window.isKeyWindow) return window;
        }
        if (windowScene.windows.count > 0) return windowScene.windows.firstObject;
    }
    return nil;
}

static UIViewController *TSVisibleController(UIViewController *controller, int depth) {
    if (!controller || depth > 12) return controller;
    if (controller.presentedViewController && !controller.presentedViewController.isBeingDismissed) {
        return TSVisibleController(controller.presentedViewController, depth + 1);
    }
    if ([controller isKindOfClass:[UINavigationController class]]) {
        UIViewController *visible = [(UINavigationController *)controller visibleViewController];
        if (visible && visible != controller) return TSVisibleController(visible, depth + 1);
    }
    if ([controller isKindOfClass:[UITabBarController class]]) {
        UIViewController *selected = [(UITabBarController *)controller selectedViewController];
        if (selected && selected != controller) return TSVisibleController(selected, depth + 1);
    }
    return controller;
}

UIViewController *TSTopViewController(void) {
    return TSVisibleController(TSKeyWindow().rootViewController, 0);
}

void TSPresentAlert(UIViewController *presenter, NSString *title, NSString *message) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *host = presenter ?: TSTopViewController();
        if (!host) return;
        while (host.presentedViewController && !host.presentedViewController.isBeingDismissed) {
            host = host.presentedViewController;
        }
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                       message:message
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [host presentViewController:alert animated:YES completion:nil];
    });
}

BOOL TSReduceMotion(void) {
    return UIAccessibilityIsReduceMotionEnabled();
}

static BOOL TSHapticsAllowed(void) {
    return TSBool(TSKeyHaptics, YES);
}

static CGFloat TSHapticIntensity(void) {
    float value = TSFloat(TSKeyHapticIntensity, 0.85f);
    if (value < 0.25f) value = 0.25f;
    if (value > 1.f) value = 1.f;
    return value;
}

void TSHapticLight(void) {
    if (!TSHapticsAllowed()) return;
    UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [generator impactOccurredWithIntensity:TSHapticIntensity()];
}

UIFont *TSMappedFont(UIFont *font) {
    if (!font) return nil;
    NSString *choice = [[TSPrefs shared] stringForKey:TSKeyFontChoice];
    if (choice.length == 0 || [choice isEqualToString:@"system"]) return font;
    UIFontDescriptorSystemDesign design = UIFontDescriptorSystemDesignDefault;
    if ([choice isEqualToString:@"rounded"]) design = UIFontDescriptorSystemDesignRounded;
    else if ([choice isEqualToString:@"serif"]) design = UIFontDescriptorSystemDesignSerif;
    else if ([choice isEqualToString:@"mono"]) design = UIFontDescriptorSystemDesignMonospaced;
    else return font;
    UIFontDescriptor *descriptor = [font.fontDescriptor fontDescriptorWithDesign:design];
    if (!descriptor) return font;
    return [UIFont fontWithDescriptor:descriptor size:font.pointSize];
}

void TSHapticSelection(void) {
    if (!TSHapticsAllowed()) return;
    UISelectionFeedbackGenerator *generator = [[UISelectionFeedbackGenerator alloc] init];
    [generator selectionChanged];
}

void TSHapticWarning(void) {
    if (!TSHapticsAllowed()) return;
    UINotificationFeedbackGenerator *generator = [[UINotificationFeedbackGenerator alloc] init];
    [generator notificationOccurred:UINotificationFeedbackTypeWarning];
}

void TSHapticSuccess(void) {
    if (!TSHapticsAllowed()) return;
    UINotificationFeedbackGenerator *generator = [[UINotificationFeedbackGenerator alloc] init];
    [generator notificationOccurred:UINotificationFeedbackTypeSuccess];
}
