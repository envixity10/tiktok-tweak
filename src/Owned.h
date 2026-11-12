#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static inline void TSMarkOwned(id object) {
    if (!object) return;
    objc_setAssociatedObject(object, @selector(ts_tikspiceOwned), @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static inline BOOL TSIsOwnedObject(id object) {
    return object && objc_getAssociatedObject(object, @selector(ts_tikspiceOwned)) != nil;
}

static inline BOOL TSIsOwnedView(UIView *view) {
    for (UIView *cursor = view; cursor; cursor = cursor.superview) {
        if (TSIsOwnedObject(cursor)) return YES;
        if ([NSStringFromClass(cursor.class) hasPrefix:@"TS"]) return YES;
    }
    return NO;
}
