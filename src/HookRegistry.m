#import "HookRegistry.h"
#import "TSKeys.h"

static const TSHookSpec kSpecs[] = {
    // Ads. Forcing the getter off does not always remove the cell; the view
    // scanner also hides "Sponsored" labels. UNVERIFIED against a binary.
    {.ident = "ads.aweme.isAds", .group = "ads", .className = "AWEAwemeModel", .selector = "isAds", .prefKey = "hideAds", .purpose = "Report the post as not an ad", .returnType = 'B', .kind = TSHookKindBoolNO, .unverified = 1},
    {.ident = "ads.aweme.isAd", .group = "ads", .className = "AWEAwemeModel", .selector = "isAd", .prefKey = "hideAds", .purpose = "Report the post as not an ad", .returnType = 'B', .kind = TSHookKindBoolNO, .unverified = 1},
    {.ident = "ads.aweme.isAdvertisement", .group = "ads", .className = "AWEAwemeModel", .selector = "isAdvertisement", .prefKey = "hideAds", .purpose = "Report the post as not an ad", .returnType = 'B', .kind = TSHookKindBoolNO, .unverified = 1},
    {.ident = "ads.base.isAds", .group = "ads", .className = "AWEAwemeBaseModel", .selector = "isAds", .prefKey = "hideAds", .purpose = "Report the post as not an ad", .returnType = 'B', .kind = TSHookKindBoolNO, .unverified = 1},
    {.ident = "ads.ttk.isAds", .group = "ads", .className = "TTKAwemeModel", .selector = "isAds", .prefKey = "hideAds", .purpose = "Report the post as not an ad", .returnType = 'B', .kind = TSHookKindBoolNO, .unverified = 1},

    // Auto-advance. Only zero-argument methods are hooked. An animated
    // variant needs its own trampoline once you confirm the signature.
    {.ident = "feed.table.scrollToNext", .group = "feed", .className = "AWEFeedTableViewController", .selector = "scrollToNext", .prefKey = "playback.disableAutoScroll", .purpose = "Skip automatic advance", .returnType = 'v', .kind = TSHookKindVoidSkip, .unverified = 1},
    {.ident = "feed.table.scrollToNextVideo", .group = "feed", .className = "AWEFeedTableViewController", .selector = "scrollToNextVideo", .prefKey = "playback.disableAutoScroll", .purpose = "Skip automatic advance", .returnType = 'v', .kind = TSHookKindVoidSkip, .unverified = 1},
    {.ident = "feed.table.scrollToNextAweme", .group = "feed", .className = "AWEFeedTableViewController", .selector = "scrollToNextAweme", .prefKey = "playback.disableAutoScroll", .purpose = "Skip automatic advance", .returnType = 'v', .kind = TSHookKindVoidSkip, .unverified = 1},
    {.ident = "feed.table.playNextVideo", .group = "feed", .className = "AWEFeedTableViewController", .selector = "playNextVideo", .prefKey = "playback.disableAutoScroll", .purpose = "Skip automatic advance", .returnType = 'v', .kind = TSHookKindVoidSkip, .unverified = 1},
    {.ident = "feed.detail.scrollToNext", .group = "feed", .className = "AWEAwemeDetailTableViewController", .selector = "scrollToNext", .prefKey = "playback.disableAutoScroll", .purpose = "Skip automatic advance", .returnType = 'v', .kind = TSHookKindVoidSkip, .unverified = 1},
    {.ident = "feed.detail.scrollToNextVideo", .group = "feed", .className = "AWEAwemeDetailTableViewController", .selector = "scrollToNextVideo", .prefKey = "playback.disableAutoScroll", .purpose = "Skip automatic advance", .returnType = 'v', .kind = TSHookKindVoidSkip, .unverified = 1},
    {.ident = "feed.ttk.scrollToNext", .group = "feed", .className = "TTKFeedViewController", .selector = "scrollToNext", .prefKey = "playback.disableAutoScroll", .purpose = "Skip automatic advance", .returnType = 'v', .kind = TSHookKindVoidSkip, .unverified = 1},
    {.ident = "feed.ttk.scrollToNextVideo", .group = "feed", .className = "TTKFeedViewController", .selector = "scrollToNextVideo", .prefKey = "playback.disableAutoScroll", .purpose = "Skip automatic advance", .returnType = 'v', .kind = TSHookKindVoidSkip, .unverified = 1},
    {.ident = "feed.awe.scrollToNextVideo", .group = "feed", .className = "AWEFeedViewController", .selector = "scrollToNextVideo", .prefKey = "playback.disableAutoScroll", .purpose = "Skip automatic advance", .returnType = 'v', .kind = TSHookKindVoidSkip, .unverified = 1},
    {.ident = "feed.root.scrollToNextVideo", .group = "feed", .className = "AWEFeedRootViewController", .selector = "scrollToNextVideo", .prefKey = "playback.disableAutoScroll", .purpose = "Skip automatic advance", .returnType = 'v', .kind = TSHookKindVoidSkip, .unverified = 1},

    // Download getters. The replacement returns the play-address object only
    // when it is the same class as the original download object.
    {.ident = "video.awe.downloadAddr", .group = "video", .className = "AWEVideoModel", .selector = "downloadAddr", .swapSelector = "playAddr", .prefKey = "download.preferCleanURL", .purpose = "Prefer the playback address", .returnType = '@', .kind = TSHookKindSwapPlay, .unverified = 1},
    {.ident = "video.awe.downloadURL", .group = "video", .className = "AWEVideoModel", .selector = "downloadURL", .swapSelector = "playURL", .prefKey = "download.preferCleanURL", .purpose = "Prefer the playback URL", .returnType = '@', .kind = TSHookKindSwapPlay, .unverified = 1},
    {.ident = "video.aweme.downloadAddr", .group = "video", .className = "AWEAwemeVideoModel", .selector = "downloadAddr", .swapSelector = "playAddr", .prefKey = "download.preferCleanURL", .purpose = "Prefer the playback address", .returnType = '@', .kind = TSHookKindSwapPlay, .unverified = 1},
    {.ident = "video.ttk.downloadAddr", .group = "video", .className = "TTKVideoModel", .selector = "downloadAddr", .swapSelector = "playAddr", .prefKey = "download.preferCleanURL", .purpose = "Prefer the playback address", .returnType = '@', .kind = TSHookKindSwapPlay, .unverified = 1},

    // Region. The hook replaces the value only when the original return is an NSString.
    {.ident = "region.manager.current", .group = "region", .className = "AWERegionManager", .selector = "currentRegion", .prefKey = "region.enabled", .purpose = "Replace a string region code", .returnType = '@', .kind = TSHookKindRegion, .unverified = 1},
    {.ident = "region.manager.code", .group = "region", .className = "AWERegionManager", .selector = "regionCode", .prefKey = "region.enabled", .purpose = "Replace a string region code", .returnType = '@', .kind = TSHookKindRegion, .unverified = 1},
    {.ident = "region.ttk.current", .group = "region", .className = "TTKRegionManager", .selector = "currentRegion", .prefKey = "region.enabled", .purpose = "Replace a string region code", .returnType = '@', .kind = TSHookKindRegion, .unverified = 1},
    {.ident = "region.service.current", .group = "region", .className = "AWERegionService", .selector = "currentRegion", .prefKey = "region.enabled", .purpose = "Replace a string region code", .returnType = '@', .kind = TSHookKindRegion, .unverified = 1},
    {.ident = "region.user.carrier", .group = "region", .className = "AWEUserCountryService", .selector = "carrierRegionCode", .prefKey = "region.enabled", .purpose = "Replace a string region code", .returnType = '@', .kind = TSHookKindRegion, .unverified = 1},

    // Probe-only names. The view scanner uses these class names when the matching toggle is on.
    {.ident = "live.entrance", .group = "live", .className = "AWELiveEntranceView", .purpose = "LIVE entry", .kind = TSHookKindProbe, .unverified = 1},
    {.ident = "live.feedEntrance", .group = "live", .className = "AWELiveFeedEntranceView", .purpose = "LIVE feed entry", .kind = TSHookKindProbe, .unverified = 1},
    {.ident = "live.ttkEntrance", .group = "live", .className = "TTKLiveEntranceView", .purpose = "LIVE entry", .kind = TSHookKindProbe, .unverified = 1},
    {.ident = "live.skylight", .group = "live", .className = "AWELiveSkylightView", .purpose = "Top LIVE tray", .kind = TSHookKindProbe, .unverified = 1},
    {.ident = "live.ttkSkylight", .group = "live", .className = "TTKLiveSkylightCollectionView", .purpose = "Top LIVE tray", .kind = TSHookKindProbe, .unverified = 1},

    {.ident = "shop.tab", .group = "shop", .className = "TTKShopTabViewController", .purpose = "Shop tab", .kind = TSHookKindProbe, .unverified = 1},
    {.ident = "shop.mall", .group = "shop", .className = "TTKMallViewController", .purpose = "Shop mall", .kind = TSHookKindProbe, .unverified = 1},
    {.ident = "shop.entrance", .group = "shop", .className = "AWEShopEntranceView", .purpose = "Shop entrance", .kind = TSHookKindProbe, .unverified = 1},

    {.ident = "upload.plus", .group = "upload", .className = "AWETabBarPlusButton", .purpose = "Center upload button", .kind = TSHookKindProbe, .unverified = 1},
    {.ident = "upload.ttkPlus", .group = "upload", .className = "TTKTabBarPlusButton", .purpose = "Center upload button", .kind = TSHookKindProbe, .unverified = 1},
    {.ident = "upload.post", .group = "upload", .className = "AWEPostTabBarButton", .purpose = "Center upload button", .kind = TSHookKindProbe, .unverified = 1},

    {.ident = "story.tray", .group = "story", .className = "AWEStoryTrayView", .purpose = "Story tray", .kind = TSHookKindProbe, .unverified = 1},
    {.ident = "story.ttk", .group = "story", .className = "TTKStoryTrayView", .purpose = "Story tray", .kind = TSHookKindProbe, .unverified = 1},

    {.ident = "music.info", .group = "music", .className = "AWEMusicInfoView", .purpose = "Music ticker", .kind = TSHookKindProbe, .unverified = 1},
    {.ident = "music.ttk", .group = "music", .className = "TTKMusicInfoView", .purpose = "Music ticker", .kind = TSHookKindProbe, .unverified = 1},

    // settingsHome: exact class of the root "Settings and privacy" page.
    // Subclasses are not treated as a match. Add the class shown in Hook status.
    {.ident = "settings.table", .group = "settingsHome", .className = "AWESettingsTableViewController", .purpose = "Settings and privacy", .kind = TSHookKindProbe, .unverified = 1},
    {.ident = "settings.view", .group = "settingsHome", .className = "AWESettingsViewController", .purpose = "Settings and privacy", .kind = TSHookKindProbe, .unverified = 1},
    {.ident = "settings.base", .group = "settingsHome", .className = "AWESettingBaseViewController", .purpose = "Settings and privacy", .kind = TSHookKindProbe, .unverified = 1},
    {.ident = "settings.list", .group = "settingsHome", .className = "AWESettingTableViewController", .purpose = "Settings and privacy", .kind = TSHookKindProbe, .unverified = 1},
    {.ident = "settings.ttk", .group = "settingsHome", .className = "TTKSettingsViewController", .purpose = "Settings and privacy", .kind = TSHookKindProbe, .unverified = 1},
    {.ident = "settings.ttkHome", .group = "settingsHome", .className = "TTKSettingHomeViewController", .purpose = "Settings and privacy", .kind = TSHookKindProbe, .unverified = 1},
    {.ident = "settings.ttkList", .group = "settingsHome", .className = "TTKSettingListViewController", .purpose = "Settings and privacy", .kind = TSHookKindProbe, .unverified = 1},
    {.ident = "settings.ttkBase", .group = "settingsHome", .className = "TTKSettingBaseViewController", .purpose = "Settings and privacy", .kind = TSHookKindProbe, .unverified = 1},
    {.ident = "settings.ttkPage", .group = "settingsHome", .className = "TTKSettingsHomeViewController", .purpose = "Settings and privacy", .kind = TSHookKindProbe, .unverified = 1},

    // profileMenu: hamburger sheet. Used only when no settingsHome class exists.
    {.ident = "menu.ttk", .group = "profileMenu", .className = "TTKProfileMenuViewController", .purpose = "Profile menu sheet", .kind = TSHookKindProbe, .unverified = 1},
    {.ident = "menu.ttkSheet", .group = "profileMenu", .className = "TTKProfileMenuSheetViewController", .purpose = "Profile menu sheet", .kind = TSHookKindProbe, .unverified = 1},
    {.ident = "menu.awe", .group = "profileMenu", .className = "AWEProfileMenuViewController", .purpose = "Profile menu sheet", .kind = TSHookKindProbe, .unverified = 1},
    {.ident = "menu.aweSide", .group = "profileMenu", .className = "AWEProfileSideMenuViewController", .purpose = "Profile menu sheet", .kind = TSHookKindProbe, .unverified = 1},
    {.ident = "menu.ttkSide", .group = "profileMenu", .className = "TTKProfileSideMenuViewController", .purpose = "Profile menu sheet", .kind = TSHookKindProbe, .unverified = 1},
    {.ident = "menu.home", .group = "profileMenu", .className = "TTKUserHomeMenuViewController", .purpose = "Profile menu sheet", .kind = TSHookKindProbe, .unverified = 1},
    {.ident = "menu.slide", .group = "profileMenu", .className = "AWEProfileSlidingViewController", .purpose = "Profile menu sheet", .kind = TSHookKindProbe, .unverified = 1},

    {.ident = "profile.awe", .group = "profile", .className = "AWEProfileViewController", .purpose = "Profile screen", .kind = TSHookKindProbe, .unverified = 1},
    {.ident = "profile.ttk", .group = "profile", .className = "TTKProfileViewController", .purpose = "Profile screen", .kind = TSHookKindProbe, .unverified = 1},
    {.ident = "profile.home", .group = "profile", .className = "AWEUserHomeViewController", .purpose = "Profile screen", .kind = TSHookKindProbe, .unverified = 1},
    {.ident = "profile.header", .group = "profile", .className = "AWEProfileHeaderViewController", .purpose = "Profile header", .kind = TSHookKindProbe, .unverified = 1},

    {.ident = "interaction.awe", .group = "interaction", .className = "AWEAwemePlayInteractionViewController", .purpose = "Right-rail buttons", .kind = TSHookKindProbe, .unverified = 1},
    {.ident = "interaction.ttk", .group = "interaction", .className = "TTKFeedInteractionViewController", .purpose = "Right-rail buttons", .kind = TSHookKindProbe, .unverified = 1},

    {.ident = "player.aweme", .group = "player", .className = "AWEAwemePlayVideoViewController", .purpose = "Video player", .kind = TSHookKindProbe, .unverified = 1},
    {.ident = "player.play", .group = "player", .className = "AWEPlayVideoViewController", .purpose = "Video player", .kind = TSHookKindProbe, .unverified = 1},
    {.ident = "player.ttk", .group = "player", .className = "TTKFeedPlayerController", .purpose = "Video player", .kind = TSHookKindProbe, .unverified = 1},
};

