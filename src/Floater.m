#import "Floater.h"
#import "SettingsUI.h"
#import "Theme.h"
#import "Prefs.h"
#import "Owned.h"
#import "UIUtil.h"
#import "Download.h"

@interface TSFloaterView : UIView
@property (nonatomic, strong) UIVisualEffectView *blur;
@property (nonatomic, strong) UIView *wash;
@property (nonatomic, strong) UIImageView *icon;
@property (nonatomic, assign) BOOL dragging;
@end

@implementation TSFloaterView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;
    self.accessibilityLabel = @"TikSpice";
    self.isAccessibilityElement = YES;
    self.exclusiveTouch = YES;
    TSMarkOwned(self);

    self.layer.shadowColor = UIColor.blackColor.CGColor;
    self.layer.shadowOpacity = 0.22f;
    self.layer.shadowRadius = 10;
    self.layer.shadowOffset = CGSizeMake(0, 4);

    _blur = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterial]];
    _blur.userInteractionEnabled = NO;
    _blur.clipsToBounds = YES;
    [self addSubview:_blur];

    _wash = [UIView new];
    _wash.userInteractionEnabled = NO;
    [_blur.contentView addSubview:_wash];

    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:20 weight:UIImageSymbolWeightSemibold];
    _icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"sparkles" withConfiguration:config]];
    _icon.contentMode = UIViewContentModeCenter;
    [_blur.contentView addSubview:_icon];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapped)];
    UILongPressGestureRecognizer *press = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(pressed:)];
    press.minimumPressDuration = 0.4;
    [tap requireGestureRecognizerToFail:press];
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panned:)];
    [self addGestureRecognizer:tap];
    [self addGestureRecognizer:press];
    [self addGestureRecognizer:pan];
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.blur.frame = self.bounds;
    self.blur.layer.cornerRadius = self.bounds.size.width / 2.0;
    self.wash.frame = self.blur.bounds;
    self.icon.frame = self.blur.bounds;
    self.layer.shadowPath = [UIBezierPath bezierPathWithOvalInRect:self.bounds].CGPath;
}

- (void)applyTheme {
    TSTheme *theme = [TSTheme current];
    self.icon.tintColor = theme.accent;
    self.wash.backgroundColor = [theme.accent colorWithAlphaComponent:0.18];
    self.blur.layer.borderColor = [theme.accent colorWithAlphaComponent:0.85].CGColor;
    self.blur.layer.borderWidth = 1;
}

- (void)tapped {
    if (self.dragging) return;
    TSHapticLight();
    [TSFloater openSettings];
}

- (void)pressed:(UILongPressGestureRecognizer *)press {
    if (press.state != UIGestureRecognizerStateBegan) return;
    TSHapticSelection();
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"TikSpice" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Settings" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [TSFloater openSettings];
        });
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Save video" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [TSDownload saveCurrentVideo];
        });
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Copy playback URL" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [TSDownload copyPlaybackURL];
        });
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Hook status" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [TSHookStatusViewController presentFromViewController:TSTopViewController()];
        });
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Hide button" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *action) {
        if (!TSBool(TSKeyShakeToOpen, YES)) {
            TSPresentAlert(nil, @"Keep a way back in", @"Leave Shake to open on, then hide the button.");
            return;
        }
        [[TSPrefs shared] setBool:NO forKey:TSKeyShowFloater];
        TSPresentAlert(nil, @"Button hidden", @"Shake the phone to open TikSpice.");
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    UIViewController *host = TSTopViewController();
    sheet.popoverPresentationController.sourceView = self;
    sheet.popoverPresentationController.sourceRect = self.bounds;
    [host presentViewController:sheet animated:YES completion:nil];
}

- (void)panned:(UIPanGestureRecognizer *)pan {
    UIView *container = self.superview;
    if (!container) return;
    CGPoint translation = [pan translationInView:container];
    if (pan.state == UIGestureRecognizerStateBegan) {
        self.dragging = YES;
        if (!TSReduceMotion()) {
            [UIView animateWithDuration:0.18 animations:^{
                self.transform = CGAffineTransformMakeScale(1.06, 1.06);
            }];
        }
    }
    if (pan.state == UIGestureRecognizerStateChanged) {
        self.center = CGPointMake(self.center.x + translation.x, self.center.y + translation.y);
        [pan setTranslation:CGPointZero inView:container];
    }
    if (pan.state == UIGestureRecognizerStateEnded || pan.state == UIGestureRecognizerStateCancelled) {
        self.dragging = NO;
        [self snapAndSave];
    }
}

