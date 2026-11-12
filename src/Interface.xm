#import "Tweak.h"
#import <objc/runtime.h>

static BOOL ts_bypass = NO;
static BOOL ts_confirming = NO;

static BOOL TSIsCompact(UIView *view) {
    CGSize size = view.bounds.size;
    return size.width > 0 && size.width <= 200 && size.height > 0 && size.height <= 90;
}

static BOOL TSAncestorContains(UIView *view, NSString *needle) {
    NSInteger depth = 0;
    for (UIView *cursor = view; cursor && depth < 16; cursor = cursor.superview, depth++) {
        if ([NSStringFromClass(cursor.class).lowercaseString containsString:needle]) return YES;
    }
    return NO;
}

static NSString *TSButtonTitle(UIView *view) {
    if (![view isKindOfClass:[UIButton class]]) return @"";
    return [(UIButton *)view currentTitle].lowercaseString ?: @"";
}

static BOOL TSIsLikeControl(UIView *view) {
    if (!TSBool(TSKeyConfirmLike, NO)) return NO;
    NSString *cls = NSStringFromClass(view.class).lowercaseString;
    if ([cls containsString:@"tabbar"]) return NO;
    if ([cls containsString:@"dislike"]) return NO;
    if ([cls containsString:@"like"] || [cls containsString:@"digg"]) return YES;
    if (!TSIsCompact(view)) return NO;
    NSString *label = view.accessibilityLabel.lowercaseString ?: @"";
    NSString *title = TSButtonTitle(view);
    return [label isEqualToString:@"like"] || [label isEqualToString:@"liked"] || [title isEqualToString:@"like"] || [title isEqualToString:@"liked"];
}

static BOOL TSIsFollowControl(UIView *view) {
    if (!TSBool(TSKeyConfirmFollow, NO)) return NO;
    NSString *cls = NSStringFromClass(view.class).lowercaseString;
    if ([cls containsString:@"tabbar"]) return NO;
    if ([cls containsString:@"followbutton"]) return YES;
    if (!TSIsCompact(view)) return NO;
    NSString *label = view.accessibilityLabel.lowercaseString ?: @"";
    NSString *title = TSButtonTitle(view);
    return [label isEqualToString:@"follow"] || [title isEqualToString:@"follow"];
}

static BOOL TSIsShareControl(UIView *view) {
    if (!TSBool(TSKeyConfirmShare, NO)) return NO;
    NSString *cls = NSStringFromClass(view.class).lowercaseString;
    if ([cls containsString:@"tabbar"]) return NO;
    if ([cls containsString:@"sharebutton"]) return YES;
    if (!TSIsCompact(view)) return NO;
    return [view.accessibilityLabel.lowercaseString isEqualToString:@"share"];
}

static BOOL TSIsCommentSend(UIView *view) {
    if (!TSBool(TSKeyConfirmComment, NO)) return NO;
    NSString *cls = NSStringFromClass(view.class).lowercaseString;
    if ([cls containsString:@"commentpost"] || [cls containsString:@"commentpublish"] || [cls containsString:@"postcomment"]) return YES;
    if (!TSIsCompact(view)) return NO;
    NSString *label = view.accessibilityLabel.lowercaseString ?: @"";
    NSString *title = TSButtonTitle(view);
    BOOL send = [label isEqualToString:@"post"] || [label isEqualToString:@"send"] || [title isEqualToString:@"post"] || [title isEqualToString:@"send"];
    return send && TSAncestorContains(view, @"comment");
}

static void TSAsk(NSString *title, NSString *message, void (^yes)(void)) {
    if (ts_confirming) return;
    UIViewController *host = TSTopViewController();
    if (!host) return;
    ts_confirming = YES;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(__unused UIAlertAction *action) {
        ts_confirming = NO;
    }]];
    UIAlertAction *confirm = [UIAlertAction actionWithTitle:@"Confirm" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        ts_confirming = NO;
        if (yes) yes();
    }];
    [alert addAction:confirm];
    alert.preferredAction = confirm;
    TSHapticWarning();
    [host presentViewController:alert animated:YES completion:nil];
}

static BOOL TSShouldSwallowScroll(UIScrollView *scrollView, CGFloat deltaY, CGFloat deltaX, BOOL animated) {
    if (!animated || !TSShouldBlockAutoAdvance() || TSIsOwnedView(scrollView) || !scrollView.pagingEnabled) return NO;
    CGFloat height = scrollView.bounds.size.height;
    if (height < 200) return NO;
    return deltaY > height * 0.55 && deltaY < height * 1.6 && deltaX < 48;
}

