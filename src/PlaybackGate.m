#import "PlaybackGate.h"
#import "Prefs.h"
#import <objc/runtime.h>

static CFTimeInterval ts_blockUntil = 0;

float TSDesiredPlaybackRate(void) {
    if (!TSBool(TSKeySpeedEnabled, NO)) return 0.f;
    float rate = TSFloat(TSKeyPlaybackSpeed, 1.f);
    if (rate < 0.5f) rate = 0.5f;
    if (rate > 3.f) rate = 3.f;
    if (fabsf(rate - 1.f) < 0.02f) return 0.f;
    return rate;
}

void TSArmAutoAdvanceBlock(CFTimeInterval duration) {
    ts_blockUntil = CFAbsoluteTimeGetCurrent() + duration;
}

BOOL TSShouldBlockAutoAdvance(void) {
    return CFAbsoluteTimeGetCurrent() < ts_blockUntil;
}

@interface TSEndWatcher : NSObject
@property (nonatomic, weak) AVPlayer *player;
@property (nonatomic, weak) AVPlayerItem *item;
@end

@implementation TSEndWatcher

- (void)ended:(NSNotification *)note {
    AVPlayer *player = self.player;
    AVPlayerItem *item = note.object;
    if (!player || ![item isKindOfClass:[AVPlayerItem class]]) return;
    BOOL loop = TSBool(TSKeyLoopVideo, NO);
    BOOL hold = TSBool(TSKeyDisableAutoScroll, NO);
    if (!loop && !hold) return;
    Float64 seconds = CMTimeGetSeconds(item.duration);
    if (isnan(seconds) || seconds < 1.5) return;
    TSArmAutoAdvanceBlock(0.6);
    if (!loop) return;
    __weak AVPlayer *weakPlayer = player;
    [item seekToTime:kCMTimeZero toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero completionHandler:^(BOOL finished) {
        AVPlayer *strongPlayer = weakPlayer;
        if (!strongPlayer || !finished) return;
        float want = TSDesiredPlaybackRate();
        if (want > 0.f) [strongPlayer playImmediatelyAtRate:want];
        else [strongPlayer play];
    }];
}

@end

void TSPlaybackWatch(AVPlayer *player) {
    if (![player isKindOfClass:[AVPlayer class]]) return;
    TSEndWatcher *watcher = objc_getAssociatedObject(player, @selector(ts_endWatcher));
    if (!watcher) {
        watcher = [TSEndWatcher new];
        watcher.player = player;
        objc_setAssociatedObject(player, @selector(ts_endWatcher), watcher, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    AVPlayerItem *item = player.currentItem;
    if (watcher.item == item) return;
    if (watcher.item) {
        [[NSNotificationCenter defaultCenter] removeObserver:watcher
                                                        name:AVPlayerItemDidPlayToEndTimeNotification
                                                      object:watcher.item];
    }
    watcher.item = item;
    if (!item) return;
    [[NSNotificationCenter defaultCenter] addObserver:watcher
                                             selector:@selector(ended:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:item];
}