const TSHookSpec *TSHookSpecs(NSUInteger *count) {
    if (count) *count = sizeof(kSpecs) / sizeof(kSpecs[0]);
    return kSpecs;
}

@implementation TSHookResult
@end

@implementation TSHookRegistry

static NSArray<TSHookResult *> *ts_results;
static NSMutableArray<NSString *> *ts_recent;

+ (void)replaceResults:(NSArray<TSHookResult *> *)results {
    ts_results = [results copy] ?: @[];
}

+ (NSArray<TSHookResult *> *)results {
    return ts_results ?: @[];
}

+ (NSArray<NSString *> *)classNamesInGroup:(NSString *)group {
    NSMutableOrderedSet *names = [NSMutableOrderedSet orderedSet];
    NSUInteger count = 0;
    const TSHookSpec *specs = TSHookSpecs(&count);
    for (NSUInteger i = 0; i < count; i++) {
        if (strcmp(specs[i].group, group.UTF8String) != 0) continue;
        if (specs[i].className) [names addObject:@(specs[i].className)];
    }
    return names.array;
}

+ (BOOL)class:(Class)cls implementsSelector:(SEL)selector {
    if (!cls || !selector) return NO;
    unsigned int count = 0;
    Method *list = class_copyMethodList(cls, &count);
    BOOL found = NO;
    for (unsigned int i = 0; i < count; i++) {
        if (method_getName(list[i]) == selector) {
            found = YES;
            break;
        }
    }
    free(list);
    return found;
}

