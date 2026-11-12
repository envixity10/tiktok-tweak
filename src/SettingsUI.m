#import "SettingsUI.h"
#import "Theme.h"
#import "Prefs.h"
#import "Owned.h"
#import "UIUtil.h"
#import "HookRegistry.h"
#import "Floater.h"
#import "Download.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <objc/message.h>

typedef NS_ENUM(NSInteger, TSRowKind) {
    TSRowInfo = 0,
    TSRowToggle,
    TSRowAction,
    TSRowSlider,
    TSRowColor,
    TSRowPreset,
    TSRowText,
};

@interface TSRow : NSObject
@property (nonatomic, assign) TSRowKind kind;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *subtitle;
@property (nonatomic, copy) NSString *symbol;
@property (nonatomic, copy) NSString *prefKey;
@property (nonatomic, copy) NSString *colorKey;
@property (nonatomic, copy) NSString *searchBlob;
@property (nonatomic, assign) float sliderMin;
@property (nonatomic, assign) float sliderMax;
@property (nonatomic, assign) BOOL speedChips;
@property (nonatomic, copy) void (^action)(UIViewController *controller);
@end

@implementation TSRow
@end

@interface TSSection : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *footer;
@property (nonatomic, copy) NSArray<TSRow *> *rows;
@end

@implementation TSSection
@end

static BOOL TSThemeIsLight(TSTheme *theme, UITraitCollection *traits) {
    UIColor *resolved = [theme.background resolvedColorWithTraitCollection:traits];
    CGFloat red = 0, green = 0, blue = 0, alpha = 1;
    if (![resolved getRed:&red green:&green blue:&blue alpha:&alpha]) {
        CGFloat white = 0;
        if ([resolved getWhite:&white alpha:&alpha]) return white > 0.65;
        return NO;
    }
    return (0.2126 * red + 0.7152 * green + 0.0722 * blue) > 0.65;
}

static void TSStyleController(UITableViewController *controller) {
    TSTheme *theme = [TSTheme current];
    UIUserInterfaceStyle style = TSThemeIsLight(theme, controller.traitCollection) ? UIUserInterfaceStyleLight : UIUserInterfaceStyleDark;
    controller.overrideUserInterfaceStyle = style;
    controller.navigationController.overrideUserInterfaceStyle = style;
    controller.view.backgroundColor = theme.background;
    controller.tableView.backgroundColor = theme.background;
    controller.tableView.separatorColor = theme.separator;

    UINavigationBarAppearance *appearance = [UINavigationBarAppearance new];
    [appearance configureWithOpaqueBackground];
    appearance.backgroundColor = theme.background;
    appearance.shadowColor = UIColor.clearColor;
    appearance.titleTextAttributes = @{NSForegroundColorAttributeName: theme.textPrimary};
    appearance.largeTitleTextAttributes = @{
        NSForegroundColorAttributeName: theme.textPrimary,
        NSFontAttributeName: [UIFont systemFontOfSize:34 weight:UIFontWeightBold]
    };
    UINavigationBar *bar = controller.navigationController.navigationBar;
    bar.standardAppearance = appearance;
    bar.scrollEdgeAppearance = appearance;
    bar.compactAppearance = appearance;
    bar.tintColor = theme.accent;
    bar.prefersLargeTitles = YES;
    controller.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeAlways;
    UISearchBar *search = controller.navigationItem.searchController.searchBar;
    search.tintColor = theme.accent;
    search.searchTextField.textColor = theme.textPrimary;
    search.searchTextField.backgroundColor = theme.surface;
    TSMarkOwned(controller.view);
    TSMarkOwned(controller.tableView);
    TSMarkOwned(controller.navigationController.view);
}

static void TSFillListCell(UITableViewCell *cell, NSString *title, NSString *subtitle, NSString *symbol, TSTheme *theme, UIColor *detailColor) {
    UIListContentConfiguration *content = [UIListContentConfiguration subtitleCellConfiguration];
    content.text = title;
    content.secondaryText = subtitle;
    content.textProperties.color = theme.textPrimary;
    content.textProperties.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    content.secondaryText = subtitle;
    content.secondaryTextProperties.color = detailColor ?: theme.textSecondary;
    content.secondaryTextProperties.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
    content.secondaryTextProperties.numberOfLines = 3;
    if (symbol.length) {
        content.image = [UIImage systemImageNamed:symbol];
        content.imageProperties.tintColor = theme.accent;
    }
    cell.contentConfiguration = content;
    UIBackgroundConfiguration *background = [UIBackgroundConfiguration listGroupedCellConfiguration];
    background.backgroundColor = theme.surface;
    cell.backgroundConfiguration = background;
}

static void TSPresentSheet(UIViewController *root, UIViewController *from) {
    UIViewController *host = from ?: TSTopViewController();
    if ([host isKindOfClass:[UIAlertController class]]) host = host.presentingViewController ?: host;
    if (!host || !root) return;
    UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:root];
    navigation.modalPresentationStyle = UIModalPresentationPageSheet;
    navigation.navigationBar.prefersLargeTitles = YES;
    UISheetPresentationController *sheet = navigation.sheetPresentationController;
    sheet.detents = @[
        [UISheetPresentationControllerDetent mediumDetent],
        [UISheetPresentationControllerDetent largeDetent]
    ];
    sheet.selectedDetentIdentifier = UISheetPresentationControllerDetentIdentifierLarge;
    sheet.prefersGrabberVisible = YES;
    sheet.prefersScrollingExpandsWhenScrolledToEdge = YES;
    sheet.prefersEdgeAttachedInCompactHeight = YES;
    SEL cornerRadiusSetter = sel_registerName("setPreferredCornerRadius:");
    if ([sheet respondsToSelector:cornerRadiusSetter]) {
        ((void (*)(id, SEL, CGFloat))objc_msgSend)(sheet, cornerRadiusSetter, (CGFloat)22);
    }
    TSMarkOwned(navigation.view);
    [host presentViewController:navigation animated:YES completion:nil];
}

static BOOL TSAlreadyShowing(Class cls, UIViewController *start) {
    UIViewController *cursor = start;
    while (cursor) {
        if ([cursor isKindOfClass:cls]) return YES;
        if ([cursor isKindOfClass:[UINavigationController class]]) {
            for (UIViewController *child in [(UINavigationController *)cursor viewControllers]) {
                if ([child isKindOfClass:cls]) return YES;
            }
        }
        cursor = cursor.presentingViewController;
    }
    return NO;
}

