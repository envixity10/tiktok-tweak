#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

FOUNDATION_EXPORT float TSDesiredPlaybackRate(void);
FOUNDATION_EXPORT void TSArmAutoAdvanceBlock(CFTimeInterval duration);
FOUNDATION_EXPORT BOOL TSShouldBlockAutoAdvance(void);
FOUNDATION_EXPORT void TSPlaybackWatch(AVPlayer *player);
