#import "HookRegistry.h"
#import "Prefs.h"
#import "TSKeys.h"
#import <objc/message.h>

// Logos' internal generator hooks with the Objective-C runtime. Private hooks
// do the same so the dylib has no CydiaSubstrate or ElleKit dependency.
static void TSReplaceMethod(Class cls, SEL selector, IMP replacement, IMP *original) {
    if (original) *original = NULL;
    if (!cls || !selector || !replacement) return;
    unsigned int count = 0;
    Method *methods = class_copyMethodList(cls, &count);
    for (unsigned int index = 0; index < count; index++) {
        if (method_getName(methods[index]) != selector) continue;
        if (original) *original = method_setImplementation(methods[index], replacement);
        free(methods);
        return;
    }
    free(methods);
}

typedef BOOL (*TSBoolIMP)(id, SEL);
typedef void (*TSVoidIMP)(id, SEL);
typedef id (*TSIdIMP)(id, SEL);

@interface TSSlot : NSObject {
@public
    IMP orig;
    SEL sel;
    SEL swap;
    TSHookKind kind;
}
@property (nonatomic, copy) NSString *prefKey;
@end

@implementation TSSlot
@end

static NSMutableArray<TSSlot *> *ts_slots;
static NSMutableSet<NSString *> *ts_hookedIdents;

static BOOL TSReturnMatches(const char *encoding, char expected) {
    if (!encoding || !encoding[0] || !expected) return NO;
    if (expected == 'B') return encoding[0] == 'B' || encoding[0] == 'c';
    return encoding[0] == expected;
}

static BOOL TSInstallOne(const TSHookSpec *spec, TSHookResult *result) {
    Class cls = objc_getClass(spec->className);
    SEL sel = sel_registerName(spec->selector);
    TSSlot *slot = [TSSlot new];
    slot->sel = sel;
    slot->kind = spec->kind;
    slot.prefKey = spec->prefKey ? @(spec->prefKey) : nil;
    if (spec->swapSelector) slot->swap = sel_registerName(spec->swapSelector);
    if (!ts_slots) ts_slots = [NSMutableArray array];
    [ts_slots addObject:slot];

    IMP replacement = NULL;
    if (spec->kind == TSHookKindBoolNO) {
        replacement = imp_implementationWithBlock(^BOOL(id selfObject) {
            if (slot.prefKey.length && TSBool(slot.prefKey, NO)) return NO;
            TSBoolIMP original = (TSBoolIMP)slot->orig;
            return original ? original(selfObject, slot->sel) : NO;
        });
    } else if (spec->kind == TSHookKindVoidSkip) {
        replacement = imp_implementationWithBlock(^(id selfObject) {
            if (slot.prefKey.length && TSBool(slot.prefKey, NO)) return;
            TSVoidIMP original = (TSVoidIMP)slot->orig;
            if (original) original(selfObject, slot->sel);
        });
    } else if (spec->kind == TSHookKindRegion || spec->kind == TSHookKindSwapPlay) {
        replacement = imp_implementationWithBlock(^id(id selfObject) {
            TSIdIMP original = (TSIdIMP)slot->orig;
            id value = original ? original(selfObject, slot->sel) : nil;
            if (slot->kind == TSHookKindRegion) {
                if (!TSBool(TSKeyRegionEnabled, NO)) return value;
                if (![value isKindOfClass:[NSString class]]) return value;
                NSString *code = [[[TSPrefs shared] stringForKey:TSKeyRegionCode] uppercaseString];
                if (code.length == 0) return value;
                return code;
            }
            if (slot.prefKey.length == 0 || !TSBool(slot.prefKey, NO) || !slot->swap) return value;
            if (![selfObject respondsToSelector:slot->swap]) return value;
            id play = ((id (*)(id, SEL))objc_msgSend)(selfObject, slot->swap);
            if (!play) return value;
            if (value && [play class] != [value class]) return value;
            return play;
        });
    }

    if (!replacement) {
        result.status = @"No installer for this kind";
        return NO;
    }
    TSReplaceMethod(cls, sel, replacement, &slot->orig);
    return slot->orig != NULL;
}

void TSPrivateHooksInstall(void) {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            TSPrivateHooksInstall();
        });
        return;
    }

    static BOOL installing = NO;
    if (installing) return;
    installing = YES;

    if (!ts_hookedIdents) ts_hookedIdents = [NSMutableSet set];
    NSUInteger count = 0;
    const TSHookSpec *specs = TSHookSpecs(&count);
    NSSet<NSString *> *known = [NSSet setWithArray:TSAllPreferenceKeys()];
    NSMutableArray<TSHookResult *> *results = [NSMutableArray arrayWithCapacity:count];

    for (NSUInteger index = 0; index < count; index++) {
        const TSHookSpec *spec = &specs[index];
        TSHookResult *result = [TSHookResult new];
        result.ident = spec->ident ? @(spec->ident) : @"";
        result.group = spec->group ? @(spec->group) : @"";
        result.className = spec->className ? @(spec->className) : @"";
        result.selectorName = spec->selector ? @(spec->selector) : @"";
        result.purpose = spec->purpose ? @(spec->purpose) : @"";
        result.prefKey = spec->prefKey ? @(spec->prefKey) : @"";
        result.kind = spec->kind;
        result.unverified = spec->unverified != 0;
        if (spec->prefKey && ![known containsObject:result.prefKey]) {
            NSLog(@"[TikSpice] unknown preference key in registry: %s", spec->prefKey);
        }

        Class cls = objc_getClass(spec->className);
        if (!cls) {
            result.status = @"Class not in this build";
            [results addObject:result];
            continue;
        }
        result.classPresent = YES;

        if (spec->kind == TSHookKindProbe || spec->selector == NULL) {
            result.status = @"Present";
            [results addObject:result];
            continue;
        }

        SEL selector = sel_registerName(spec->selector);
        if (![TSHookRegistry class:cls implementsSelector:selector]) {
            result.status = @"Selector not implemented on this class";
            [results addObject:result];
            continue;
        }
        Method method = class_getInstanceMethod(cls, selector);
        const char *encoding = method ? method_getTypeEncoding(method) : NULL;
        if (!TSReturnMatches(encoding, spec->returnType)) {
            result.status = [NSString stringWithFormat:@"Return type mismatch (%s)", encoding ?: "?"];
            [results addObject:result];
            continue;
        }
        if (spec->kind == TSHookKindSwapPlay) {
            SEL swap = spec->swapSelector ? sel_registerName(spec->swapSelector) : NULL;
            Method swapMethod = swap ? class_getInstanceMethod(cls, swap) : NULL;
            const char *swapEncoding = swapMethod ? method_getTypeEncoding(swapMethod) : NULL;
            if (!swap || ![TSHookRegistry class:cls implementsSelector:swap] || !TSReturnMatches(swapEncoding, '@')) {
                result.status = @"Play-address selector does not match";
                [results addObject:result];
                continue;
            }
        }

        if ([ts_hookedIdents containsObject:result.ident]) {
            result.hooked = YES;
            result.status = @"Hooked";
            [results addObject:result];
            continue;
        }
        if (TSInstallOne(spec, result)) {
            [ts_hookedIdents addObject:result.ident];
            result.hooked = YES;
            result.status = @"Hooked";
        } else if (result.status.length == 0) {
            result.status = @"Hook failed";
        }
        [results addObject:result];
    }

    [TSHookRegistry replaceResults:results];
    installing = NO;
}
