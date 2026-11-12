#import "Chrome.h"
#import "Theme.h"
#import "Prefs.h"
#import "Owned.h"
#import "UIUtil.h"
#import <AVFoundation/AVFoundation.h>

static BOOL TSLayerHostsPlayer(CALayer *layer) {
    if ([layer isKindOfClass:[AVPlayerLayer class]]) return YES;
    for (CALayer *sublayer in layer.sublayers) {
        if ([sublayer isKindOfClass:[AVPlayerLayer class]]) return YES;
    }
    return NO;
}

static UINavigationBarAppearance *TSNavigationAppearance(TSTheme *theme) {
    UINavigationBarAppearance *appearance = [UINavigationBarAppearance new];
    [appearance configureWithOpaqueBackground];
    appearance.backgroundColor = theme.surface;
    appearance.shadowColor = theme.separator;
    appearance.titleTextAttributes = @{NSForegroundColorAttributeName: theme.textPrimary};
    appearance.largeTitleTextAttributes = @{NSForegroundColorAttributeName: theme.textPrimary};
    return appearance;
}

static UITabBarAppearance *TSTabAppearance(TSTheme *theme) {
    UITabBarAppearance *appearance = [UITabBarAppearance new];
    [appearance configureWithOpaqueBackground];
    appearance.backgroundColor = theme.surface;
    appearance.shadowColor = theme.separator;
    NSDictionary *selected = @{NSForegroundColorAttributeName: theme.accent};
    NSDictionary *normal = @{NSForegroundColorAttributeName: theme.textSecondary};
    appearance.stackedLayoutAppearance.selected.iconColor = theme.accent;
    appearance.stackedLayoutAppearance.selected.titleTextAttributes = selected;
    appearance.stackedLayoutAppearance.normal.iconColor = theme.textSecondary;
    appearance.stackedLayoutAppearance.normal.titleTextAttributes = normal;
    appearance.inlineLayoutAppearance.selected.iconColor = theme.accent;
    appearance.inlineLayoutAppearance.selected.titleTextAttributes = selected;
    appearance.inlineLayoutAppearance.normal.iconColor = theme.textSecondary;
    appearance.inlineLayoutAppearance.normal.titleTextAttributes = normal;
    return appearance;
}

static void TSPaintView(UIView *view, TSTheme *theme, BOOL chrome, BOOL surfaces, NSInteger depth) {
    if (!view || depth > 28 || TSIsOwnedView(view)) return;
    if (TSLayerHostsPlayer(view.layer)) return;

    if (chrome && [view isKindOfClass:[UINavigationBar class]]) {
        UINavigationBar *bar = (UINavigationBar *)view;
        UINavigationBarAppearance *appearance = TSNavigationAppearance(theme);
        bar.standardAppearance = appearance;
        bar.scrollEdgeAppearance = appearance;
        bar.compactAppearance = appearance;
        bar.tintColor = theme.accent;
        bar.barTintColor = theme.surface;
    } else if (chrome && [view isKindOfClass:[UITabBar class]]) {
        UITabBar *bar = (UITabBar *)view;
        UITabBarAppearance *appearance = TSTabAppearance(theme);
        bar.standardAppearance = appearance;
        bar.scrollEdgeAppearance = appearance;
        bar.tintColor = theme.accent;
        bar.unselectedItemTintColor = theme.textSecondary;
        bar.barTintColor = theme.surface;
    } else if (surfaces && ([view isKindOfClass:[UITableView class]] || [view isKindOfClass:[UICollectionView class]])) {
        view.backgroundColor = theme.background;
    }

    for (UIView *subview in view.subviews) {
        TSPaintView(subview, theme, chrome, surfaces, depth + 1);
    }
}

@interface TSChromeBootstrap : NSObject
@end

@implementation TSChromeBootstrap

+ (void)load {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(prefsChanged:) name:TSPrefsChangedNotification object:nil];
}

+ (void)prefsChanged:(NSNotification *)note {
    NSString *key = note.userInfo[@"key"];
    if (!key || [key hasPrefix:@"theme."]) TSChromeRefresh();
}

@end

void TSChromeRefresh(void) {
    BOOL chrome = TSBool(TSKeyThemeChrome, NO);
    BOOL tint = TSBool(TSKeyThemeGlobalTint, NO);
    BOOL surfaces = TSBool(TSKeyThemeSurfaces, NO);
    if (!chrome && !tint && !surfaces) return;

    TSTheme *theme = [TSTheme current];
    if (chrome) {
        UINavigationBarAppearance *navigation = TSNavigationAppearance(theme);
        UINavigationBar *navigationProxy = [UINavigationBar appearance];
        navigationProxy.standardAppearance = navigation;
        navigationProxy.scrollEdgeAppearance = navigation;
        navigationProxy.compactAppearance = navigation;
        navigationProxy.tintColor = theme.accent;
        UITabBarAppearance *tab = TSTabAppearance(theme);
        UITabBar *tabProxy = [UITabBar appearance];
        tabProxy.standardAppearance = tab;
        tabProxy.scrollEdgeAppearance = tab;
        tabProxy.tintColor = theme.accent;
        tabProxy.unselectedItemTintColor = theme.textSecondary;
    }
    if (tint) {
        [UISwitch appearance].onTintColor = theme.accent;
        [UISegmentedControl appearance].selectedSegmentTintColor = theme.accent;
    }

    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) continue;
        UIWindowScene *windowScene = (UIWindowScene *)scene;
        for (UIWindow *window in windowScene.windows) {
            if (tint) window.tintColor = theme.accent;
            if (chrome || surfaces) TSPaintView(window, theme, chrome, surfaces, 0);
        }
    }
}