static TSRow *TSToggleRow(NSString *title, NSString *subtitle, NSString *symbol, NSString *key) {
    TSRow *row = [TSRow new];
    row.kind = TSRowToggle;
    row.title = title;
    row.subtitle = subtitle;
    row.symbol = symbol;
    row.prefKey = key;
    row.searchBlob = [[NSString stringWithFormat:@"%@ %@ %@", title, subtitle ?: @"", key] lowercaseString];
    return row;
}

static TSRow *TSActionRow(NSString *title, NSString *subtitle, NSString *symbol, void (^action)(UIViewController *)) {
    TSRow *row = [TSRow new];
    row.kind = TSRowAction;
    row.title = title;
    row.subtitle = subtitle;
    row.symbol = symbol;
    row.action = action;
    row.searchBlob = [[NSString stringWithFormat:@"%@ %@", title, subtitle ?: @""] lowercaseString];
    return row;
}

static NSArray<NSString *> *TSHideKeys(void) {
    return @[
        TSKeyHideAds, TSKeyHideLive, TSKeyHideShop, TSKeyHideUpload, TSKeyHideFriends, TSKeyHideInbox,
        TSKeyHideSuggested, TSKeyHideFeedTabs, TSKeyHideStories, TSKeyHideMusicTicker, TSKeyHideViewCounts,
        TSKeyHideLikeCounts, TSKeyHideCommentCounts, TSKeyHideShareButton
    ];
}

#pragma mark - Cells

@interface TSToggleCell : UITableViewCell
@property (nonatomic, strong) UISwitch *toggle;
@property (nonatomic, copy) void (^onChange)(UISwitch *toggle, BOOL on);
@end

@implementation TSToggleCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (!self) return nil;
    _toggle = [UISwitch new];
    [_toggle addTarget:self action:@selector(changed) forControlEvents:UIControlEventValueChanged];
    self.accessoryView = _toggle;
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    return self;
}
- (void)changed {
    if (self.onChange) self.onChange(self.toggle, self.toggle.on);
}
@end

@interface TSSliderCell : UITableViewCell
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *valueLabel;
@property (nonatomic, strong) UIStackView *chips;
@property (nonatomic, strong) UISlider *slider;
@property (nonatomic, copy) void (^onChange)(float value, BOOL continuous);
- (void)setChipValues:(NSArray<NSNumber *> *)values accent:(UIColor *)accent secondary:(UIColor *)secondary surface:(UIColor *)surface current:(float)current;
@end

@implementation TSSliderCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (!self) return nil;
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    _titleLabel = [UILabel new];
    _titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    _valueLabel = [UILabel new];
    _valueLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
    _valueLabel.textAlignment = NSTextAlignmentRight;
    _chips = [UIStackView new];
    _chips.axis = UILayoutConstraintAxisHorizontal;
    _chips.spacing = 6;
    _chips.distribution = UIStackViewDistributionFillEqually;
    _slider = [UISlider new];
    [_slider addTarget:self action:@selector(moved) forControlEvents:UIControlEventValueChanged];
    [_slider addTarget:self action:@selector(ended) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside];
    for (UIView *view in @[_titleLabel, _valueLabel, _chips, _slider]) {
        view.translatesAutoresizingMaskIntoConstraints = YES;
        [self.contentView addSubview:view];
    }
    return self;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat width = CGRectGetWidth(self.contentView.bounds);
    CGFloat pad = 16;
    self.titleLabel.frame = CGRectMake(pad, 8, width - 120, 24);
    self.valueLabel.frame = CGRectMake(width - 96, 8, 80, 24);
    CGFloat y = 36;
    if (!self.chips.hidden) {
        self.chips.frame = CGRectMake(pad, y, width - pad * 2, 28);
        y = 70;
    }
    self.slider.frame = CGRectMake(pad, y, width - pad * 2, 32);
}
- (void)setChipValues:(NSArray<NSNumber *> *)values accent:(UIColor *)accent secondary:(UIColor *)secondary surface:(UIColor *)surface current:(float)current {
    for (UIView *view in self.chips.arrangedSubviews) [view removeFromSuperview];
    for (NSNumber *number in values) {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
        float value = number.floatValue;
        [button setTitle:[NSString stringWithFormat:@"%g×", value] forState:UIControlStateNormal];
        button.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
        button.layer.cornerRadius = 8;
        button.tag = (NSInteger)lrint(value * 100);
        BOOL selected = fabsf(current - value) < 0.02f;
        button.backgroundColor = selected ? accent : surface;
        [button setTitleColor:selected ? UIColor.whiteColor : secondary forState:UIControlStateNormal];
        [button addTarget:self action:@selector(chip:) forControlEvents:UIControlEventTouchUpInside];
        [self.chips addArrangedSubview:button];
    }
}
- (void)chip:(UIButton *)button {
    float value = button.tag / 100.0f;
    self.slider.value = value;
    if (self.onChange) self.onChange(value, NO);
}
- (void)moved {
    if (self.onChange) self.onChange(self.slider.value, YES);
}
- (void)ended {
    if (self.onChange) self.onChange(self.slider.value, NO);
}
@end

@interface TSColorCell : UITableViewCell
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *hexLabel;
@property (nonatomic, strong) UIColorWell *well;
@property (nonatomic, copy) void (^onChange)(UIColor *color);
@property (nonatomic, assign) BOOL suppress;
@end

@implementation TSColorCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (!self) return nil;
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    _titleLabel = [UILabel new];
    _titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    _hexLabel = [UILabel new];
    _hexLabel.font = [UIFont monospacedSystemFontOfSize:13 weight:UIFontWeightRegular];
    _well = [UIColorWell new];
    _well.supportsAlpha = NO;
    [_well addTarget:self action:@selector(changed) forControlEvents:UIControlEventValueChanged];
    for (UIView *view in @[_titleLabel, _hexLabel, _well]) [self.contentView addSubview:view];
    return self;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat width = CGRectGetWidth(self.contentView.bounds);
    self.well.frame = CGRectMake(width - 52, 13, 36, 32);
    self.titleLabel.frame = CGRectMake(16, 8, width - 80, 22);
    self.hexLabel.frame = CGRectMake(16, 30, width - 80, 18);
}
- (void)changed {
    if (self.suppress) return;
    self.hexLabel.text = [TSTheme hexForColor:self.well.selectedColor];
    if (self.onChange) self.onChange(self.well.selectedColor);
}
@end

@interface TSTextCell : UITableViewCell <UITextFieldDelegate>
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UITextField *field;
@property (nonatomic, copy) void (^onCommit)(NSString *text);
@end

