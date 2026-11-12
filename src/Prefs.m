#import "Prefs.h"

@implementation TSPrefs

+ (instancetype)shared {
    static TSPrefs *prefs;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        prefs = [TSPrefs new];
    });
    return prefs;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _defaults = [[NSUserDefaults alloc] initWithSuiteName:TSSuiteName];
    }
    return self;
}

- (BOOL)boolForKey:(NSString *)key fallback:(BOOL)fallback {
    id value = [self.defaults objectForKey:key];
    if (value == nil) return fallback;
    return [self.defaults boolForKey:key];
}

- (void)setBool:(BOOL)value forKey:(NSString *)key {
    [self.defaults setBool:value forKey:key];
    [self publishKey:key];
}

- (float)floatForKey:(NSString *)key fallback:(float)fallback {
    id value = [self.defaults objectForKey:key];
    if (value == nil) return fallback;
    return [self.defaults floatForKey:key];
}

- (void)setFloat:(float)value forKey:(NSString *)key {
    [self.defaults setFloat:value forKey:key];
    [self publishKey:key];
}

- (NSString *)stringForKey:(NSString *)key {
    id value = [self.defaults objectForKey:key];
    return [value isKindOfClass:[NSString class]] ? value : nil;
}

- (void)setString:(NSString *)value forKey:(NSString *)key {
    if (value) [self.defaults setObject:value forKey:key];
    else [self.defaults removeObjectForKey:key];
    [self publishKey:key];
}

- (NSDictionary *)dictionaryForKey:(NSString *)key {
    id value = [self.defaults objectForKey:key];
    return [value isKindOfClass:[NSDictionary class]] ? value : nil;
}

- (void)setDictionary:(NSDictionary *)value forKey:(NSString *)key {
    if (value) [self.defaults setObject:value forKey:key];
    else [self.defaults removeObjectForKey:key];
    [self publishKey:key];
}

- (void)reset {
    [self.defaults removePersistentDomainForName:TSSuiteName];
    [self.defaults synchronize];
    [self publishKey:nil];
}

- (void)publishKey:(NSString *)key {
    [self.defaults synchronize];
    NSDictionary *info = key ? @{@"key": key} : nil;
    [[NSNotificationCenter defaultCenter] postNotificationName:TSPrefsChangedNotification object:nil userInfo:info];
}

@end
