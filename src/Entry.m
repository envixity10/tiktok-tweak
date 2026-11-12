#import "Entry.h"
#import "HookRegistry.h"
#import "SettingsUI.h"
#import "Owned.h"
#import "UIUtil.h"
#import <objc/runtime.h>

static NSString *const TSEntryCellID = @"TikSpiceEntry";

#pragma mark - Table proxy

@interface TSTableProxy : NSObject <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, weak) id dataSource;
@property (nonatomic, weak) id delegateSource;
@property (nonatomic, weak) UIViewController *host;
@end

@implementation TSTableProxy

- (NSIndexPath *)mappedPath:(NSIndexPath *)path {
    return [NSIndexPath indexPathForRow:path.row inSection:path.section - 1];
}

- (BOOL)isEntryPath:(NSIndexPath *)path {
    return path.section == 0;
}

- (BOOL)respondsToSelector:(SEL)selector {
    if (selector == @selector(numberOfSectionsInTableView:) ||
        selector == @selector(tableView:numberOfRowsInSection:) ||
        selector == @selector(tableView:cellForRowAtIndexPath:) ||
        selector == @selector(tableView:didSelectRowAtIndexPath:) ||
        selector == @selector(tableView:willDisplayCell:forRowAtIndexPath:)) {
        return YES;
    }
    if ([self dataSelector:selector] && [self.dataSource respondsToSelector:selector]) return YES;
    if ([self delegateSelector:selector] && [self.delegateSource respondsToSelector:selector]) return YES;
    return NO;
}

- (BOOL)dataSelector:(SEL)selector {
    return selector == @selector(tableView:titleForHeaderInSection:) ||
           selector == @selector(tableView:titleForFooterInSection:) ||
           selector == @selector(tableView:canEditRowAtIndexPath:) ||
           selector == @selector(tableView:canMoveRowAtIndexPath:);
}