@implementation TSTextCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (!self) return nil;
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    _titleLabel = [UILabel new];
    _titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    _field = [UITextField new];
    _field.delegate = self;
    _field.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
    _field.autocorrectionType = UITextAutocorrectionTypeNo;
    _field.returnKeyType = UIReturnKeyDone;
    _field.textAlignment = NSTextAlignmentRight;
    _field.font = [UIFont monospacedSystemFontOfSize:17 weight:UIFontWeightMedium];
    _field.placeholder = @"US";
    [_field addTarget:self action:@selector(ended) forControlEvents:UIControlEventEditingDidEnd];
    [self.contentView addSubview:_titleLabel];
    [self.contentView addSubview:_field];
    return self;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat width = CGRectGetWidth(self.contentView.bounds);
    self.titleLabel.frame = CGRectMake(16, 0, 140, CGRectGetHeight(self.contentView.bounds));
    self.field.frame = CGRectMake(160, 0, width - 176, CGRectGetHeight(self.contentView.bounds));
}
- (void)ended {
    if (self.onCommit) self.onCommit(self.field.text ?: @"");
}
- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}
@end

@interface TSPresetCard : UICollectionViewCell
@property (nonatomic, strong) UIView *preview;
@property (nonatomic, strong) UIView *surface;
@property (nonatomic, strong) UIView *dot;
@property (nonatomic, strong) UIView *lineOne;
@property (nonatomic, strong) UIView *lineTwo;
@property (nonatomic, strong) UILabel *nameLabel;
@end

@implementation TSPresetCard
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;
    _preview = [UIView new];
    _preview.layer.cornerRadius = 16;
    _surface = [UIView new];
    _surface.layer.cornerRadius = 10;
    _dot = [UIView new];
    _dot.layer.cornerRadius = 6;
    _lineOne = [UIView new];
    _lineOne.layer.cornerRadius = 2;
    _lineTwo = [UIView new];
    _lineTwo.layer.cornerRadius = 2;
    _nameLabel = [UILabel new];
    _nameLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
    _nameLabel.textAlignment = NSTextAlignmentCenter;
    for (UIView *view in @[_surface, _dot, _lineOne, _lineTwo]) [_preview addSubview:view];
    [self.contentView addSubview:_preview];
    [self.contentView addSubview:_nameLabel];
    return self;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat width = CGRectGetWidth(self.contentView.bounds);
    self.preview.frame = CGRectMake(0, 0, width, 112);
    self.nameLabel.frame = CGRectMake(0, 118, width, 18);
    self.surface.frame = CGRectInset(CGRectMake(0, 0, width, 78), 10, 0);
    self.surface.frame = CGRectMake(10, 22, width - 20, 70);
    self.dot.frame = CGRectMake(20, 34, 12, 12);
    self.lineOne.frame = CGRectMake(40, 36, width - 62, 6);
    self.lineTwo.frame = CGRectMake(40, 50, width - 86, 6);
}
- (void)showTheme:(TSTheme *)theme chrome:(TSTheme *)chrome selected:(BOOL)selected {
    self.preview.backgroundColor = theme.background;
    self.preview.layer.borderWidth = selected ? 2 : 1;
    self.preview.layer.borderColor = (selected ? chrome.accent : theme.separator).CGColor;
    self.surface.backgroundColor = theme.surface;
    self.dot.backgroundColor = theme.accent;
    self.lineOne.backgroundColor = theme.textPrimary;
    self.lineTwo.backgroundColor = theme.textSecondary;
    self.nameLabel.text = theme.name;
    self.nameLabel.textColor = chrome.textPrimary;
    self.accessibilityLabel = theme.name;
}
@end

@interface TSPresetCell : UITableViewCell <UICollectionViewDataSource, UICollectionViewDelegate>
@property (nonatomic, strong) UICollectionView *collection;
@property (nonatomic, copy) NSArray<TSTheme *> *themes;
@property (nonatomic, copy) NSString *selectedIdentifier;
@property (nonatomic, strong) TSTheme *chrome;
@property (nonatomic, copy) void (^onSelect)(TSTheme *theme);
@end

@implementation TSPresetCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (!self) return nil;
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    UICollectionViewFlowLayout *layout = [UICollectionViewFlowLayout new];
    layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
    layout.itemSize = CGSizeMake(108, 148);
    layout.minimumLineSpacing = 10;
    layout.sectionInset = UIEdgeInsetsMake(8, 16, 8, 16);
    _collection = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    _collection.backgroundColor = UIColor.clearColor;
    _collection.showsHorizontalScrollIndicator = NO;
    _collection.dataSource = self;
    _collection.delegate = self;
    [_collection registerClass:[TSPresetCard class] forCellWithReuseIdentifier:@"card"];
    [self.contentView addSubview:_collection];
    return self;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    self.collection.frame = self.contentView.bounds;
}
- (void)reloadThemes {
    NSMutableArray *themes = [[TSTheme presets] mutableCopy];
    NSDictionary *saved = [[TSPrefs shared] dictionaryForKey:TSKeyThemeCustom];
    TSTheme *custom = [TSTheme themeFromDictionary:saved error:nil];
    if (!custom) custom = [[TSTheme presetWithIdentifier:@"spice"] copyTheme];
    custom.identifier = @"custom";
    custom.name = @"Custom";
    [themes addObject:custom];
    self.themes = themes;
    [self.collection reloadData];
}
- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.themes.count;
}
- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    TSPresetCard *card = [collectionView dequeueReusableCellWithReuseIdentifier:@"card" forIndexPath:indexPath];
    TSTheme *theme = self.themes[indexPath.item];
    [card showTheme:theme chrome:self.chrome ?: theme selected:[theme.identifier isEqualToString:self.selectedIdentifier]];
    return card;
}
- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    TSTheme *theme = self.themes[indexPath.item];
    if (self.onSelect) self.onSelect(theme);
}
@end

#pragma mark - Settings

@interface TSSettingsViewController () <UISearchResultsUpdating, UIDocumentPickerDelegate>
@property (nonatomic, strong) UISearchController *search;
@property (nonatomic, copy) NSArray<TSSection *> *allSections;
@property (nonatomic, copy) NSArray<TSSection *> *visibleSections;
@end

@implementation TSSettingsViewController