- (void)snapAndSave {
    UIView *container = self.superview;
    if (!container) return;
    CGRect bounds = container.bounds;
    UIEdgeInsets safe = container.safeAreaInsets;
    CGFloat half = CGRectGetWidth(self.bounds) / 2.0;
    CGFloat margin = 10;
    CGFloat mid = CGRectGetMidX(bounds);
    CGFloat x = self.center.x < mid ? safe.left + margin + half : CGRectGetWidth(bounds) - safe.right - margin - half;
    CGFloat minY = safe.top + margin + half;
    CGFloat maxY = CGRectGetHeight(bounds) - safe.bottom - margin - half;
    CGFloat y = MIN(MAX(self.center.y, minY), maxY);
    CGPoint center = CGPointMake(x, y);
    void (^save)(void) = ^{
        if (CGRectGetWidth(bounds) < 1 || CGRectGetHeight(bounds) < 1) return;
        [[TSPrefs shared] setFloat:center.x / CGRectGetWidth(bounds) forKey:TSKeyFloaterX];
        [[TSPrefs shared] setFloat:center.y / CGRectGetHeight(bounds) forKey:TSKeyFloaterY];
    };
    if (TSReduceMotion()) {
        self.transform = CGAffineTransformIdentity;
        self.center = center;
        save();
        return;
    }
    [UIView animateWithDuration:0.55 delay:0 usingSpringWithDamping:0.78 initialSpringVelocity:0.4 options:UIViewAnimationOptionAllowUserInteraction animations:^{
        self.transform = CGAffineTransformIdentity;
        self.center = center;
    } completion:^(__unused BOOL finished) {
        save();
    }];
}

- (void)placeDefaultIfNeeded {
    UIView *container = self.superview;
    if (!container || self.dragging) return;
    CGRect bounds = container.bounds;
    if (CGRectGetWidth(bounds) < 1) return;
    CGFloat nx = TSFloat(TSKeyFloaterX, 0.08f);
    CGFloat ny = TSFloat(TSKeyFloaterY, 0.28f);
    self.center = CGPointMake(nx * CGRectGetWidth(bounds), ny * CGRectGetHeight(bounds));
}

@end

@implementation TSFloater

static TSFloaterView *ts_floater;
static BOOL ts_welcomed;

+ (void)load {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(prefsChanged:) name:TSPrefsChangedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(install) name:UISceneDidActivateNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(install) name:UIWindowDidBecomeKeyNotification object:nil];
}

+ (void)prefsChanged:(NSNotification *)note {
    NSString *key = note.userInfo[@"key"];
    if ([key isEqualToString:TSKeyFloaterX] || [key isEqualToString:TSKeyFloaterY]) return;
    if (!key || [key hasPrefix:@"entry."] || [key hasPrefix:@"theme."]) [self install];
}

+ (void)install {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self installOnMainAttempt:0];
    });
}

+ (void)installOnMainAttempt:(NSInteger)attempt {
    UIWindow *window = TSKeyWindow();
    if (!TSBool(TSKeyShowFloater, YES)) {
        [ts_floater removeFromSuperview];
        return;
    }
    if (!window) {
        if (attempt < 40) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self installOnMainAttempt:attempt + 1];
            });
        }
        return;
    }
    if (!ts_floater) ts_floater = [[TSFloaterView alloc] initWithFrame:CGRectMake(0, 0, 48, 48)];
    if (ts_floater.superview != window) {
        [ts_floater removeFromSuperview];
        [window addSubview:ts_floater];
        [ts_floater placeDefaultIfNeeded];
    }
    [window bringSubviewToFront:ts_floater];
    [ts_floater applyTheme];
    if (!ts_welcomed) {
        ts_welcomed = YES;
        if (!TSReduceMotion()) {
            ts_floater.alpha = 0;
            ts_floater.transform = CGAffineTransformMakeScale(0.7, 0.7);
            [UIView animateWithDuration:0.7 delay:0.05 usingSpringWithDamping:0.72 initialSpringVelocity:0.4 options:UIViewAnimationOptionAllowUserInteraction animations:^{
                ts_floater.alpha = 1;
                ts_floater.transform = CGAffineTransformIdentity;
            } completion:nil];
        }
    }
}

+ (void)openSettings {
    UIViewController *host = TSTopViewController();
    if ([host isKindOfClass:[UIAlertController class]]) host = host.presentingViewController ?: host;
    [TSSettingsViewController presentFromViewController:host];
}

+ (void)installAccessoryOnViewController:(UIViewController *)controller {
    if (!controller.navigationController) return;
    for (UIBarButtonItem *item in controller.navigationItem.rightBarButtonItems) {
        if ([item.accessibilityLabel isEqualToString:@"TikSpice"]) return;
    }
    UIImage *image = [UIImage systemImageNamed:@"sparkles"];
    UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithImage:image style:UIBarButtonItemStylePlain target:self action:@selector(openSettings)];
    item.accessibilityLabel = @"TikSpice";
    NSMutableArray *items = [controller.navigationItem.rightBarButtonItems mutableCopy] ?: [NSMutableArray array];
    [items addObject:item];
    controller.navigationItem.rightBarButtonItems = items;
}

@end