%hook UIControl

- (void)sendAction:(SEL)action to:(id)target forEvent:(UIEvent *)event {
    if (ts_bypass || TSIsOwnedView(self) || ![NSThread isMainThread] ||
        [self isKindOfClass:[UISwitch class]] || [self isKindOfClass:[UISlider class]] ||
        [self isKindOfClass:[UITextField class]] || [self isKindOfClass:[UISegmentedControl class]] ||
        [self isKindOfClass:[UIStepper class]] || [self isKindOfClass:[UIPageControl class]]) {
        %orig;
        return;
    }

    NSString *title = nil;
    NSString *message = nil;
    if (TSIsLikeControl(self)) {
        title = @"Like this video?";
        message = @"Confirm before the like goes through.";
    } else if (TSIsFollowControl(self)) {
        title = @"Follow this account?";
        message = @"Confirm before the follow goes through.";
    } else if (TSIsShareControl(self)) {
        title = @"Share this video?";
        message = @"Confirm before sharing.";
    } else if (TSIsCommentSend(self)) {
        title = @"Post this comment?";
        message = @"Confirm before the comment is sent.";
    }
    if (!title) {
        %orig;
        return;
    }

    __weak UIControl *weakControl = self;
    SEL act = action;
    id tgt = target;
    TSAsk(title, message, ^{
        UIControl *strongControl = weakControl;
        if (!strongControl) return;
        ts_bypass = YES;
        [strongControl sendAction:act to:tgt forEvent:nil];
        ts_bypass = NO;
    });
}

%end

%hook UIScrollView

- (void)setContentOffset:(CGPoint)contentOffset animated:(BOOL)animated {
    CGFloat dy = fabs(contentOffset.y - self.contentOffset.y);
    CGFloat dx = fabs(contentOffset.x - self.contentOffset.x);
    if (TSShouldSwallowScroll(self, dy, dx, animated)) return;
    %orig;
}

- (void)scrollRectToVisible:(CGRect)rect animated:(BOOL)animated {
    CGFloat dy = fabs(CGRectGetMinY(rect) - self.contentOffset.y);
    CGFloat dx = fabs(CGRectGetMinX(rect) - self.contentOffset.x);
    if (TSShouldSwallowScroll(self, dy, dx, animated)) return;
    %orig;
}

%end

%hook UITapGestureRecognizer

- (void)setState:(UIGestureRecognizerState)state {
    if (state == UIGestureRecognizerStateRecognized &&
        self.numberOfTapsRequired >= 2 &&
        TSBool(TSKeyDisableDoubleTapLike, NO) &&
        !TSIsOwnedView(self.view) &&
        self.view.bounds.size.width > 120 &&
        self.view.bounds.size.height > 120) {
        %orig(UIGestureRecognizerStateCancelled);
        return;
    }
    %orig;
}

%end

%hook UITabBar

- (void)setItems:(NSArray<UITabBarItem *> *)items animated:(BOOL)animated {
    BOOL hideLabels = TSBool(TSKeyHideTabLabels, NO);
    for (UITabBarItem *item in items) {
        NSString *saved = objc_getAssociatedObject(item, @selector(ts_originalTitle));
        if (!saved) {
            saved = item.title ?: @"";
            objc_setAssociatedObject(item, @selector(ts_originalTitle), saved, OBJC_ASSOCIATION_COPY_NONATOMIC);
        }
        if (hideLabels) item.title = @"";
        else item.title = saved;
    }
    %orig;
    if (TSBool(TSKeyThemeChrome, NO) || TSBool(TSKeyThemeGlobalTint, NO)) {
        self.tintColor = [TSTheme current].accent;
    }
}

%end

%hook UIViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    NSString *name = NSStringFromClass(self.class);
    if ([name hasPrefix:@"TS"]) return;
    if (TSBool(TSKeyLogViewControllers, NO)) NSLog(@"[TikSpice] %@", name);
    [TSHookRegistry noteViewControllerClass:name];
    [TSEntry considerViewController:self];
    static CFTimeInterval lastHooks = 0;
    CFTimeInterval now = CFAbsoluteTimeGetCurrent();
    if (now - lastHooks > 2.0) {
        lastHooks = now;
        TSPrivateHooksInstall();
    }
    TSScannerScanIfNeeded();
}

%end