+ (void)presentFromViewController:(UIViewController *)viewController {
    if (TSAlreadyShowing(self, viewController ?: TSTopViewController())) return;
    TSPresentSheet([self new], viewController);
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"TikSpice";
    self.navigationItem.backButtonTitle = @"Back";
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Close" style:UIBarButtonItemStylePlain target:self action:@selector(close)];
    self.search = [[UISearchController alloc] initWithSearchResultsController:nil];
    self.search.searchResultsUpdater = self;
    self.search.obscuresBackgroundDuringPresentation = NO;
    self.search.searchBar.placeholder = @"Search settings";
    self.navigationItem.searchController = self.search;
    self.navigationItem.hidesSearchBarWhenScrolling = NO;
    self.definesPresentationContext = YES;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 64;
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    [self.tableView registerClass:[TSToggleCell class] forCellReuseIdentifier:@"toggle"];
    [self.tableView registerClass:[TSSliderCell class] forCellReuseIdentifier:@"slider"];
    [self.tableView registerClass:[TSColorCell class] forCellReuseIdentifier:@"color"];
    [self.tableView registerClass:[TSTextCell class] forCellReuseIdentifier:@"text"];
    [self.tableView registerClass:[TSPresetCell class] forCellReuseIdentifier:@"preset"];
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"basic"];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(prefsChanged:) name:TSPrefsChangedNotification object:nil];
    TSPrivateHooksInstall();
    [self rebuild];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self applyTheme];
}

- (void)close {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)prefsChanged:(NSNotification *)note {
    NSString *key = note.userInfo[@"key"];
    if (!key || [key hasPrefix:@"theme."]) [self applyTheme];
    if (!key) [self rebuild];
}

- (void)applyTheme {
    TSStyleController(self);
    for (UITableViewCell *cell in self.tableView.visibleCells) {
        if ([cell isKindOfClass:[TSTextCell class]] && ((TSTextCell *)cell).field.isFirstResponder) continue;
        if ([cell isKindOfClass:[TSSliderCell class]] && ((TSSliderCell *)cell).slider.isTracking) continue;
        if ([cell isKindOfClass:[TSColorCell class]]) continue;
        NSIndexPath *path = [self.tableView indexPathForCell:cell];
        if (path) [self configureCell:cell at:path];
    }
}

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    [self applyFilter];
}

- (TSRow *)rowAt:(NSIndexPath *)path {
    if (path.section >= (NSInteger)self.visibleSections.count) return nil;
    TSSection *section = self.visibleSections[path.section];
    if (path.row >= (NSInteger)section.rows.count) return nil;
    return section.rows[path.row];
}

- (void)rebuild {
    self.allSections = [self makeSections];
    [self applyFilter];
}

