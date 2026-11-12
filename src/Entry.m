#import "Entry.h"
#import "HookRegistry.h"
#import "SettingsUI.h"
#import "Owned.h"
#import "UIUtil.h"
#import <objc/message.h>
#import <objc/runtime.h>

static NSString *const TSEntryCellID = @"TikSpiceEntry";
static NSString *const TSEntryToken = @"com.tikspice.entry";
static const void *kTSDiffableMark = &kTSDiffableMark;
static const void *kTSDiffableHost = &kTSDiffableHost;

#pragma mark - Style

static UIColor *TSCardColor(void) {
    return [UIColor colorWithRed:42.0 / 255.0 green:42.0 / 255.0 blue:42.0 / 255.0 alpha:1];
}

static BOOL TSIsAccountTitle(NSString *title) {
    if (title.length == 0 || title.length > 40) return NO;
    NSString *fold = title.lowercaseString;
    if ([fold isEqualToString:@"account"] || [fold isEqualToString:@"cuenta"] || [fold isEqualToString:@"compte"] || [fold isEqualToString:@"konto"]) return YES;
    return [title isEqualToString:@"账户"] || [title isEqualToString:@"账号"] || [title isEqualToString:@"帳號"] || [title isEqualToString:@"계정"];
}

static NSString *TSFirstLabelText(UIView *view, NSInteger depth) {
    if (!view || depth > 6) return nil;
    if ([view isKindOfClass:[UILabel class]]) {
        NSString *text = ((UILabel *)view).text;
        if (text.length) return text;
    }
    for (UIView *subview in view.subviews) {
        NSString *text = TSFirstLabelText(subview, depth + 1);
        if (text.length) return text;
    }
    return nil;
}

static void TSPaintLabels(UIView *view, BOOL *foundTitle, NSInteger depth) {
    if (!view || depth > 8) return;
    if ([view isKindOfClass:[UILabel class]]) {
        UILabel *label = (UILabel *)view;
        if (!*foundTitle && label.font.pointSize >= 14) {
            label.text = @"TikSpice";
            label.hidden = NO;
            *foundTitle = YES;
        } else if (*foundTitle && label.text.length && label.font.pointSize < 14) {
            label.text = @"";
        }
    }
    for (UIView *subview in view.subviews) TSPaintLabels(subview, foundTitle, depth + 1);
}

static void TSPaintIcon(UIView *view, UIImageView **best, CGFloat *bestX, NSInteger depth) {
    if (!view || depth > 8) return;
    if ([view isKindOfClass:[UIImageView class]]) {
        UIImageView *imageView = (UIImageView *)view;
        CGFloat width = imageView.bounds.size.width;
        if (width >= 14 && width <= 36) {
            CGPoint origin = [imageView convertPoint:CGPointZero toView:imageView.window ?: imageView.superview];
            if (!*best || origin.x < *bestX) {
                *best = imageView;
                *bestX = origin.x;
            }
        }
    }
    for (UIView *subview in view.subviews) TSPaintIcon(subview, best, bestX, depth + 1);
}

