#import <UIKit/UIKit.h>

FOUNDATION_EXPORT UIWindow *TSKeyWindow(void);
FOUNDATION_EXPORT UIViewController *TSTopViewController(void);
FOUNDATION_EXPORT void TSPresentAlert(UIViewController *presenter, NSString *title, NSString *message);
FOUNDATION_EXPORT void TSHapticLight(void);
FOUNDATION_EXPORT void TSHapticSelection(void);
FOUNDATION_EXPORT void TSHapticWarning(void);
FOUNDATION_EXPORT void TSHapticSuccess(void);
FOUNDATION_EXPORT BOOL TSReduceMotion(void);