- (void)applyFilter {
    NSString *query = [self.search.searchBar.text.lowercaseString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (query.length == 0) {
        self.visibleSections = self.allSections;
    } else {
        NSMutableArray *sections = [NSMutableArray array];
        for (TSSection *section in self.allSections) {
            NSMutableArray *rows = [NSMutableArray array];
            for (TSRow *row in section.rows) {
                if ([row.searchBlob containsString:query] || [section.title.lowercaseString containsString:query]) [rows addObject:row];
            }
            if (rows.count == 0) continue;
            TSSection *copy = [TSSection new];
            copy.title = section.title;
            copy.footer = section.footer;
            copy.rows = rows;
            [sections addObject:copy];
        }
        self.visibleSections = sections;
    }
    [self.tableView reloadData];
    if (self.visibleSections.count == 0) {
        UILabel *empty = [[UILabel alloc] initWithFrame:self.tableView.bounds];
        empty.text = @"No matching settings";
        empty.textAlignment = NSTextAlignmentCenter;
        empty.textColor = [TSTheme current].textSecondary;
        empty.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
        self.tableView.backgroundView = empty;
    } else {
        self.tableView.backgroundView = nil;
    }
    [self applyTheme];
}

- (NSArray<TSSection *> *)makeSections {
    TSSection *look = [TSSection new];
    look.title = @"Appearance";
    look.footer = @"Chrome paints tab and navigation bars. Video frames stay as TikTok drew them. Turning chrome off clears on the next launch.";
    TSRow *presets = [TSRow new];
    presets.kind = TSRowPreset;
    presets.title = @"Presets";
    presets.searchBlob = @"theme preset appearance color amoled pastel midnight ocean sunset clean spice custom accent";
    TSRow *radius = [TSRow new];
    radius.kind = TSRowSlider;
    radius.title = @"Corner radius";
    radius.prefKey = @"theme.radius";
    radius.sliderMin = 8;
    radius.sliderMax = 28;
    radius.searchBlob = @"corner radius theme";
    NSMutableArray *lookRows = [NSMutableArray arrayWithObject:presets];
    for (NSArray *spec in @[
        @[@"Accent", @"accent"],
        @[@"Background", @"background"],
        @[@"Surface", @"surface"],
        @[@"Primary text", @"textPrimary"],
        @[@"Secondary text", @"textSecondary"],
    ]) {
        TSRow *color = [TSRow new];
        color.kind = TSRowColor;
        color.title = spec[0];
        color.colorKey = spec[1];
        color.searchBlob = [spec[0] lowercaseString];
        [lookRows addObject:color];
    }
    [lookRows addObject:radius];
    [lookRows addObject:TSActionRow(@"Import theme", @"Pick a TikSpice JSON file.", @"square.and.arrow.down", ^(UIViewController *controller) {
        [(TSSettingsViewController *)controller importTheme];
    })];
    [lookRows addObject:TSActionRow(@"Export theme", @"Share the current theme as JSON.", @"square.and.arrow.up", ^(UIViewController *controller) {
        [(TSSettingsViewController *)controller exportTheme];
    })];
    [lookRows addObject:TSActionRow(@"Paste theme JSON", @"Read a theme from the clipboard.", @"doc.on.clipboard", ^(UIViewController *controller) {
        [(TSSettingsViewController *)controller pasteTheme];
    })];
    [lookRows addObject:TSToggleRow(@"Color the tab and nav bars", @"Apply surface and accent to bars.", @"paintbrush.fill", TSKeyThemeChrome)];
    [lookRows addObject:TSToggleRow(@"Tint icons with the accent", @"Window tint and switches follow the accent.", @"drop.fill", TSKeyThemeGlobalTint)];
    [lookRows addObject:TSToggleRow(@"Recolor lists", @"Experimental. List backgrounds pick up the theme. The player is left alone.", @"square.stack.3d.up", TSKeyThemeSurfaces)];
    look.rows = lookRows;

    TSSection *feed = [TSSection new];
    feed.title = @"Feed";
    feed.footer = [NSString stringWithFormat:@"Ads hook: %@. Hiding matches labels and class names, so a wrong guess only hides a small view.", [TSHookRegistry summaryForGroup:@"ads"]];
    feed.rows = @[
        TSActionRow(@"Quiet feed", @"Hide ads, LIVE, Shop, counts, stories, and the music ticker.", @"moon.fill", ^(UIViewController *controller) {
            [(TSSettingsViewController *)controller quietFeed];
        }),
        TSActionRow(@"Show feed chrome", @"Turn every hide toggle off.", @"sun.max.fill", ^(UIViewController *controller) {
            [(TSSettingsViewController *)controller showFeedChrome];
        }),
        TSToggleRow(@"Hide ads and sponsored", @"Sponsored labels, plus an ad flag when that class exists.", @"eye.slash", TSKeyHideAds),
        TSToggleRow(@"Hide LIVE", @"LIVE chips and known entrance views.", @"video.slash", TSKeyHideLive),
        TSToggleRow(@"Hide Shop tab", @"The Shop tab button, when its label matches.", @"bag", TSKeyHideShop),
        TSToggleRow(@"Hide upload button", @"Center plus button when its class name matches.", @"plus.circle", TSKeyHideUpload),
        TSToggleRow(@"Hide Friends tab", @"Tab labeled Friends or Now.", @"person.2", TSKeyHideFriends),
        TSToggleRow(@"Hide Inbox tab", @"Tab labeled Inbox.", @"tray", TSKeyHideInbox),
        TSToggleRow(@"Hide tab labels", @"Keeps the icons, clears the titles.", @"textformat", TSKeyHideTabLabels),
        TSToggleRow(@"Hide suggested accounts", @"Short labels that say suggested accounts.", @"person.crop.circle.badge.plus", TSKeyHideSuggested),
        TSToggleRow(@"Hide For You / Following", @"The top feed switch labels.", @"rectangle.grid.1x2", TSKeyHideFeedTabs),
        TSToggleRow(@"Hide story tray", @"Views whose class name contains StoryTray.", @"circle.grid.2x2", TSKeyHideStories),
        TSToggleRow(@"Hide music ticker", @"Views whose class name contains MusicInfo.", @"music.note", TSKeyHideMusicTicker),
    ];

    TSSection *counts = [TSSection new];
    counts.title = @"Counts";
    counts.footer = @"These look for short labels. A caption that merely mentions views is left visible.";
    counts.rows = @[
        TSToggleRow(@"Hide view counts", @"Short text containing “views”.", @"eye", TSKeyHideViewCounts),
        TSToggleRow(@"Hide like counts", @"Short text containing “likes”.", @"heart", TSKeyHideLikeCounts),
        TSToggleRow(@"Hide comment counts", @"Short text containing “comments”.", @"bubble.right", TSKeyHideCommentCounts),
        TSToggleRow(@"Hide share button", @"A compact control labeled Share.", @"square.and.arrow.up", TSKeyHideShareButton),
    ];

    TSSection *playback = [TSSection new];
    playback.title = @"Playback";
    playback.footer = [NSString stringWithFormat:@"Speed hooks AVPlayer. Holding the current video also swallows a full-page animated scroll for a moment. Private advance methods: %@.", [TSHookRegistry summaryForGroup:@"feed"]];
    TSRow *speed = [TSRow new];
    speed.kind = TSRowSlider;
    speed.title = @"Speed";
    speed.prefKey = TSKeyPlaybackSpeed;
    speed.sliderMin = 0.5f;
    speed.sliderMax = 3.f;
    speed.speedChips = YES;
    speed.searchBlob = @"playback speed 0.5 1.25 1.5 2 3";
    playback.rows = @[
        TSToggleRow(@"Custom playback speed", @"1× leaves TikTok in control.", @"speedometer", TSKeySpeedEnabled),
        speed,
        TSToggleRow(@"Loop the current video", @"Seek to the start when it ends.", @"repeat", TSKeyLoopVideo),
        TSToggleRow(@"Stay on the current video", @"Try not to advance when the video ends.", @"pause.circle", TSKeyDisableAutoScroll),
    ];

    TSSection *gestures = [TSSection new];
    gestures.title = @"Gestures";
    gestures.footer = @"Confirmation watches button labels and class names such as Like and Follow. Double-tap cancels double-taps on large views, which is how the heart animation is usually triggered.";
    gestures.rows = @[
        TSToggleRow(@"Confirm before like", nil, @"hand.raised", TSKeyConfirmLike),
        TSToggleRow(@"Confirm before follow", nil, @"person.badge.plus", TSKeyConfirmFollow),
        TSToggleRow(@"Confirm before comment", @"Post and Send buttons inside a comment view.", @"text.bubble", TSKeyConfirmComment),
        TSToggleRow(@"Confirm before share", nil, @"square.and.arrow.up", TSKeyConfirmShare),
        TSToggleRow(@"Disable double-tap to like", @"Cancels double-taps on large views.", @"hand.tap", TSKeyDisableDoubleTapLike),
    ];

    TSSection *saving = [TSSection new];
    saving.title = @"Saving";
    saving.footer = [NSString stringWithFormat:@"Save exports the playing asset. The private download-url swap is separate: %@.", [TSHookRegistry summaryForGroup:@"video"]];
    saving.rows = @[
        TSActionRow(@"Save current video", @"Write the playing video to Photos.", @"square.and.arrow.down", ^(__unused UIViewController *controller) {
            [TSDownload saveCurrentVideo];
        }),
        TSActionRow(@"Copy playback URL", @"Copy the player URL, when it has one.", @"link", ^(UIViewController *controller) {
            [TSDownload copyPlaybackURL];
        }),
        TSToggleRow(@"Prefer playback URL for downloads", @"Unverified. When a known download getter exists, return the play address instead.", @"link.circle", TSKeyPreferCleanURL),
    ];

    TSSection *region = [TSSection new];
    region.title = @"Region";
    region.footer = [NSString stringWithFormat:@"Unverified. %@ The code is used only when the original value is a string.", [TSHookRegistry summaryForGroup:@"region"]];
    TSRow *code = [TSRow new];
    code.kind = TSRowText;
    code.title = @"Region code";
    code.prefKey = TSKeyRegionCode;
    code.searchBlob = @"region code country feed";
    region.rows = @[
        TSToggleRow(@"Override region", @"Apply the code below to a matching getter.", @"globe", TSKeyRegionEnabled),
        code,
    ];

    TSSection *access = [TSSection new];
    access.title = @"Opening TikSpice";
    access.footer = @"The sparkle button can be dragged. Shake stays available so hiding the button does not lock you out.";
    access.rows = @[
        TSToggleRow(@"Floating button", @"A draggable sparkle over the app.", @"circle.circle", TSKeyShowFloater),
        TSToggleRow(@"Shake to open", @"Motion opens this panel.", @"iphone.radiowaves.left.and.right", TSKeyShakeToOpen),
        TSToggleRow(@"Haptics", @"Taps and confirms click.", @"waveform", TSKeyHaptics),
    ];

    TSSection *advanced = [TSSection new];
    advanced.title = @"Advanced";
    advanced.footer = [NSString stringWithFormat:@"TikSpice %@ · Preferences stay in this app under %@.", TSSpiceVersion, TSSuiteName];
    advanced.rows = @[
        TSActionRow(@"Hook status", @"Which private classes this build actually contains.", @"ladybug", ^(UIViewController *controller) {
            [controller.navigationController pushViewController:[TSHookStatusViewController new] animated:YES];
        }),
        TSToggleRow(@"Log view controllers", @"Print each screen class to the device log.", @"text.alignleft", TSKeyLogViewControllers),
        TSActionRow(@"Reset everything", @"Restore the Spice theme and turn features off.", @"arrow.counterclockwise", ^(UIViewController *controller) {
            [(TSSettingsViewController *)controller confirmReset];
        }),
    ];

    return @[look, feed, counts, playback, gestures, saving, region, access, advanced];
}

#pragma mark - Actions

- (void)importTheme {
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[UTTypeJSON, UTTypePlainText] asCopy:YES];
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSURL *url = urls.firstObject;
    if (!url) return;
    [url startAccessingSecurityScopedResource];
    NSData *data = [NSData dataWithContentsOfURL:url];
    [url stopAccessingSecurityScopedResource];
    [self importData:data];
}

