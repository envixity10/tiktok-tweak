#import "Tweak.h"

%ctor {
    NSLog(@"[TikSpice] loaded %@", TSSpiceVersion);
    TSPrivateHooksInstall();
    TSChromeRefresh();
    [TSFloater install];
}