- (BOOL)delegateSelector:(SEL)selector {
    return selector == @selector(tableView:heightForRowAtIndexPath:) ||
           selector == @selector(tableView:estimatedHeightForRowAtIndexPath:) ||
           selector == @selector(tableView:heightForHeaderInSection:) ||
           selector == @selector(tableView:heightForFooterInSection:) ||
           selector == @selector(tableView:estimatedHeightForHeaderInSection:) ||
           selector == @selector(tableView:estimatedHeightForFooterInSection:) ||
           selector == @selector(tableView:viewForHeaderInSection:) ||
           selector == @selector(tableView:viewForFooterInSection:) ||
           selector == @selector(tableView:didDeselectRowAtIndexPath:) ||
           selector == @selector(tableView:willSelectRowAtIndexPath:) ||
           selector == @selector(tableView:willDeselectRowAtIndexPath:) ||
           selector == @selector(tableView:shouldHighlightRowAtIndexPath:) ||
           selector == @selector(tableView:didHighlightRowAtIndexPath:) ||
           selector == @selector(tableView:didUnhighlightRowAtIndexPath:) ||
           selector == @selector(tableView:accessoryButtonTappedForRowWithIndexPath:) ||
           selector == @selector(tableView:indentationLevelForRowAtIndexPath:) ||
           selector == @selector(tableView:shouldIndentWhileEditingRowAtIndexPath:) ||
           selector == @selector(tableView:editingStyleForRowAtIndexPath:) ||
           selector == @selector(tableView:trailingSwipeActionsConfigurationForRowAtIndexPath:) ||
           selector == @selector(tableView:leadingSwipeActionsConfigurationForRowAtIndexPath:) ||
           selector == @selector(tableView:contextMenuConfigurationForRowAtIndexPath:point:) ||
           selector == @selector(tableView:didEndDisplayingCell:forRowAtIndexPath:);
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    NSInteger count = 1;
    if ([self.dataSource respondsToSelector:@selector(numberOfSectionsInTableView:)]) {
        count = [self.dataSource numberOfSectionsInTableView:tableView];
    }
    if (count < 0) count = 0;
    return count + 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return 1;
    if (![self.dataSource respondsToSelector:@selector(tableView:numberOfRowsInSection:)]) return 0;
    return [self.dataSource tableView:tableView numberOfRowsInSection:section - 1];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([self isEntryPath:indexPath]) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:TSEntryCellID];
        if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:TSEntryCellID];
        cell.textLabel.text = @"TikSpice";
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
        UIImage *icon = [[UIImage systemImageNamed:@"sparkles"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        cell.imageView.image = icon;
        cell.imageView.tintColor = UIColor.labelColor;
        cell.accessibilityIdentifier = TSEntryCellID;
        cell.accessibilityLabel = @"TikSpice";
        return cell;
    }
    return [self.dataSource tableView:tableView cellForRowAtIndexPath:[self mappedPath:indexPath]];
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([self isEntryPath:indexPath]) {
        __weak UITableView *weakTable = tableView;
        __weak UITableViewCell *weakCell = cell;
        dispatch_async(dispatch_get_main_queue(), ^{
            UITableViewCell *entry = weakCell;
            UITableView *table = weakTable;
            if (!entry || !table) return;
            for (UITableViewCell *other in table.visibleCells) {
                if (other == entry || other.textLabel.text.length == 0) continue;
                if ([other.accessibilityIdentifier isEqualToString:TSEntryCellID]) continue;
                if (other.textLabel.font) entry.textLabel.font = other.textLabel.font;
                if (other.textLabel.textColor) entry.textLabel.textColor = other.textLabel.textColor;
                if (other.backgroundColor) entry.backgroundColor = other.backgroundColor;
                entry.imageView.tintColor = other.tintColor ?: other.textLabel.textColor;
                break;
            }
        });
        return;
    }
    if ([self.delegateSource respondsToSelector:@selector(tableView:willDisplayCell:forRowAtIndexPath:)]) {
        [self.delegateSource tableView:tableView willDisplayCell:cell forRowAtIndexPath:[self mappedPath:indexPath]];
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([self isEntryPath:indexPath]) {
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        TSHapticLight();
        UIViewController *host = self.host ?: TSTopViewController();
        [TSSettingsViewController presentFromViewController:host];
        return;
    }
    if ([self.delegateSource respondsToSelector:@selector(tableView:didSelectRowAtIndexPath:)]) {
        [self.delegateSource tableView:tableView didSelectRowAtIndexPath:[self mappedPath:indexPath]];
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) return nil;
    return [self.dataSource tableView:tableView titleForHeaderInSection:section - 1];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 0) return nil;
    return [self.dataSource tableView:tableView titleForFooterInSection:section - 1];
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if (section == 0) return tableView.style == UITableViewStylePlain ? 8 : 18;
    return [self.delegateSource tableView:tableView heightForHeaderInSection:section - 1];
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    if (section == 0) return 0.01;
    return [self.delegateSource tableView:tableView heightForFooterInSection:section - 1];
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForHeaderInSection:(NSInteger)section {
    if (section == 0) return 18;
    return [self.delegateSource tableView:tableView estimatedHeightForHeaderInSection:section - 1];
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForFooterInSection:(NSInteger)section {
    if (section == 0) return 0.01;
    return [self.delegateSource tableView:tableView estimatedHeightForFooterInSection:section - 1];
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    if (section == 0) return nil;
    return [self.delegateSource tableView:tableView viewForHeaderInSection:section - 1];
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
    if (section == 0) return nil;
    return [self.delegateSource tableView:tableView viewForFooterInSection:section - 1];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([self isEntryPath:indexPath]) {
        if ([self.delegateSource respondsToSelector:@selector(tableView:heightForRowAtIndexPath:)] &&
            [self.dataSource respondsToSelector:@selector(tableView:numberOfRowsInSection:)]) {
            NSInteger sections = 1;
            if ([self.dataSource respondsToSelector:@selector(numberOfSectionsInTableView:)]) {
                sections = [self.dataSource numberOfSectionsInTableView:tableView];
            }
            if (sections > 0 && [self.dataSource tableView:tableView numberOfRowsInSection:0] > 0) {
                CGFloat height = [self.delegateSource tableView:tableView heightForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
                if (height > 20 && height < 160) return height;
            }
        }
        CGFloat fallback = tableView.rowHeight;
        if (fallback > 20 && fallback < 160) return fallback;
        return 52;
    }
    return [self.delegateSource tableView:tableView heightForRowAtIndexPath:[self mappedPath:indexPath]];
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([self isEntryPath:indexPath]) return 52;
    return [self.delegateSource tableView:tableView estimatedHeightForRowAtIndexPath:[self mappedPath:indexPath]];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([self isEntryPath:indexPath]) return NO;
    return [self.dataSource tableView:tableView canEditRowAtIndexPath:[self mappedPath:indexPath]];
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([self isEntryPath:indexPath]) return NO;
    return [self.dataSource tableView:tableView canMoveRowAtIndexPath:[self mappedPath:indexPath]];
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([self isEntryPath:indexPath]) return UITableViewCellEditingStyleNone;
    return [self.delegateSource tableView:tableView editingStyleForRowAtIndexPath:[self mappedPath:indexPath]];
}

- (BOOL)tableView:(UITableView *)tableView shouldIndentWhileEditingRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([self isEntryPath:indexPath]) return NO;
    return [self.delegateSource tableView:tableView shouldIndentWhileEditingRowAtIndexPath:[self mappedPath:indexPath]];
}

- (NSInteger)tableView:(UITableView *)tableView indentationLevelForRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([self isEntryPath:indexPath]) return 0;
    return [self.delegateSource tableView:tableView indentationLevelForRowAtIndexPath:[self mappedPath:indexPath]];
}

- (BOOL)tableView:(UITableView *)tableView shouldHighlightRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([self isEntryPath:indexPath]) return YES;
    return [self.delegateSource tableView:tableView shouldHighlightRowAtIndexPath:[self mappedPath:indexPath]];
}

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([self isEntryPath:indexPath]) return indexPath;
    return [self.delegateSource tableView:tableView willSelectRowAtIndexPath:[self mappedPath:indexPath]];
}