- (void)pasteTheme {
    [self importData:[UIPasteboard.generalPasteboard.string dataUsingEncoding:NSUTF8StringEncoding]];
}

- (void)importData:(NSData *)data {
    NSError *error = nil;
    TSTheme *theme = [TSTheme themeFromJSONData:data error:&error];
    if (!theme) {
        TSPresentAlert(self, @"Could not import", error.localizedDescription ?: @"That is not a theme.");
        return;
    }
    [TSTheme saveCustomTheme:theme];
    TSHapticSuccess();
    [self rebuild];
}

- (void)exportTheme {
    TSTheme *theme = [TSTheme current];
    NSData *data = [theme jsonData];
    if (!data) return;
    NSCharacterSet *allowed = [NSCharacterSet alphanumericCharacterSet];
    NSString *safe = [[theme.name componentsSeparatedByCharactersInSet:[allowed invertedSet]] componentsJoinedByString:@"-"];
    if (safe.length == 0) safe = @"theme";
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"tikspice-%@.json", safe.lowercaseString]];
    [data writeToFile:path atomically:YES];
    UIActivityViewController *activity = [[UIActivityViewController alloc] initWithActivityItems:@[[NSURL fileURLWithPath:path]] applicationActivities:nil];
    activity.popoverPresentationController.sourceView = self.view;
    activity.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(self.view.bounds), 80, 1, 1);
    [self presentViewController:activity animated:YES completion:nil];
}

- (void)quietFeed {
    for (NSString *key in @[TSKeyHideAds, TSKeyHideLive, TSKeyHideShop, TSKeyHideSuggested, TSKeyHideViewCounts, TSKeyHideStories, TSKeyHideMusicTicker]) {
        [[TSPrefs shared] setBool:YES forKey:key];
    }
    TSHapticSuccess();
    [self rebuild];
}

- (void)showFeedChrome {
    for (NSString *key in TSHideKeys()) [[TSPrefs shared] setBool:NO forKey:key];
    TSHapticSuccess();
    [self rebuild];
}

- (void)confirmReset {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Reset TikSpice?" message:@"Themes and toggles return to their defaults." preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Reset" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) {
        [[TSPrefs shared] reset];
        [TSFloater install];
        TSHapticSuccess();
        [self rebuild];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)editColor:(UIColor *)color key:(NSString *)key {
    TSTheme *draft = [[TSTheme current] copyTheme];
    [draft setValue:color forKey:key];
    draft.name = @"Custom";
    [TSTheme saveCustomTheme:draft];
    TSHapticSelection();
}

- (void)editRadius:(float)value {
    TSTheme *draft = [[TSTheme current] copyTheme];
    draft.cornerRadius = value;
    draft.name = @"Custom";
    [TSTheme saveCustomTheme:draft];
}

#pragma mark - Table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.visibleSections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.visibleSections[section].rows.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return self.visibleSections[section].title;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return self.visibleSections[section].footer;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    TSRow *row = [self rowAt:indexPath];
    switch (row.kind) {
        case TSRowPreset: return 176;
        case TSRowSlider: return row.speedChips ? 124 : 84;
        case TSRowColor: return 58;
        case TSRowText: return 64;
        default: return UITableViewAutomaticDimension;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    TSRow *row = [self rowAt:indexPath];
    NSString *identifier = @"basic";
    switch (row.kind) {
        case TSRowToggle: identifier = @"toggle"; break;
        case TSRowSlider: identifier = @"slider"; break;
        case TSRowColor: identifier = @"color"; break;
        case TSRowPreset: identifier = @"preset"; break;
        case TSRowText: identifier = @"text"; break;
        default: break;
    }
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier forIndexPath:indexPath];
    [self configureCell:cell at:indexPath];
    return cell;
}

