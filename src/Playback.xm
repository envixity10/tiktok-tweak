#import "Tweak.h"

%hook AVPlayer

- (void)setRate:(float)rate {
    float want = TSDesiredPlaybackRate();
    if (want > 0.f && rate > 0.01f && fabsf(rate - want) > 0.02f) {
        %orig(want);
    } else {
        %orig;
    }
    TSPlaybackWatch(self);
}

- (void)play {
    %orig;
    float want = TSDesiredPlaybackRate();
    if (want > 0.f && self.rate > 0.01f) self.rate = want;
    TSPlaybackWatch(self);
}

- (void)playImmediatelyAtRate:(float)rate {
    float want = TSDesiredPlaybackRate();
    if (want > 0.f) rate = want;
    %orig(rate);
    TSPlaybackWatch(self);
}

- (void)setRate:(float)rate time:(CMTime)itemTime atHostTime:(CMTime)hostClockTime {
    float want = TSDesiredPlaybackRate();
    if (want > 0.f && rate > 0.01f) rate = want;
    %orig(rate, itemTime, hostClockTime);
    TSPlaybackWatch(self);
}

- (void)replaceCurrentItemWithPlayerItem:(AVPlayerItem *)item {
    %orig;
    TSPlaybackWatch(self);
}

%end