+ (BOOL)className:(NSString *)className inGroup:(NSString *)group {
    if (className.length == 0) return NO;
    return [[self classNamesInGroup:group] containsObject:className];
}

+ (BOOL)groupHasLoadedClass:(NSString *)group {
    for (NSString *name in [self classNamesInGroup:group]) {
        if (objc_getClass(name.UTF8String)) return YES;
    }
    return NO;
}

+ (void)noteViewControllerClass:(NSString *)className {
    if (className.length == 0) return;
    if ([className hasPrefix:@"TS"] || [className hasPrefix:@"UI"] || [className hasPrefix:@"NS"] || [className hasPrefix:@"_UI"]) return;
    if (!ts_recent) ts_recent = [NSMutableArray array];
    [ts_recent removeObject:className];
    [ts_recent insertObject:className atIndex:0];
    while (ts_recent.count > 40) [ts_recent removeLastObject];
}

+ (NSArray<NSString *> *)recentViewControllerNames {
    return [ts_recent copy] ?: @[];
}

+ (NSString *)summaryForGroup:(NSString *)group {
    NSInteger present = 0, hooked = 0, total = 0;
    for (TSHookResult *result in [self results]) {
        if (![result.group isEqualToString:group]) continue;
        total++;
        if (result.classPresent) present++;
        if (result.hooked) hooked++;
    }
    if (total == 0) return @"No registry entries for this group.";
    if (hooked > 0) return [NSString stringWithFormat:@"%ld matching method%@ hooked in this process.", (long)hooked, hooked == 1 ? @"" : @"s"];
    if (present > 0) return [NSString stringWithFormat:@"%ld class%@ present, but the selector was not hooked.", (long)present, present == 1 ? @"" : @"es"];
    return @"No class from this group is in the process. On-screen fallbacks still run.";
}

@end