static UITableViewCell *TSMakeTableCell(UITableView *tableView) {
    UITableViewCell *sample = nil;
    for (UITableViewCell *cell in tableView.visibleCells) {
        if (![cell.accessibilityIdentifier isEqualToString:TSEntryCellID]) {
            sample = cell;
            break;
        }
    }
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:TSEntryCellID];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:TSEntryCellID];
    BOOL painted = NO;
    if (sample && sample.class != [UITableViewCell class]) {
        UITableViewCell *native = [[sample.class alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:TSEntryCellID];
        if (native) {
            TSPaintLabels(native, &painted, 0);
            if (painted) cell = native;
        }
    }
    if (!painted) {
        cell.textLabel.text = @"TikSpice";
        cell.textLabel.textColor = sample.textLabel.textColor ?: UIColor.whiteColor;
        cell.textLabel.font = sample.textLabel.font ?: [UIFont systemFontOfSize:16 weight:UIFontWeightRegular];
    }
    UIColor *fill = sample.backgroundColor;
    if (!fill || [fill isEqual:UIColor.clearColor]) fill = TSCardColor();
    cell.backgroundColor = fill;
    cell.imageView.image = [[UIImage systemImageNamed:@"sparkles"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    cell.imageView.tintColor = sample.imageView.tintColor ?: UIColor.whiteColor;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.tintColor = [UIColor colorWithWhite:0.62 alpha:1];
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    cell.accessibilityIdentifier = TSEntryCellID;
    cell.accessibilityLabel = @"TikSpice";
    cell.separatorInset = sample ? sample.separatorInset : UIEdgeInsetsMake(0, 56, 0, 0);
    return cell;
}

@interface TSCollectionEntryCell : UICollectionViewCell
@property (nonatomic, strong) UIImageView *iconView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIImageView *chevronView;
@property (nonatomic, strong) UIView *hairline;
@end

@implementation TSCollectionEntryCell

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;
    self.backgroundColor = UIColor.clearColor;
    _iconView = [[UIImageView alloc] initWithImage:[[UIImage systemImageNamed:@"sparkles"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]];
    _iconView.tintColor = UIColor.whiteColor;
    _iconView.contentMode = UIViewContentModeScaleAspectFit;
    _titleLabel = [UILabel new];
    _titleLabel.text = @"TikSpice";
    _titleLabel.textColor = UIColor.whiteColor;
    _titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightRegular];
    _chevronView = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"chevron.right"]];
    _chevronView.tintColor = [UIColor colorWithWhite:0.55 alpha:1];
    _chevronView.contentMode = UIViewContentModeScaleAspectFit;
    _hairline = [UIView new];
    _hairline.backgroundColor = [UIColor colorWithWhite:1 alpha:0.08];
    for (UIView *view in @[_iconView, _titleLabel, _chevronView, _hairline]) {
        view.translatesAutoresizingMaskIntoConstraints = NO;
        [self.contentView addSubview:view];
    }
    [NSLayoutConstraint activateConstraints:@[
        [self.contentView.heightAnchor constraintGreaterThanOrEqualToConstant:52],
        [_iconView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
        [_iconView.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        [_iconView.widthAnchor constraintEqualToConstant:24],
        [_iconView.heightAnchor constraintEqualToConstant:24],
        [_titleLabel.leadingAnchor constraintEqualToAnchor:_iconView.trailingAnchor constant:12],
        [_titleLabel.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        [_chevronView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],
        [_chevronView.centerYAnchor constraintEqualToAnchor:self.contentView.centerYAnchor],
        [_chevronView.widthAnchor constraintEqualToConstant:11],
        [_chevronView.heightAnchor constraintEqualToConstant:16],
        [_titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:_chevronView.leadingAnchor constant:-8],
        [_hairline.leadingAnchor constraintEqualToAnchor:_titleLabel.leadingAnchor],
        [_hairline.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
        [_hairline.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
        [_hairline.heightAnchor constraintEqualToConstant:0.5],
    ]];
    self.accessibilityLabel = @"TikSpice";
    self.accessibilityIdentifier = TSEntryCellID;
    return self;
}

- (UICollectionViewLayoutAttributes *)preferredLayoutAttributesFittingAttributes:(UICollectionViewLayoutAttributes *)layoutAttributes {
    UICollectionViewLayoutAttributes *fit = [layoutAttributes copy];
    CGRect frame = fit.frame;
    if (frame.size.height < 48) frame.size.height = 52;
    fit.frame = frame;
    return fit;
}

@end

static void TSMatchCollectionCell(TSCollectionEntryCell *cell, UICollectionView *collectionView) {
    for (UICollectionViewCell *other in collectionView.visibleCells) {
        if (other == cell || [other.accessibilityIdentifier isEqualToString:TSEntryCellID]) continue;
        UIColor *fill = other.backgroundColor ?: other.contentView.backgroundColor;
        if (fill && ![fill isEqual:UIColor.clearColor]) {
            cell.contentView.backgroundColor = fill;
            cell.backgroundColor = fill;
        }
        NSString *text = TSFirstLabelText(other, 0);
        (void)text;
        UILabel *label = nil;
        NSMutableArray<UIView *> *stack = [NSMutableArray arrayWithObject:other];
        while (stack.count && !label) {
            UIView *view = stack.firstObject;
            [stack removeObjectAtIndex:0];
            if ([view isKindOfClass:[UILabel class]] && ((UILabel *)view).font.pointSize >= 14) label = (UILabel *)view;
            else [stack addObjectsFromArray:view.subviews];
        }
        if (label) {
            cell.titleLabel.font = label.font;
            cell.titleLabel.textColor = label.textColor;
        }
        break;
    }
}

static UICollectionViewCell *TSMakeCollectionCell(UICollectionView *collectionView, NSIndexPath *indexPath) {
    [collectionView registerClass:[TSCollectionEntryCell class] forCellWithReuseIdentifier:TSEntryCellID];
    UICollectionViewCell *sample = nil;
    for (UICollectionViewCell *cell in collectionView.visibleCells) {
        if (![cell.accessibilityIdentifier isEqualToString:TSEntryCellID] && cell.reuseIdentifier.length) {
            sample = cell;
            break;
        }
    }
    if (sample.reuseIdentifier.length && ![sample.reuseIdentifier isEqualToString:TSEntryCellID]) {
        @try {
            UICollectionViewCell *native = [collectionView dequeueReusableCellWithReuseIdentifier:sample.reuseIdentifier forIndexPath:indexPath];
            BOOL painted = NO;
            TSPaintLabels(native, &painted, 0);
            if (painted) {
                UIImageView *icon = nil;
                CGFloat iconX = 0;
                TSPaintIcon(native, &icon, &iconX, 0);
                icon.image = [[UIImage systemImageNamed:@"sparkles"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
                icon.tintColor = UIColor.whiteColor;
                native.accessibilityIdentifier = TSEntryCellID;
                native.accessibilityLabel = @"TikSpice";
                return native;
            }
        } @catch (__unused NSException *exception) {
        }
    }
    TSCollectionEntryCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:TSEntryCellID forIndexPath:indexPath];
    TSMatchCollectionCell(cell, collectionView);
    return cell;
}

#pragma mark - Diffable snapshots

static id TSPreferredSection(NSDiffableDataSourceSnapshot *snapshot) {
    for (id section in snapshot.sectionIdentifiers) {
        NSString *blob = [section isKindOfClass:[NSString class]] ? section : nil;
        if (!blob) {
            @try {
                for (NSString *key in @[@"title", @"headerTitle", @"name", @"sectionTitle", @"header"]) {
                    id value = [section valueForKey:key];
                    if ([value isKindOfClass:[NSString class]] && [value length]) {
                        blob = value;
                        break;
                    }
                }
            } @catch (__unused NSException *exception) {
            }
        }
        if (TSIsAccountTitle(blob)) return section;
    }
    return snapshot.sectionIdentifiers.firstObject;
}

static NSDiffableDataSourceSnapshot *TSSnapshotByInsertingEntry(NSDiffableDataSourceSnapshot *snapshot) {
    if (snapshot.numberOfSections == 0) return snapshot;
    NSDiffableDataSourceSnapshot *copy = [snapshot copy];
    id section = TSPreferredSection(copy);
    if (!section) return snapshot;
    id current = nil;
    for (id existing in copy.sectionIdentifiers) {
        if ([[copy itemIdentifiersInSectionWithIdentifier:existing] containsObject:TSEntryToken]) {
            current = existing;
            break;
        }
    }
    if (current && ![current isEqual:section]) {
        [copy deleteItemsWithIdentifiers:@[TSEntryToken]];
        current = nil;
    }
    if (!current) {
        [copy appendItemsWithIdentifiers:@[TSEntryToken] intoSectionWithIdentifier:section];
    }
    return copy;
}

static BOOL TSDiffableMarked(id dataSource) {
    return objc_getAssociatedObject(dataSource, kTSDiffableMark) != nil;
}

static IMP TSClassOrig(Class cls, const void *key) {
    for (Class cursor = cls; cursor; cursor = class_getSuperclass(cursor)) {
        NSValue *value = objc_getAssociatedObject(cursor, key);
        if (value) return value.pointerValue;
    }
    return NULL;
}

static BOOL TSClassOwnsSelector(Class cls, SEL selector) {
    unsigned int count = 0;
    Method *list = class_copyMethodList(cls, &count);
    BOOL found = NO;
    for (unsigned int index = 0; index < count; index++) {
        if (method_getName(list[index]) == selector) found = YES;
    }
    free(list);
    return found;
}

static Class TSOwnerOfSelector(Class cls, SEL selector) {
    for (Class cursor = cls; cursor; cursor = class_getSuperclass(cursor)) {
        if (TSClassOwnsSelector(cursor, selector)) return cursor;
    }
    return Nil;
}

static const void *kOrigApply2 = &kOrigApply2;
static const void *kOrigApply3 = &kOrigApply3;
static const void *kOrigReload = &kOrigReload;
static const void *kOrigTableCell = &kOrigTableCell;
static const void *kOrigCollectionCell = &kOrigCollectionCell;

static void TSApply2(id self, SEL _cmd, NSDiffableDataSourceSnapshot *snapshot, BOOL animated) {
    IMP orig = TSClassOrig([self class], kOrigApply2);
    if (TSDiffableMarked(self)) snapshot = TSSnapshotByInsertingEntry(snapshot);
    ((void (*)(id, SEL, NSDiffableDataSourceSnapshot *, BOOL))orig)(self, _cmd, snapshot, animated);
}

static void TSApply3(id self, SEL _cmd, NSDiffableDataSourceSnapshot *snapshot, BOOL animated, id completion) {
    IMP orig = TSClassOrig([self class], kOrigApply3);
    if (TSDiffableMarked(self)) snapshot = TSSnapshotByInsertingEntry(snapshot);
    ((void (*)(id, SEL, NSDiffableDataSourceSnapshot *, BOOL, id))orig)(self, _cmd, snapshot, animated, completion);
}

static void TSApplyReload(id self, SEL _cmd, NSDiffableDataSourceSnapshot *snapshot) {
    IMP orig = TSClassOrig([self class], kOrigReload);
    if (TSDiffableMarked(self)) snapshot = TSSnapshotByInsertingEntry(snapshot);
    ((void (*)(id, SEL, NSDiffableDataSourceSnapshot *))orig)(self, _cmd, snapshot);
}

static UITableViewCell *TSDiffableTableCell(id self, SEL _cmd, UITableView *tableView, NSIndexPath *indexPath) {
    IMP orig = TSClassOrig([self class], kOrigTableCell);
    if (TSDiffableMarked(self)) {
        id item = ((id (*)(id, SEL, NSIndexPath *))objc_msgSend)(self, @selector(itemIdentifierForIndexPath:), indexPath);
        if ([item isEqual:TSEntryToken]) return TSMakeTableCell(tableView);
    }
    return ((UITableViewCell *(*)(id, SEL, UITableView *, NSIndexPath *))orig)(self, _cmd, tableView, indexPath);
}

static UICollectionViewCell *TSDiffableCollectionCell(id self, SEL _cmd, UICollectionView *collectionView, NSIndexPath *indexPath) {
    IMP orig = TSClassOrig([self class], kOrigCollectionCell);
    if (TSDiffableMarked(self)) {
        id item = ((id (*)(id, SEL, NSIndexPath *))objc_msgSend)(self, @selector(itemIdentifierForIndexPath:), indexPath);
        if ([item isEqual:TSEntryToken]) return TSMakeCollectionCell(collectionView, indexPath);
    }
    return ((UICollectionViewCell *(*)(id, SEL, UICollectionView *, NSIndexPath *))orig)(self, _cmd, collectionView, indexPath);
}

static void TSSwizzle(Class cls, SEL selector, IMP replacement, const void *key) {
    Class owner = TSOwnerOfSelector(cls, selector);
    if (!owner || objc_getAssociatedObject(owner, key)) return;
    Method method = class_getInstanceMethod(owner, selector);
    if (!method) return;
    IMP previous = method_setImplementation(method, replacement);
    objc_setAssociatedObject(owner, key, [NSValue valueWithPointer:previous], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void TSInstallDiffableSwizzles(id dataSource, BOOL table) {
    Class cls = [dataSource class];
    TSSwizzle(cls, @selector(applySnapshot:animatingDifferences:), (IMP)TSApply2, kOrigApply2);
    TSSwizzle(cls, @selector(applySnapshot:animatingDifferences:completion:), (IMP)TSApply3, kOrigApply3);
    TSSwizzle(cls, @selector(applySnapshotUsingReloadData:), (IMP)TSApplyReload, kOrigReload);
    if (table) TSSwizzle(cls, @selector(tableView:cellForRowAtIndexPath:), (IMP)TSDiffableTableCell, kOrigTableCell);
    else TSSwizzle(cls, @selector(collectionView:cellForItemAtIndexPath:), (IMP)TSDiffableCollectionCell, kOrigCollectionCell);
}

#pragma mark - Classic list proxy

@interface TSListProxy : NSObject <UITableViewDataSource, UITableViewDelegate, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout>
@property (nonatomic, weak) id dataSource;
@property (nonatomic, weak) id delegateSource;
@property (nonatomic, weak) UIViewController *host;
@property (nonatomic, assign) BOOL selectionOnly;
@property (nonatomic, weak) id diffable;
@end

static BOOL TSProxyImplements(SEL selector) {
    unsigned int count = 0;
    Method *list = class_copyMethodList([TSListProxy class], &count);
    BOOL found = NO;
    for (unsigned int index = 0; index < count; index++) {
        if (method_getName(list[index]) == selector) found = YES;
    }
    free(list);
    return found;
}

@implementation TSListProxy

- (BOOL)respondsToSelector:(SEL)selector {
    BOOL required = selector == @selector(tableView:numberOfRowsInSection:) ||
                    selector == @selector(tableView:cellForRowAtIndexPath:) ||
                    selector == @selector(tableView:didSelectRowAtIndexPath:) ||
                    selector == @selector(collectionView:numberOfItemsInSection:) ||
                    selector == @selector(collectionView:cellForItemAtIndexPath:) ||
                    selector == @selector(collectionView:didSelectItemAtIndexPath:);
    if (required) {
        if (self.selectionOnly) {
            return selector == @selector(tableView:didSelectRowAtIndexPath:) || selector == @selector(collectionView:didSelectItemAtIndexPath:);
        }
        return YES;
    }
    if (TSProxyImplements(selector)) {
        return [self.delegateSource respondsToSelector:selector] || [self.dataSource respondsToSelector:selector];
    }
    return [self.dataSource respondsToSelector:selector] || [self.delegateSource respondsToSelector:selector];
}

- (id)forwardingTargetForSelector:(SEL)selector {
    if (TSProxyImplements(selector)) return nil;
    if ([self.dataSource respondsToSelector:selector]) return self.dataSource;
    if ([self.delegateSource respondsToSelector:selector]) return self.delegateSource;
    return [super forwardingTargetForSelector:selector];
}

- (NSInteger)accountSectionForTable:(UITableView *)tableView {
    NSInteger sections = 1;
    if ([self.dataSource respondsToSelector:@selector(numberOfSectionsInTableView:)]) {
        sections = [self.dataSource numberOfSectionsInTableView:tableView];
    }
    for (NSInteger section = 0; section < sections; section++) {
        NSString *title = nil;
        if ([self.dataSource respondsToSelector:@selector(tableView:titleForHeaderInSection:)]) {
            title = [self.dataSource tableView:tableView titleForHeaderInSection:section];
        }
        if (!TSIsAccountTitle(title)) title = TSFirstLabelText([tableView headerViewForSection:section], 0);
        if (TSIsAccountTitle(title)) return section;
    }
    return 0;
}

- (NSInteger)accountSectionForCollection:(UICollectionView *)collectionView {
    NSInteger sections = 1;
    if ([self.dataSource respondsToSelector:@selector(numberOfSectionsInCollectionView:)]) {
        sections = [self.dataSource numberOfSectionsInCollectionView:collectionView];
    }
    for (NSInteger section = 0; section < sections; section++) {
        NSIndexPath *path = [NSIndexPath indexPathForItem:0 inSection:section];
        UICollectionViewLayoutAttributes *attributes = [collectionView.collectionViewLayout layoutAttributesForSupplementaryViewOfKind:UICollectionElementKindSectionHeader atIndexPath:path];
        if (!attributes) continue;
        for (UICollectionReusableView *view in [collectionView visibleSupplementaryViewsOfKind:UICollectionElementKindSectionHeader]) {
            if (fabs(CGRectGetMinY(view.frame) - CGRectGetMinY(attributes.frame)) > 2) continue;
            if (TSIsAccountTitle(TSFirstLabelText(view, 0))) return section;
        }
    }
    return sections > 1 ? 1 : 0;
}

- (BOOL)isExtraTablePath:(NSIndexPath *)indexPath table:(UITableView *)tableView {
    if (self.selectionOnly) {
        id item = ((id (*)(id, SEL, NSIndexPath *))objc_msgSend)(self.diffable, @selector(itemIdentifierForIndexPath:), indexPath);
        return [item isEqual:TSEntryToken];
    }
    if (indexPath.section != [self accountSectionForTable:tableView]) return NO;
    NSInteger count = [self.dataSource tableView:tableView numberOfRowsInSection:indexPath.section];
    return indexPath.row == count;
}

- (BOOL)isExtraCollectionPath:(NSIndexPath *)indexPath collection:(UICollectionView *)collectionView {
    if (self.selectionOnly) {
        id item = ((id (*)(id, SEL, NSIndexPath *))objc_msgSend)(self.diffable, @selector(itemIdentifierForIndexPath:), indexPath);
        return [item isEqual:TSEntryToken];
    }
    if (indexPath.section != [self accountSectionForCollection:collectionView]) return NO;
    NSInteger count = [self.dataSource collectionView:collectionView numberOfItemsInSection:indexPath.section];
    return indexPath.item == count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSInteger count = [self.dataSource tableView:tableView numberOfRowsInSection:section];
    if (section == [self accountSectionForTable:tableView]) count += 1;
    return count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([self isExtraTablePath:indexPath table:tableView]) return TSMakeTableCell(tableView);
    return [self.dataSource tableView:tableView cellForRowAtIndexPath:indexPath];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([self isExtraTablePath:indexPath table:tableView]) {
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        TSHapticLight();
        [TSSettingsViewController presentFromViewController:self.host ?: TSTopViewController()];
        return;
    }
    if ([self.delegateSource respondsToSelector:@selector(tableView:didSelectRowAtIndexPath:)]) {
        [self.delegateSource tableView:tableView didSelectRowAtIndexPath:indexPath];
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([self isExtraTablePath:indexPath table:tableView]) {
        NSInteger count = [self.dataSource tableView:tableView numberOfRowsInSection:indexPath.section];
        if (count > 0 && [self.delegateSource respondsToSelector:@selector(tableView:heightForRowAtIndexPath:)]) {
            CGFloat height = [self.delegateSource tableView:tableView heightForRowAtIndexPath:[NSIndexPath indexPathForRow:count - 1 inSection:indexPath.section]];
            if (height > 20 && height < 120) return height;
        }
        return 52;
    }
    return [self.delegateSource tableView:tableView heightForRowAtIndexPath:indexPath];
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    NSInteger count = [self.dataSource collectionView:collectionView numberOfItemsInSection:section];
    if (section == [self accountSectionForCollection:collectionView]) count += 1;
    return count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    if ([self isExtraCollectionPath:indexPath collection:collectionView]) return TSMakeCollectionCell(collectionView, indexPath);
    return [self.dataSource collectionView:collectionView cellForItemAtIndexPath:indexPath];
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    if ([self isExtraCollectionPath:indexPath collection:collectionView]) {
        [collectionView deselectItemAtIndexPath:indexPath animated:YES];
        TSHapticLight();
        [TSSettingsViewController presentFromViewController:self.host ?: TSTopViewController()];
        return;
    }
    if ([self.delegateSource respondsToSelector:@selector(collectionView:didSelectItemAtIndexPath:)]) {
        [self.delegateSource collectionView:collectionView didSelectItemAtIndexPath:indexPath];
    }
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([self isExtraTablePath:indexPath table:tableView]) return NO;
    return [self.dataSource tableView:tableView canEditRowAtIndexPath:indexPath];
}

- (BOOL)tableView:(UITableView *)tableView shouldHighlightRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([self isExtraTablePath:indexPath table:tableView]) return YES;
    return [self.delegateSource tableView:tableView shouldHighlightRowAtIndexPath:indexPath];
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([self isExtraTablePath:indexPath table:tableView]) return UITableViewCellEditingStyleNone;
    return [self.delegateSource tableView:tableView editingStyleForRowAtIndexPath:indexPath];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([self isExtraTablePath:indexPath table:tableView]) return nil;
    return [self.delegateSource tableView:tableView trailingSwipeActionsConfigurationForRowAtIndexPath:indexPath];
}

- (UIContextMenuConfiguration *)tableView:(UITableView *)tableView contextMenuConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath point:(CGPoint)point {
    if ([self isExtraTablePath:indexPath table:tableView]) return nil;
    return [self.delegateSource tableView:tableView contextMenuConfigurationForRowAtIndexPath:indexPath point:point];
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([self isExtraTablePath:indexPath table:tableView]) return;
    if ([self.delegateSource respondsToSelector:@selector(tableView:willDisplayCell:forRowAtIndexPath:)]) {
        [self.delegateSource tableView:tableView willDisplayCell:cell forRowAtIndexPath:indexPath];
    }
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)layout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    if ([self isExtraCollectionPath:indexPath collection:collectionView]) {
        NSInteger count = [self.dataSource collectionView:collectionView numberOfItemsInSection:indexPath.section];
        if (count > 0) {
            return [self.delegateSource collectionView:collectionView layout:layout sizeForItemAtIndexPath:[NSIndexPath indexPathForItem:count - 1 inSection:indexPath.section]];
        }
        return CGSizeMake(collectionView.bounds.size.width, 52);
    }
    return [self.delegateSource collectionView:collectionView layout:layout sizeForItemAtIndexPath:indexPath];
}

@end

#pragma mark - Entry

static NSString *TSVisibleTitle(UIViewController *controller);
static BOOL TSTitleIsSettingsHome(NSString *title);
static UIScrollView *TSMainList(UIViewController *controller);

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
                if (!window || objc_getAssociatedObject(window, @selector(ts_recovery))) continue;
                UILongPressGestureRecognizer *press = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(recoveryPressed:)];
                press.numberOfTouchesRequired = 3;
                press.minimumPressDuration = 0.6;
                press.cancelsTouchesInView = YES;
                [window addGestureRecognizer:press];
                objc_setAssociatedObject(window, @selector(ts_recovery), press, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            }
        }
    });
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
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (weakController) [self injectInto:weakController];
    });
}

