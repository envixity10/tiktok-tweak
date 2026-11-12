#import <Foundation/Foundation.h>
#import <objc/runtime.h>

typedef NS_ENUM(NSInteger, TSHookKind) {
    TSHookKindProbe = 0,
    TSHookKindBoolNO = 1,
    TSHookKindVoidSkip = 2,
    TSHookKindRegion = 3,
    TSHookKindSwapPlay = 4,
};

// One row in the private-API table. Edit src/HookRegistry.m to retarget a
// TikTok build. The loader hooks a row only when that class implements the
// selector itself and the return type matches, so a stale name is skipped.
typedef struct {
    const char *ident;
    const char *group;
    const char *className;
    const char *selector;
    const char *swapSelector;
    const char *prefKey;
    const char *purpose;
    char returnType;
    TSHookKind kind;
    int unverified;
} TSHookSpec;

FOUNDATION_EXPORT const TSHookSpec *TSHookSpecs(NSUInteger *count);
FOUNDATION_EXPORT void TSPrivateHooksInstall(void);

@interface TSHookResult : NSObject
@property (nonatomic, copy) NSString *ident;
@property (nonatomic, copy) NSString *group;
@property (nonatomic, copy) NSString *className;
@property (nonatomic, copy) NSString *selectorName;
@property (nonatomic, copy) NSString *purpose;
@property (nonatomic, copy) NSString *prefKey;
@property (nonatomic, copy) NSString *status;
@property (nonatomic, assign) TSHookKind kind;
@property (nonatomic, assign) BOOL unverified;
@property (nonatomic, assign) BOOL hooked;
@property (nonatomic, assign) BOOL classPresent;
@end

@interface TSHookRegistry : NSObject
+ (void)replaceResults:(NSArray<TSHookResult *> *)results;
+ (NSArray<TSHookResult *> *)results;
+ (NSArray<NSString *> *)classNamesInGroup:(NSString *)group;
+ (BOOL)class:(Class)cls implementsSelector:(SEL)selector;
+ (BOOL)shouldOfferSettingsButtonForClass:(NSString *)className;
+ (void)noteViewControllerClass:(NSString *)className;
+ (NSArray<NSString *> *)recentViewControllerNames;
+ (NSString *)summaryForGroup:(NSString *)group;
@end