- (NSIndexPath *)tableView:(UITableView *)tableView willDeselectRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([self isEntryPath:indexPath]) return indexPath;
    return [self.delegateSource tableView:tableView willDeselectRowAtIndexPath:[self mappedPath:indexPath]];
}

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([self isEntryPath:indexPath]) return;
    [self.delegateSource tableView:tableView didDeselectRowAtIndexPath:[self mappedPath:indexPath]];
}

- (void)tableView:(UITableView *)tableView didHighlightRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([self isEntryPath:indexPath]) return;
    [self.delegateSource tableView:tableView didHighlightRowAtIndexPath:[self mappedPath:indexPath]];
}

- (void)tableView:(UITableView *)tableView didUnhighlightRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([self isEntryPath:indexPath]) return;
    [self.delegateSource tableView:tableView didUnhighlightRowAtIndexPath:[self mappedPath:indexPath]];
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
    if ([self isEntryPath:indexPath]) return;
    [self.delegateSource tableView:tableView accessoryButtonTappedForRowWithIndexPath:[self mappedPath:indexPath]];
}

- (void)tableView:(UITableView *)tableView didEndDisplayingCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([self isEntryPath:indexPath]) return;
    [self.delegateSource tableView:tableView didEndDisplayingCell:cell forRowAtIndexPath:[self mappedPath:indexPath]];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath API_AVAILABLE(ios(11.0)) {
    if ([self isEntryPath:indexPath]) return nil;
    return [self.delegateSource tableView:tableView trailingSwipeActionsConfigurationForRowAtIndexPath:[self mappedPath:indexPath]];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView leadingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath API_AVAILABLE(ios(11.0)) {
    if ([self isEntryPath:indexPath]) return nil;
    return [self.delegateSource tableView:tableView leadingSwipeActionsConfigurationForRowAtIndexPath:[self mappedPath:indexPath]];
}

- (UIContextMenuConfiguration *)tableView:(UITableView *)tableView contextMenuConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath point:(CGPoint)point API_AVAILABLE(ios(13.0)) {
    if ([self isEntryPath:indexPath]) return nil;
    return [self.delegateSource tableView:tableView contextMenuConfigurationForRowAtIndexPath:[self mappedPath:indexPath] point:point];
}

@end

#pragma mark - Fallback row

@interface TSFallbackRow : UIControl
@property (nonatomic, weak) UIViewController *host;
@end

@implementation TSFallbackRow

- (instancetype)initWithHost:(UIViewController *)host {
    self = [super initWithFrame:CGRectZero];
    if (!self) return nil;
    _host = host;
    self.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
    self.accessibilityLabel = @"TikSpice";
    self.isAccessibilityElement = YES;

    UIImageView *icon = [[UIImageView alloc] initWithImage:[[UIImage systemImageNamed:@"sparkles"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]];
    icon.tintColor = UIColor.labelColor;
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    UILabel *title = [UILabel new];
    title.text = @"TikSpice";
    title.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    title.textColor = UIColor.labelColor;
    title.translatesAutoresizingMaskIntoConstraints = NO;
    UIImageView *chevron = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"chevron.right"]];
    chevron.tintColor = UIColor.tertiaryLabelColor;
    chevron.translatesAutoresizingMaskIntoConstraints = NO;
    UIView *hairline = [UIView new];
    hairline.backgroundColor = UIColor.separatorColor;
    hairline.translatesAutoresizingMaskIntoConstraints = NO;
    for (UIView *view in @[icon, title, chevron, hairline]) [self addSubview:view];
    [NSLayoutConstraint activateConstraints:@[
        [self.heightAnchor constraintEqualToConstant:52],
        [icon.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:16],
        [icon.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [icon.widthAnchor constraintEqualToConstant:22],
        [icon.heightAnchor constraintEqualToConstant:22],
        [title.leadingAnchor constraintEqualToAnchor:icon.trailingAnchor constant:12],
        [title.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [chevron.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-16],
        [chevron.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [title.trailingAnchor constraintLessThanOrEqualToAnchor:chevron.leadingAnchor constant:-8],
        [hairline.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [hairline.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [hairline.topAnchor constraintEqualToAnchor:self.topAnchor],
        [hairline.heightAnchor constraintEqualToConstant:0.5],
    ]];
    [self addTarget:self action:@selector(open) forControlEvents:UIControlEventTouchUpInside];
    return self;
}

- (void)open {
    TSHapticLight();
    [TSSettingsViewController presentFromViewController:self.host ?: TSTopViewController()];
}

@end

#pragma mark - Entry

static NSString *TSVisibleTitle(UIViewController *controller);
static BOOL TSTitleIsSettingsHome(NSString *title);
static UITableView *TSMainTable(UIViewController *controller);

@implementation TSEntry

+ (void)load {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(installRecoveryGesture) name:UISceneDidActivateNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(installRecoveryGesture) name:UIWindowDidBecomeKeyNotification object:nil];
}

+ (void)installRecoveryGesture {
    dispatch_async(dispatch_get_main_queue(), ^{
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if (![scene isKindOfClass:[UIWindowScene class]]) continue;
            for (UIWindow *window in ((UIWindowScene *)scene).windows) {
                [self attachRecoveryToWindow:window];
            }
        }
    });
}

+ (void)attachRecoveryToWindow:(UIWindow *)window {
    if (!window || objc_getAssociatedObject(window, @selector(ts_recovery))) return;
    UILongPressGestureRecognizer *press = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(recoveryPressed:)];
    press.numberOfTouchesRequired = 3;
    press.minimumPressDuration = 0.6;
    press.cancelsTouchesInView = YES;
    [window addGestureRecognizer:press];
    objc_setAssociatedObject(window, @selector(ts_recovery), press, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

+ (void)recoveryPressed:(UILongPressGestureRecognizer *)press {
    if (press.state != UIGestureRecognizerStateBegan) return;
    TSHapticLight();
    [TSSettingsViewController presentFromViewController:TSTopViewController()];
}

+ (void)considerViewController:(UIViewController *)controller {
    if (!controller || TSIsOwnedView(controller.view)) return;
    NSString *name = NSStringFromClass(controller.class);
    if ([name hasPrefix:@"TS"] || [name hasPrefix:@"UI"] || [name hasPrefix:@"_UI"]) return;
    BOOL settings = [[TSHookRegistry classNamesInGroup:@"settingsHome"] containsObject:name] || TSTitleIsSettingsHome(TSVisibleTitle(controller));
    BOOL menu = NO;
    if (!settings && ![TSHookRegistry groupHasLoadedClass:@"settingsHome"]) {
        menu = [[TSHookRegistry classNamesInGroup:@"profileMenu"] containsObject:name] || ([name containsString:@"Profile"] && [name containsString:@"Menu"]);
    }
    if (!settings && !menu) return;
    [self injectInto:controller];
    __weak UIViewController *weakController = controller;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (weakController) [self injectInto:weakController];
    });
}

+ (void)injectInto:(UIViewController *)controller {
    if (!controller.isViewLoaded || TSIsOwnedView(controller.view)) return;
    UITableView *table = TSMainTable(controller);
    if (table.dataSource && [self installProxyOn:table host:controller]) {
        TSFallbackRow *fallback = objc_getAssociatedObject(controller, @selector(ts_fallbackRow));
        [fallback removeFromSuperview];
        objc_setAssociatedObject(controller, @selector(ts_fallbackRow), nil, OBJC_ASSOCIATION_ASSIGN);
        return;
    }
    [self installFallbackRowOn:controller];
}

+ (BOOL)installProxyOn:(UITableView *)table host:(UIViewController *)host {
    if ([table.dataSource isKindOfClass:[TSTableProxy class]]) return YES;
    // A diffable snapshot has a fixed section count. Adding a section through
    // the data source fights that snapshot, so use the pinned row instead.
    if ([table.dataSource isKindOfClass:[UITableViewDiffableDataSource class]]) return NO;
    id dataSource = table.dataSource;
    if (!dataSource) return NO;
    TSTableProxy *proxy = [TSTableProxy new];
    proxy.dataSource = dataSource;
    proxy.delegateSource = table.delegate ?: dataSource;
    proxy.host = host;
    objc_setAssociatedObject(table, @selector(ts_proxy), proxy, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    table.dataSource = proxy;
    table.delegate = proxy;
    [table reloadData];
    NSLog(@"[TikSpice] settings row on %@", NSStringFromClass(host.class));
    return YES;
}

+ (void)installFallbackRowOn:(UIViewController *)controller {
    if (objc_getAssociatedObject(controller, @selector(ts_fallbackRow))) return;
    TSFallbackRow *row = [[TSFallbackRow alloc] initWithHost:controller];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    TSMarkOwned(row);
    [controller.view addSubview:row];
    UILayoutGuide *safe = controller.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [row.leadingAnchor constraintEqualToAnchor:controller.view.leadingAnchor],
        [row.trailingAnchor constraintEqualToAnchor:controller.view.trailingAnchor],
        [row.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor],
    ]];
    objc_setAssociatedObject(controller, @selector(ts_fallbackRow), row, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    NSLog(@"[TikSpice] fallback row on %@", NSStringFromClass(controller.class));
}

@end

static NSString *TSVisibleTitle(UIViewController *controller) {
    NSString *title = controller.navigationItem.title;
    if (title.length == 0) title = controller.title;
    if (title.length == 0 && [controller.navigationItem.titleView isKindOfClass:[UILabel class]]) {
        title = ((UILabel *)controller.navigationItem.titleView).text;
    }
    return title ?: @"";
}

static BOOL TSTitleIsSettingsHome(NSString *title) {
    if (title.length == 0 || title.length > 48) return NO;
    NSString *fold = title.lowercaseString;
    NSArray<NSString *> *english = @[@"settings and privacy", @"settings & privacy", @"privacy and settings"];
    for (NSString *candidate in english) {
        if ([fold isEqualToString:candidate]) return YES;
    }
    NSArray<NSString *> *exact = @[@"设置与隐私", @"設定與隱私", @"设置和隐私", @"設定和隱私", @"설정 및 개인정보", @"Настройки и конфиденциальность"];
    for (NSString *candidate in exact) {
        if ([title isEqualToString:candidate]) return YES;
    }
    BOOL privacy = [fold containsString:@"privacy"] || [fold containsString:@"privacidad"] || [fold containsString:@"confidential"] || [fold containsString:@"privacidade"] || [fold containsString:@"datenschutz"] || [title containsString:@"隐私"] || [title containsString:@"隱私"] || [title containsString:@"개인정보"];
    BOOL settings = [fold containsString:@"setting"] || [fold containsString:@"ajuste"] || [fold containsString:@"configura"] || [fold containsString:@"paramètre"] || [fold containsString:@"parametre"] || [fold containsString:@"einstellung"] || [fold containsString:@"impostaz"] || [title containsString:@"设置"] || [title containsString:@"設定"] || [title containsString:@"설정"];
    return privacy && settings;
}

static void TSWalkTables(UIView *view, UITableView **best, CGFloat *bestArea, NSInteger depth) {
    if (!view || depth > 24) return;
    if ([view isKindOfClass:[UITableView class]]) {
        CGFloat area = view.bounds.size.width * view.bounds.size.height;
        if (area > *bestArea) {
            *bestArea = area;
            *best = (UITableView *)view;
        }
    }
    for (UIView *subview in view.subviews) TSWalkTables(subview, best, bestArea, depth + 1);
}

static UITableView *TSMainTable(UIViewController *controller) {
    if ([controller respondsToSelector:@selector(tableView)]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        id value = [controller performSelector:@selector(tableView)];
#pragma clang diagnostic pop
        if ([value isKindOfClass:[UITableView class]] && ((UITableView *)value).dataSource) return value;
    }
    UITableView *best = nil;
    CGFloat area = 0;
    TSWalkTables(controller.view, &best, &area, 0);
    if (best.bounds.size.height < 80) return nil;
    return best;
}