+ (void)injectInto:(UIViewController *)controller {
    if (!controller.isViewLoaded || TSIsOwnedView(controller.view)) return;
    UIView *fallback = objc_getAssociatedObject(controller, @selector(ts_fallbackRow));
    [fallback removeFromSuperview];
    objc_setAssociatedObject(controller, @selector(ts_fallbackRow), nil, OBJC_ASSOCIATION_ASSIGN);

    UIScrollView *list = TSMainList(controller);
    if ([list isKindOfClass:[UITableView class]]) {
        [self injectTable:(UITableView *)list host:controller];
    } else if ([list isKindOfClass:[UICollectionView class]]) {
        [self injectCollection:(UICollectionView *)list host:controller];
    }
}

+ (void)injectTable:(UITableView *)tableView host:(UIViewController *)host {
    id dataSource = tableView.dataSource;
    if (!dataSource || [dataSource isKindOfClass:[TSListProxy class]]) return;
    if ([dataSource isKindOfClass:[UITableViewDiffableDataSource class]]) {
        [self hookDiffable:dataSource list:tableView host:host table:YES];
        return;
    }
    TSListProxy *proxy = [TSListProxy new];
    proxy.dataSource = dataSource;
    proxy.delegateSource = tableView.delegate ?: dataSource;
    proxy.host = host;
    objc_setAssociatedObject(tableView, @selector(ts_proxy), proxy, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    tableView.dataSource = proxy;
    tableView.delegate = proxy;
    [tableView reloadData];
    NSLog(@"[TikSpice] inserted row into %@", NSStringFromClass(host.class));
}

+ (void)injectCollection:(UICollectionView *)collectionView host:(UIViewController *)host {
    id dataSource = collectionView.dataSource;
    if (!dataSource || [dataSource isKindOfClass:[TSListProxy class]]) return;
    if ([dataSource isKindOfClass:[UICollectionViewDiffableDataSource class]]) {
        [self hookDiffable:dataSource list:collectionView host:host table:NO];
        return;
    }
    TSListProxy *proxy = [TSListProxy new];
    proxy.dataSource = dataSource;
    proxy.delegateSource = collectionView.delegate ?: dataSource;
    proxy.host = host;
    objc_setAssociatedObject(collectionView, @selector(ts_proxy), proxy, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    collectionView.dataSource = proxy;
    collectionView.delegate = proxy;
    [collectionView reloadData];
    NSLog(@"[TikSpice] inserted collection row into %@", NSStringFromClass(host.class));
}

+ (void)hookDiffable:(id)dataSource list:(UIScrollView *)list host:(UIViewController *)host table:(BOOL)table {
    if (TSDiffableMarked(dataSource)) return;
    objc_setAssociatedObject(dataSource, kTSDiffableMark, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(dataSource, kTSDiffableHost, host, OBJC_ASSOCIATION_ASSIGN);
    TSInstallDiffableSwizzles(dataSource, table);
    if (table) {
        UITableView *tableView = (UITableView *)list;
        if (![tableView.delegate isKindOfClass:[TSListProxy class]]) {
            TSListProxy *proxy = [TSListProxy new];
            proxy.selectionOnly = YES;
            proxy.diffable = dataSource;
            proxy.delegateSource = tableView.delegate;
            proxy.host = host;
            objc_setAssociatedObject(tableView, @selector(ts_proxy), proxy, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            tableView.delegate = proxy;
        }
    } else {
        UICollectionView *collectionView = (UICollectionView *)list;
        if (![collectionView.delegate isKindOfClass:[TSListProxy class]]) {
            TSListProxy *proxy = [TSListProxy new];
            proxy.selectionOnly = YES;
            proxy.diffable = dataSource;
            proxy.delegateSource = collectionView.delegate;
            proxy.host = host;
            objc_setAssociatedObject(collectionView, @selector(ts_proxy), proxy, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            collectionView.delegate = proxy;
        }
    }
    if ([dataSource respondsToSelector:@selector(snapshot)] && [dataSource respondsToSelector:@selector(applySnapshot:animatingDifferences:)]) {
        NSDiffableDataSourceSnapshot *snapshot = [dataSource snapshot];
        [dataSource applySnapshot:snapshot animatingDifferences:NO];
    }
    NSLog(@"[TikSpice] inserted diffable row into %@", NSStringFromClass(host.class));
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
    for (NSString *candidate in @[@"settings and privacy", @"settings & privacy", @"privacy and settings"]) {
        if ([fold isEqualToString:candidate]) return YES;
    }
    for (NSString *candidate in @[@"设置与隐私", @"設定與隱私", @"设置和隐私", @"設定和隱私", @"설정 및 개인정보", @"Настройки и конфиденциальность"]) {
        if ([title isEqualToString:candidate]) return YES;
    }
    BOOL privacy = [fold containsString:@"privacy"] || [fold containsString:@"privacidad"] || [fold containsString:@"confidential"] || [fold containsString:@"privacidade"] || [fold containsString:@"datenschutz"] || [title containsString:@"隐私"] || [title containsString:@"隱私"] || [title containsString:@"개인정보"];
    BOOL settings = [fold containsString:@"setting"] || [fold containsString:@"ajuste"] || [fold containsString:@"configura"] || [fold containsString:@"paramètre"] || [fold containsString:@"parametre"] || [fold containsString:@"einstellung"] || [fold containsString:@"impostaz"] || [title containsString:@"设置"] || [title containsString:@"設定"] || [title containsString:@"설정"];
    return privacy && settings;
}

static void TSWalkLists(UIView *view, UIScrollView **best, CGFloat *bestArea, NSInteger depth) {
    if (!view || depth > 28) return;
    if ([view isKindOfClass:[UITableView class]] || [view isKindOfClass:[UICollectionView class]]) {
        CGFloat area = view.bounds.size.width * view.bounds.size.height;
        if (area > *bestArea) {
            *bestArea = area;
            *best = (UIScrollView *)view;
        }
    }
    for (UIView *subview in view.subviews) TSWalkLists(subview, best, bestArea, depth + 1);
}

static UIScrollView *TSMainList(UIViewController *controller) {
    UIScrollView *best = nil;
    CGFloat area = 0;
    if ([controller respondsToSelector:@selector(tableView)]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        id value = [controller performSelector:@selector(tableView)];
#pragma clang diagnostic pop
        if ([value isKindOfClass:[UITableView class]]) {
            best = value;
            area = best.bounds.size.width * best.bounds.size.height;
        }
    }
    TSWalkLists(controller.view, &best, &area, 0);
    for (UIViewController *child in controller.childViewControllers) {
        TSWalkLists(child.view, &best, &area, 0);
    }
    if (best.bounds.size.height < 80 && best.bounds.size.width < 80) return nil;
    return best;
}
