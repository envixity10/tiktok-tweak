#import "Scanner.h"
#import "Prefs.h"
#import "Owned.h"
#import "HookRegistry.h"
#import "UIUtil.h"
#import <objc/runtime.h>

// Text and class-name rules for chrome the app draws with ordinary UIKit.
// Class fragments are unverified guesses plus names from HookRegistry groups.
// A rule hides a view only when every filled-in column matches.
typedef struct {
    const char *prefKey;
    const char *classContains;
    const char *textEquals;
    const char *textContains;
    const char *labelContains;
    int shortText;
    int hideTabAncestor;
} TSScanRule;

static const TSScanRule kRules[] = {
    {"hideAds", "AdOverlay", NULL, NULL, NULL, 0, 0},
    {"hideAds", "Sponsored", NULL, NULL, NULL, 0, 0},
    {"hideAds", NULL, "Sponsored", NULL, NULL, 1, 0},
    {"hideAds", NULL, "Advertisement", NULL, NULL, 1, 0},
    {"hideAds", NULL, NULL, "Sponsored", NULL, 1, 0},
    {"hideAds", NULL, NULL, "Paid partnership", NULL, 1, 0},
    {"hideLive", "LiveEntrance", NULL, NULL, NULL, 0, 0},
    {"hideLive", "LiveSkylight", NULL, NULL, NULL, 0, 0},
    {"hideLive", "LiveTag", NULL, NULL, NULL, 0, 0},
    {"hideLive", NULL, "LIVE", NULL, NULL, 1, 0},
    {"hideShop", "ShopTab", NULL, NULL, NULL, 0, 0},
    {"hideShop", "ShopEntrance", NULL, NULL, NULL, 0, 0},
    {"hideShop", NULL, "Shop", NULL, NULL, 1, 1},
    {"hideShop", NULL, "TikTok Shop", NULL, NULL, 1, 1},
    {"hideFriends", NULL, "Friends", NULL, NULL, 1, 1},
    {"hideFriends", NULL, "Now", NULL, NULL, 1, 1},
    {"hideInbox", NULL, "Inbox", NULL, NULL, 1, 1},
    {"hideUpload", "PlusButton", NULL, NULL, NULL, 0, 0},
    {"hideUpload", "TabBarPlus", NULL, NULL, NULL, 0, 0},
    {"hideStories", "StoryTray", NULL, NULL, NULL, 0, 0},
    {"hideSuggested", NULL, "Suggested accounts", NULL, NULL, 1, 0},
    {"hideSuggested", NULL, NULL, "Suggested accounts", NULL, 1, 0},
    {"hideFeedTabs", NULL, "For You", NULL, NULL, 1, 0},
    {"hideFeedTabs", NULL, "Following", NULL, NULL, 1, 0},
    {"hideViewCounts", NULL, NULL, "views", NULL, 1, 0},
    {"hideViewCounts", NULL, NULL, NULL, "views", 1, 0},
    {"hideLikeCounts", NULL, NULL, "likes", NULL, 1, 0},
    {"hideLikeCounts", NULL, NULL, NULL, "likes", 1, 0},
    {"hideCommentCounts", NULL, NULL, "comments", NULL, 1, 0},
    {"hideShareButton", NULL, NULL, NULL, "Share", 1, 0},
    {"hideMusicTicker", "MusicInfo", NULL, NULL, NULL, 0, 0},
    {"hideMusicTicker", "MusicCover", NULL, NULL, NULL, 0, 0},
};

static const void *TSHiddenMark = &TSHiddenMark;
static CFTimeInterval ts_lastScan = 0;
static BOOL ts_needsRestore = NO;

static NSString *TSViewText(UIView *view) {
    if ([view isKindOfClass:[UILabel class]]) return ((UILabel *)view).text ?: @"";
    if ([view isKindOfClass:[UIButton class]]) return [(UIButton *)view currentTitle] ?: @"";
    return @"";
}

