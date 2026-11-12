#import <UIKit/UIKit.h>

@interface TSTheme : NSObject
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, strong) UIColor *accent;
@property (nonatomic, strong) UIColor *background;
@property (nonatomic, strong) UIColor *surface;
@property (nonatomic, strong) UIColor *surfaceElevated;
@property (nonatomic, strong) UIColor *textPrimary;
@property (nonatomic, strong) UIColor *textSecondary;
@property (nonatomic, strong) UIColor *separator;
@property (nonatomic, strong) UIColor *destructive;
@property (nonatomic, assign) CGFloat cornerRadius;

+ (NSArray<TSTheme *> *)presets;
+ (TSTheme *)presetWithIdentifier:(NSString *)identifier;
+ (TSTheme *)current;
+ (void)selectPreset:(TSTheme *)preset;
+ (void)saveCustomTheme:(TSTheme *)theme;
+ (TSTheme *)themeFromDictionary:(NSDictionary *)dictionary error:(NSError **)error;
+ (TSTheme *)themeFromJSONData:(NSData *)data error:(NSError **)error;
- (NSData *)jsonData;
- (NSDictionary *)dictionary;
- (TSTheme *)copyTheme;
+ (UIColor *)colorFromHex:(NSString *)hex;
+ (NSString *)hexForColor:(UIColor *)color;
@end