- (void)configureCell:(UITableViewCell *)cell at:(NSIndexPath *)indexPath {
    TSRow *row = [self rowAt:indexPath];
    TSTheme *theme = [TSTheme current];
    if ([cell isKindOfClass:[TSPresetCell class]]) {
        TSPresetCell *preset = (TSPresetCell *)cell;
        preset.chrome = theme;
        preset.selectedIdentifier = theme.identifier;
        preset.backgroundConfiguration = [self surfaceBackground:theme];
        [preset reloadThemes];
        __weak TSSettingsViewController *weakSelf = self;
        preset.onSelect = ^(TSTheme *picked) {
            [TSTheme selectPreset:picked];
            TSHapticSelection();
            [weakSelf applyTheme];
        };
        return;
    }
    if ([cell isKindOfClass:[TSToggleCell class]]) {
        TSToggleCell *toggle = (TSToggleCell *)cell;
        TSFillListCell(toggle, row.title, row.subtitle, row.symbol, theme, nil);
        toggle.toggle.onTintColor = theme.accent;
        toggle.toggle.on = TSBool(row.prefKey, [self fallbackForKey:row.prefKey]);
        __weak TSSettingsViewController *weakSelf = self;
        toggle.onChange = ^(UISwitch *sender, BOOL on) {
            [weakSelf toggle:row.prefKey on:on sender:sender];
        };
        return;
    }
    if ([cell isKindOfClass:[TSSliderCell class]]) {
        TSSliderCell *slider = (TSSliderCell *)cell;
        slider.backgroundConfiguration = [self surfaceBackground:theme];
        slider.titleLabel.textColor = theme.textPrimary;
        slider.valueLabel.textColor = theme.textSecondary;
        slider.slider.minimumTrackTintColor = theme.accent;
        slider.slider.minimumValue = row.sliderMin;
        slider.slider.maximumValue = row.sliderMax;
        slider.chips.hidden = !row.speedChips;
        if ([row.prefKey isEqualToString:TSKeyPlaybackSpeed]) {
            float value = TSFloat(TSKeyPlaybackSpeed, 1);
            slider.slider.value = value;
            slider.titleLabel.text = @"Speed";
            slider.valueLabel.text = [NSString stringWithFormat:@"%.2f×", value];
            [slider setChipValues:@[@0.5f, @1.f, @1.25f, @1.5f, @2.f, @3.f] accent:theme.accent secondary:theme.textSecondary surface:theme.surfaceElevated current:value];
            __weak TSSliderCell *weakSpeed = slider;
            slider.onChange = ^(float next, BOOL continuous) {
                [[TSPrefs shared] setFloat:next forKey:TSKeyPlaybackSpeed];
                TSSliderCell *cell = weakSpeed;
                cell.valueLabel.text = [NSString stringWithFormat:@"%.2f×", next];
                if (!continuous) {
                    TSTheme *live = [TSTheme current];
                    [cell setChipValues:@[@0.5f, @1.f, @1.25f, @1.5f, @2.f, @3.f] accent:live.accent secondary:live.textSecondary surface:live.surfaceElevated current:next];
                    TSHapticSelection();
                }
            };
        } else {
            float value = theme.cornerRadius;
            slider.slider.value = value;
            slider.titleLabel.text = @"Corner radius";
            slider.valueLabel.text = [NSString stringWithFormat:@"%.0f", value];
            __weak TSSettingsViewController *weakSelf = self;
            __weak TSSliderCell *weakRadius = slider;
            slider.onChange = ^(float next, BOOL continuous) {
                weakRadius.valueLabel.text = [NSString stringWithFormat:@"%.0f", next];
                if (!continuous) {
                    [weakSelf editRadius:next];
                    TSHapticSelection();
                }
            };
        }
        return;
    }
    if ([cell isKindOfClass:[TSColorCell class]]) {
        TSColorCell *colorCell = (TSColorCell *)cell;
        colorCell.backgroundConfiguration = [self surfaceBackground:theme];
        colorCell.titleLabel.textColor = theme.textPrimary;
        colorCell.hexLabel.textColor = theme.textSecondary;
        colorCell.titleLabel.text = row.title;
        UIColor *color = [theme valueForKey:row.colorKey];
        colorCell.suppress = YES;
        colorCell.well.selectedColor = color;
        colorCell.suppress = NO;
        colorCell.hexLabel.text = [TSTheme hexForColor:color];
        __weak TSSettingsViewController *weakSelf = self;
        NSString *key = row.colorKey;
        colorCell.onChange = ^(UIColor *next) {
            [weakSelf editColor:next key:key];
        };
        return;
    }
    if ([cell isKindOfClass:[TSTextCell class]]) {
        TSTextCell *textCell = (TSTextCell *)cell;
        textCell.backgroundConfiguration = [self surfaceBackground:theme];
        textCell.titleLabel.textColor = theme.textPrimary;
        textCell.field.textColor = theme.accent;
        textCell.titleLabel.text = row.title;
        if (!textCell.field.isFirstResponder) textCell.field.text = [[TSPrefs shared] stringForKey:row.prefKey];
        textCell.onCommit = ^(NSString *text) {
            NSString *trimmed = [[text uppercaseString] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if (trimmed.length > 8) trimmed = [trimmed substringToIndex:8];
            [[TSPrefs shared] setString:trimmed forKey:TSKeyRegionCode];
        };
        return;
    }
    TSFillListCell(cell, row.title, row.subtitle, row.symbol, theme, nil);
    cell.accessoryType = row.kind == TSRowAction ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;
    cell.selectionStyle = row.kind == TSRowAction ? UITableViewCellSelectionStyleDefault : UITableViewCellSelectionStyleNone;
}

- (UIBackgroundConfiguration *)surfaceBackground:(TSTheme *)theme {
    UIBackgroundConfiguration *background = [UIBackgroundConfiguration listGroupedCellConfiguration];
    background.backgroundColor = theme.surface;
    return background;
}

- (BOOL)fallbackForKey:(NSString *)key {
    if ([key isEqualToString:TSKeyShowFloater] || [key isEqualToString:TSKeyShakeToOpen] || [key isEqualToString:TSKeyHaptics]) return YES;
    return NO;
}

- (void)toggle:(NSString *)key on:(BOOL)on sender:(UISwitch *)sender {
    if ([key isEqualToString:TSKeyShowFloater] && !on && !TSBool(TSKeyShakeToOpen, YES)) {
        sender.on = YES;
        TSPresentAlert(self, @"Keep a way back in", @"Leave Shake to open on before hiding the button.");
        return;
    }
    if ([key isEqualToString:TSKeyShakeToOpen] && !on && !TSBool(TSKeyShowFloater, YES)) {
        sender.on = YES;
        TSPresentAlert(self, @"Keep a way back in", @"Show the floating button before turning shake off.");
        return;
    }
    [[TSPrefs shared] setBool:on forKey:key];
    TSHapticLight();
    if ([key isEqualToString:TSKeyShowFloater]) [TSFloater install];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    TSRow *row = [self rowAt:indexPath];
    if (row.action) row.action(self);
}

- (void)tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)view forSection:(NSInteger)section {
    if ([view isKindOfClass:[UITableViewHeaderFooterView class]]) {
        UITableViewHeaderFooterView *header = (UITableViewHeaderFooterView *)view;
        header.textLabel.textColor = [TSTheme current].textSecondary;
        header.textLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    }
}

- (void)tableView:(UITableView *)tableView willDisplayFooterView:(UIView *)view forSection:(NSInteger)section {
    if ([view isKindOfClass:[UITableViewHeaderFooterView class]]) {
        ((UITableViewHeaderFooterView *)view).textLabel.textColor = [TSTheme current].textSecondary;
    }
}

