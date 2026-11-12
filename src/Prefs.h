#import <Foundation/Foundation.h>
#import "TSKeys.h"

@interface TSPrefs : NSObject
+ (instancetype)shared;
@property (nonatomic, readonly) NSUserDefaults *defaults;
- (BOOL)boolForKey:(NSString *)key fallback:(BOOL)fallback;
- (void)setBool:(BOOL)value forKey:(NSString *)key;
- (float)floatForKey:(NSString *)key fallback:(float)fallback;
- (void)setFloat:(float)value forKey:(NSString *)key;
- (NSString *)stringForKey:(NSString *)key;
- (void)setString:(NSString *)value forKey:(NSString *)key;
- (NSDictionary *)dictionaryForKey:(NSString *)key;
- (void)setDictionary:(NSDictionary *)value forKey:(NSString *)key;
- (void)reset;
@end

static inline BOOL TSBool(NSString *key, BOOL fallback) {
    return [[TSPrefs shared] boolForKey:key fallback:fallback];
}

static inline float TSFloat(NSString *key, float fallback) {
    return [[TSPrefs shared] floatForKey:key fallback:fallback];
}