static BOOL TSContainsFold(NSString *haystack, const char *needle) {
    if (!needle || haystack.length == 0) return NO;
    return [haystack rangeOfString:@(needle) options:NSCaseInsensitiveSearch].location != NSNotFound;
}

static BOOL TSEqualsFold(NSString *haystack, const char *needle) {
    if (!needle) return NO;
    return [haystack caseInsensitiveCompare:@(needle)] == NSOrderedSame;
}

static BOOL TSRuleEnabled(const TSScanRule *rule, NSDictionary<NSString *, NSNumber *> *flags) {
    return flags[@(rule->prefKey)].boolValue;
}

static BOOL TSTextIsShort(UIView *view, NSString *text, NSString *label) {
    if (text.length > 24 || label.length > 32) return NO;
    CGSize size = view.bounds.size;
    return size.width <= 280 && size.height <= 80;
}

static BOOL TSRuleMatches(UIView *view, NSString *className, NSString *text, NSString *label, const TSScanRule *rule) {
    if (rule->classContains && ![className containsString:@(rule->classContains)]) return NO;
    if (rule->textEquals && !TSEqualsFold(text, rule->textEquals)) return NO;
    if (rule->textContains && !TSContainsFold(text, rule->textContains)) return NO;
    if (rule->labelContains && !TSContainsFold(label, rule->labelContains)) return NO;
    if (!rule->classContains && !rule->textEquals && !rule->textContains && !rule->labelContains) return NO;
    if ((rule->textEquals || rule->textContains || rule->labelContains) && rule->shortText && !TSTextIsShort(view, text, label)) return NO;
    return YES;
}

static UIView *TSTabButtonAncestor(UIView *view) {
    for (UIView *cursor = view; cursor; cursor = cursor.superview) {
        NSString *name = NSStringFromClass(cursor.class);
        if ([name containsString:@"TabBarButton"]) return cursor;
        if ([name isEqualToString:@"UITabBar"] || [name containsString:@"UITabBar"]) {
            if (![name containsString:@"Button"]) return nil;
        }
    }
    return nil;
}

static BOOL TSIsHuge(UIView *view) {
    CGSize screen = UIScreen.mainScreen.bounds.size;
    return view.bounds.size.width > screen.width * 0.82 && view.bounds.size.height > screen.height * 0.28;
}

static BOOL TSNameInSet(NSString *className, NSSet<NSString *> *names) {
    return className.length > 0 && [names containsObject:className];
}

