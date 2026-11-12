#import "TSKeys.h"

NSString *const TSSuiteName = @"com.tikspice.preferences";
NSNotificationName const TSPrefsChangedNotification = @"com.tikspice.preferences.changed";
NSString *const TSSpiceVersion = @"1.0.1";

NSString *const TSKeyThemePreset = @"theme.preset";
NSString *const TSKeyThemeCustom = @"theme.custom";
NSString *const TSKeyThemeChrome = @"theme.chrome";
NSString *const TSKeyThemeGlobalTint = @"theme.globalTint";
NSString *const TSKeyThemeSurfaces = @"theme.surfaces";

NSString *const TSKeyHideAds = @"hideAds";
NSString *const TSKeyHideLive = @"hideLive";
NSString *const TSKeyHideShop = @"hideShop";
NSString *const TSKeyHideUpload = @"hideUpload";
NSString *const TSKeyHideFriends = @"hideFriends";
NSString *const TSKeyHideInbox = @"hideInbox";
NSString *const TSKeyHideTabLabels = @"hideTabLabels";
NSString *const TSKeyHideSuggested = @"hideSuggested";
NSString *const TSKeyHideFeedTabs = @"hideFeedTabs";
NSString *const TSKeyHideStories = @"hideStories";
NSString *const TSKeyHideMusicTicker = @"hideMusicTicker";
NSString *const TSKeyHideViewCounts = @"hideViewCounts";
NSString *const TSKeyHideLikeCounts = @"hideLikeCounts";
NSString *const TSKeyHideCommentCounts = @"hideCommentCounts";
NSString *const TSKeyHideShareButton = @"hideShareButton";

NSString *const TSKeySpeedEnabled = @"playback.speedEnabled";
NSString *const TSKeyPlaybackSpeed = @"playback.speed";
NSString *const TSKeyLoopVideo = @"playback.loop";
NSString *const TSKeyDisableAutoScroll = @"playback.disableAutoScroll";

NSString *const TSKeyConfirmLike = @"confirm.like";
NSString *const TSKeyConfirmFollow = @"confirm.follow";
NSString *const TSKeyConfirmComment = @"confirm.comment";
NSString *const TSKeyConfirmShare = @"confirm.share";
NSString *const TSKeyDisableDoubleTapLike = @"confirm.disableDoubleTapLike";

NSString *const TSKeyPreferCleanURL = @"download.preferCleanURL";
NSString *const TSKeyRegionEnabled = @"region.enabled";
NSString *const TSKeyRegionCode = @"region.code";

NSString *const TSKeyHaptics = @"entry.haptics";
NSString *const TSKeyLogViewControllers = @"debug.logViewControllers";

NSArray<NSString *> *TSAllPreferenceKeys(void) {
    static NSArray<NSString *> *keys;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        keys = @[
            TSKeyThemePreset, TSKeyThemeCustom, TSKeyThemeChrome, TSKeyThemeGlobalTint, TSKeyThemeSurfaces,
            TSKeyHideAds, TSKeyHideLive, TSKeyHideShop, TSKeyHideUpload, TSKeyHideFriends, TSKeyHideInbox,
            TSKeyHideTabLabels, TSKeyHideSuggested, TSKeyHideFeedTabs, TSKeyHideStories, TSKeyHideMusicTicker,
            TSKeyHideViewCounts, TSKeyHideLikeCounts, TSKeyHideCommentCounts, TSKeyHideShareButton,
            TSKeySpeedEnabled, TSKeyPlaybackSpeed, TSKeyLoopVideo, TSKeyDisableAutoScroll,
            TSKeyConfirmLike, TSKeyConfirmFollow, TSKeyConfirmComment, TSKeyConfirmShare, TSKeyDisableDoubleTapLike,
            TSKeyPreferCleanURL, TSKeyRegionEnabled, TSKeyRegionCode,
            TSKeyHaptics, TSKeyLogViewControllers
        ];
    });
    return keys;
}
