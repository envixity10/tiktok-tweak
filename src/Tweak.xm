#import "Tweak.h"

%ctor {
    NSLog(@"[TikSpice] loaded %@", TSSpiceVersion);
    TSPrivateHooksInstall();
    TSChromeRefresh();
    [TSEntry installRecoveryGesture];
}