static void TSWalk(UIView *view, NSDictionary<NSString *, NSNumber *> *flags, NSDictionary<NSString *, NSSet<NSString *> *> *groups, NSInteger depth, NSInteger *visits, BOOL *stillHidden) {
    if (!view || depth > 28 || *visits > 4500) return;
    (*visits)++;
    if (TSIsOwnedView(view)) return;

    NSString *className = NSStringFromClass(view.class);
    NSString *text = TSViewText(view);
    NSString *label = view.accessibilityLabel ?: @"";
    BOOL hide = NO;
    BOOL tabOnly = NO;

    if (flags[TSKeyHideLive].boolValue && (TSNameInSet(className, groups[@"live"]) || [className containsString:@"LiveEntrance"] || [className containsString:@"LiveSkylight"])) hide = YES;
    if (flags[TSKeyHideShop].boolValue && TSNameInSet(className, groups[@"shop"])) hide = YES;
    if (flags[TSKeyHideUpload].boolValue && (TSNameInSet(className, groups[@"upload"]) || [className containsString:@"PlusButton"] || [className containsString:@"TabBarPlus"])) hide = YES;
    if (flags[TSKeyHideStories].boolValue && (TSNameInSet(className, groups[@"story"]) || [className containsString:@"StoryTray"])) hide = YES;
    if (flags[TSKeyHideMusicTicker].boolValue && (TSNameInSet(className, groups[@"music"]) || [className containsString:@"MusicInfo"])) hide = YES;

    const NSUInteger ruleCount = sizeof(kRules) / sizeof(kRules[0]);
    for (NSUInteger i = 0; i < ruleCount && !hide; i++) {
        const TSScanRule *rule = &kRules[i];
        if (!TSRuleEnabled(rule, flags)) continue;
        if (!TSRuleMatches(view, className, text, label, rule)) continue;
        hide = YES;
        tabOnly = rule->hideTabAncestor;
    }
    if (hide && TSEqualsFold(text, "Following") && [className containsString:@"Follow"]) hide = NO;

    UIView *target = view;
    if (hide && tabOnly) {
        UIView *tab = TSTabButtonAncestor(view);
        if (tab) target = tab;
        else if ([className containsString:@"Tab"] || [className containsString:@"Button"]) target = view;
        else hide = NO;
    }
    if (hide && TSIsHuge(target)) hide = NO;

    NSNumber *mark = objc_getAssociatedObject(target, TSHiddenMark);
    if (hide) {
        target.hidden = YES;
        objc_setAssociatedObject(target, TSHiddenMark, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        *stillHidden = YES;
    } else if (mark.boolValue) {
        target.hidden = NO;
        objc_setAssociatedObject(target, TSHiddenMark, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    for (UIView *subview in view.subviews) {
        TSWalk(subview, flags, groups, depth + 1, visits, stillHidden);
    }
}

static NSDictionary<NSString *, NSNumber *> *TSHideFlags(BOOL *any) {
    NSArray<NSString *> *keys = @[
        TSKeyHideAds, TSKeyHideLive, TSKeyHideShop, TSKeyHideUpload, TSKeyHideFriends, TSKeyHideInbox,
        TSKeyHideSuggested, TSKeyHideFeedTabs, TSKeyHideStories, TSKeyHideMusicTicker, TSKeyHideViewCounts,
        TSKeyHideLikeCounts, TSKeyHideCommentCounts, TSKeyHideShareButton
    ];
    NSMutableDictionary *flags = [NSMutableDictionary dictionary];
    BOOL enabled = NO;
    for (NSString *key in keys) {
        BOOL value = TSBool(key, NO);
        flags[key] = @(value);
        enabled = enabled || value;
    }
    if (any) *any = enabled;
    return flags;
}

void TSScannerScanNow(void) {
    BOOL any = NO;
    NSDictionary *flags = TSHideFlags(&any);
    if (!any && !ts_needsRestore) return;
    NSDictionary *groups = @{
        @"live": [NSSet setWithArray:[TSHookRegistry classNamesInGroup:@"live"]],
        @"shop": [NSSet setWithArray:[TSHookRegistry classNamesInGroup:@"shop"]],
        @"upload": [NSSet setWithArray:[TSHookRegistry classNamesInGroup:@"upload"]],
        @"story": [NSSet setWithArray:[TSHookRegistry classNamesInGroup:@"story"]],
        @"music": [NSSet setWithArray:[TSHookRegistry classNamesInGroup:@"music"]],
    };
    BOOL stillHidden = NO;
    NSInteger visits = 0;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;
        for (UIWindow *window in ((UIWindowScene *)scene).windows) {
            TSWalk(window, flags, groups, 0, &visits, &stillHidden);
        }
    }
    ts_needsRestore = stillHidden;
    ts_lastScan = CACurrentMediaTime();
}

@interface TSScannerBootstrap : NSObject
@end

@implementation TSScannerBootstrap

+ (void)load {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(prefsChanged:) name:TSPrefsChangedNotification object:nil];
}

+ (void)prefsChanged:(NSNotification *)note {
    NSString *key = note.userInfo[@"key"];
    if (key && ![key hasPrefix:@"hide"]) return;
    ts_lastScan = 0;
    TSScannerScanNow();
}

@end

void TSScannerScanIfNeeded(void) {
    if (CACurrentMediaTime() - ts_lastScan < 0.45) return;
    TSScannerScanNow();
}