@end

#pragma mark - Hook status

@interface TSHookStatusViewController () <UISearchResultsUpdating>
@property (nonatomic, strong) UISearchController *search;
@property (nonatomic, copy) NSArray<TSSection *> *allSections;
@property (nonatomic, copy) NSArray<TSSection *> *visibleSections;
@end

@implementation TSHookStatusViewController

+ (void)presentFromViewController:(UIViewController *)viewController {
    if (TSAlreadyShowing(self, viewController ?: TSTopViewController())) return;
    TSPresentSheet([self new], viewController);
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Hook status";
    if (self.navigationController.viewControllers.firstObject == self) {
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Close" style:UIBarButtonItemStylePlain target:self action:@selector(close)];
    }
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(refresh)];
    self.search = [[UISearchController alloc] initWithSearchResultsController:nil];
    self.search.searchResultsUpdater = self;
    self.search.obscuresBackgroundDuringPresentation = NO;
    self.search.searchBar.placeholder = @"Search classes";
    self.navigationItem.searchController = self.search;
    self.navigationItem.hidesSearchBarWhenScrolling = NO;
    self.definesPresentationContext = YES;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 64;
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"basic"];
    [self refresh];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    TSStyleController(self);
}

- (void)close {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)refresh {
    TSPrivateHooksInstall();
    [self rebuild];
    TSStyleController(self);
}

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    [self applyFilter];
}

- (void)rebuild {
    NSMutableArray *sections = [NSMutableArray array];
    NSArray<TSHookResult *> *results = [TSHookRegistry results];
    NSInteger present = 0;
    for (TSHookResult *result in results) if (result.classPresent) present++;
    NSString *recent = [TSHookRegistry recentViewControllerNames].firstObject ?: @"Scroll the app, then refresh.";

    TSSection *overview = [TSSection new];
    overview.title = @"This process";
    overview.footer = @"Tap a row to copy the class name. Names here are unverified until they show up as present.";
    TSRow *summary = [TSRow new];
    summary.title = [NSString stringWithFormat:@"%ld of %ld classes present", (long)present, (long)results.count];
    summary.subtitle = @"Private names are skipped when the class or selector does not match.";
    summary.symbol = @"ladybug";
    summary.searchBlob = @"summary present classes";
    TSRow *front = [TSRow new];
    front.title = recent;
    front.subtitle = @"Most recent screen that is not plain UIKit.";
    front.symbol = @"rectangle.on.rectangle";
    front.searchBlob = recent.lowercaseString;
    overview.rows = @[summary, front];
    [sections addObject:overview];

    NSMutableArray *seen = [NSMutableArray array];
    for (NSString *name in [TSHookRegistry recentViewControllerNames]) {
        TSRow *row = [TSRow new];
        row.title = name;
        row.subtitle = @"Recent screen";
        row.searchBlob = name.lowercaseString;
        [seen addObject:row];
    }
    if (seen.count) {
        TSSection *recentSection = [TSSection new];
        recentSection.title = @"Recent screens";
        recentSection.footer = @"Open the screen you want to change, come back, and copy the class into HookRegistry.m.";
        recentSection.rows = seen;
        [sections addObject:recentSection];
    }

    NSArray *groups = @[@"ads", @"feed", @"video", @"region", @"live", @"shop", @"upload", @"story", @"music", @"settings", @"profile", @"interaction", @"player"];
    for (NSString *group in groups) {
        NSMutableArray *rows = [NSMutableArray array];
        for (TSHookResult *result in results) {
            if (![result.group isEqualToString:group]) continue;
            TSRow *row = [TSRow new];
            row.title = result.selectorName.length ? [NSString stringWithFormat:@"%@ %@", result.className, result.selectorName] : result.className;
            row.subtitle = [NSString stringWithFormat:@"%@ · %@", result.purpose ?: @"", result.status ?: @""];
            row.symbol = result.hooked ? @"checkmark.circle.fill" : (result.classPresent ? @"circle.fill" : @"circle");
            row.searchBlob = [[NSString stringWithFormat:@"%@ %@ %@ %@", result.className, result.selectorName, result.status, result.purpose] lowercaseString];
            row.prefKey = result.status;
            [rows addObject:row];
        }
        if (rows.count == 0) continue;
        TSSection *section = [TSSection new];
        section.title = group.capitalizedString;
        section.rows = rows;
        [sections addObject:section];
    }
    self.allSections = sections;
    [self applyFilter];
}

- (void)applyFilter {
    NSString *query = [self.search.searchBar.text.lowercaseString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (query.length == 0) {
        self.visibleSections = self.allSections;
    } else {
        NSMutableArray *sections = [NSMutableArray array];
        for (TSSection *section in self.allSections) {
            NSMutableArray *rows = [NSMutableArray array];
            for (TSRow *row in section.rows) {
                if ([row.searchBlob containsString:query] || [section.title.lowercaseString containsString:query]) [rows addObject:row];
            }
            if (rows.count == 0) continue;
            TSSection *copy = [TSSection new];
            copy.title = section.title;
            copy.footer = section.footer;
            copy.rows = rows;
            [sections addObject:copy];
        }
        self.visibleSections = sections;
    }
    [self.tableView reloadData];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return self.visibleSections.count; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return self.visibleSections[section].rows.count; }
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section { return self.visibleSections[section].title; }
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section { return self.visibleSections[section].footer; }

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"basic" forIndexPath:indexPath];
    TSRow *row = self.visibleSections[indexPath.section].rows[indexPath.row];
    TSTheme *theme = [TSTheme current];
    UIColor *detail = theme.textSecondary;
    if ([row.prefKey containsString:@"Hooked"] || [row.prefKey isEqualToString:@"Present"]) detail = theme.accent;
    else if ([row.prefKey containsString:@"mismatch"] || [row.prefKey containsString:@"not"]) detail = theme.destructive;
    TSFillListCell(cell, row.title, row.subtitle, row.symbol, theme, detail);
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    TSRow *row = self.visibleSections[indexPath.section].rows[indexPath.row];
    [UIPasteboard generalPasteboard].string = row.title;
    TSHapticSelection();
}

- (void)tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)view forSection:(NSInteger)section {
    if ([view isKindOfClass:[UITableViewHeaderFooterView class]]) {
        ((UITableViewHeaderFooterView *)view).textLabel.textColor = [TSTheme current].textSecondary;
    }
}

@end
