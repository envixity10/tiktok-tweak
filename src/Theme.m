#import "Theme.h"
#import "Prefs.h"

@implementation TSTheme

+ (UIColor *)colorFromHex:(NSString *)hex {
    if (![hex isKindOfClass:[NSString class]]) return nil;
    NSString *raw = [[hex stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] uppercaseString];
    if ([raw hasPrefix:@"#"]) raw = [raw substringFromIndex:1];
    if (raw.length == 3 || raw.length == 4) {
        NSMutableString *expanded = [NSMutableString string];
        for (NSUInteger i = 0; i < raw.length; i++) {
            unichar c = [raw characterAtIndex:i];
            [expanded appendFormat:@"%C%C", c, c];
        }
        raw = expanded;
    }
    if (raw.length != 6 && raw.length != 8) return nil;
    unsigned long long value = 0;
    NSScanner *scanner = [NSScanner scannerWithString:raw];
    if (![scanner scanHexLongLong:&value] || !scanner.isAtEnd) return nil;
    CGFloat alpha = 1.0;
    if (raw.length == 8) {
        alpha = (value & 0xFF) / 255.0;
        value >>= 8;
    }
    CGFloat red = ((value >> 16) & 0xFF) / 255.0;
    CGFloat green = ((value >> 8) & 0xFF) / 255.0;
    CGFloat blue = (value & 0xFF) / 255.0;
    return [UIColor colorWithRed:red green:green blue:blue alpha:alpha];
}

+ (NSString *)hexForColor:(UIColor *)color {
    if (!color) return @"#000000";
    UIColor *resolved = [color resolvedColorWithTraitCollection:UITraitCollection.currentTraitCollection];
    CGFloat red = 0, green = 0, blue = 0, alpha = 1;
    if (![resolved getRed:&red green:&green blue:&blue alpha:&alpha]) {
        CGFloat white = 0;
        if ([resolved getWhite:&white alpha:&alpha]) {
            red = green = blue = white;
        }
    }
    int ri = (int)lrint(fmax(0, fmin(1, red)) * 255.0);
    int gi = (int)lrint(fmax(0, fmin(1, green)) * 255.0);
    int bi = (int)lrint(fmax(0, fmin(1, blue)) * 255.0);
    int ai = (int)lrint(fmax(0, fmin(1, alpha)) * 255.0);
    if (ai < 255) return [NSString stringWithFormat:@"#%02X%02X%02X%02X", ri, gi, bi, ai];
    return [NSString stringWithFormat:@"#%02X%02X%02X", ri, gi, bi];
}

+ (TSTheme *)themeWithIdentifier:(NSString *)identifier
                            name:(NSString *)name
                           hexes:(NSDictionary<NSString *, NSString *> *)hexes
                          radius:(CGFloat)radius {
    TSTheme *theme = [TSTheme new];
    theme.identifier = identifier;
    theme.name = name;
    theme.accent = [self colorFromHex:hexes[@"accent"]];
    theme.background = [self colorFromHex:hexes[@"background"]];
    theme.surface = [self colorFromHex:hexes[@"surface"]];
    theme.surfaceElevated = [self colorFromHex:hexes[@"surfaceElevated"]];
    theme.textPrimary = [self colorFromHex:hexes[@"textPrimary"]];
    theme.textSecondary = [self colorFromHex:hexes[@"textSecondary"]];
    theme.separator = [self colorFromHex:hexes[@"separator"]];
    theme.destructive = [self colorFromHex:hexes[@"destructive"]];
    theme.cornerRadius = radius;
    return theme;
}

+ (NSArray<TSTheme *> *)presets {
    return @[
        [self themeWithIdentifier:@"spice" name:@"Spice" hexes:@{
            @"accent": @"#FE2C55",
            @"background": @"#101010",
            @"surface": @"#1A1A1A",
            @"surfaceElevated": @"#242424",
            @"textPrimary": @"#FFFFFF",
            @"textSecondary": @"#A3A3A3",
            @"separator": @"#2A2A2A",
            @"destructive": @"#FF453A"
        } radius:16],
        [self themeWithIdentifier:@"amoled" name:@"AMOLED" hexes:@{
            @"accent": @"#FF375F",
            @"background": @"#000000",
            @"surface": @"#000000",
            @"surfaceElevated": @"#0C0C0C",
            @"textPrimary": @"#F5F5F7",
            @"textSecondary": @"#8D8D93",
            @"separator": @"#1A1A1A",
            @"destructive": @"#FF453A"
        } radius:18],
        [self themeWithIdentifier:@"midnight" name:@"Midnight" hexes:@{
            @"accent": @"#7AA2FF",
            @"background": @"#0B1020",
            @"surface": @"#141A2E",
            @"surfaceElevated": @"#1C243D",
            @"textPrimary": @"#E8EEFF",
            @"textSecondary": @"#9AA6C3",
            @"separator": @"#2A3350",
            @"destructive": @"#FF6B6B"
        } radius:16],
        [self themeWithIdentifier:@"ocean" name:@"Ocean" hexes:@{
            @"accent": @"#2DD4BF",
            @"background": @"#061416",
            @"surface": @"#0C1F22",
            @"surfaceElevated": @"#123033",
            @"textPrimary": @"#E7FFFB",
            @"textSecondary": @"#8FB8B4",
            @"separator": @"#1A3A3E",
            @"destructive": @"#FF6B6B"
        } radius:18],
        [self themeWithIdentifier:@"sunset" name:@"Sunset" hexes:@{
            @"accent": @"#FF8A5B",
            @"background": @"#1A0F0C",
            @"surface": @"#2A1814",
            @"surfaceElevated": @"#3A221C",
            @"textPrimary": @"#FFF4EF",
            @"textSecondary": @"#C9A79A",
            @"separator": @"#4A2E26",
            @"destructive": @"#FF6B6B"
        } radius:18],
        [self themeWithIdentifier:@"pastel" name:@"Pastel" hexes:@{
            @"accent": @"#C77DFF",
            @"background": @"#F7F2FF",
            @"surface": @"#FFFFFF",
            @"surfaceElevated": @"#F3E8FF",
            @"textPrimary": @"#2D2140",
            @"textSecondary": @"#7A6B8A",
            @"separator": @"#E6DCF5",
            @"destructive": @"#E35D6A"
        } radius:20],
        [self themeWithIdentifier:@"clean" name:@"Clean" hexes:@{
            @"accent": @"#0095F6",
            @"background": @"#FAFAFA",
            @"surface": @"#FFFFFF",
            @"surfaceElevated": @"#FFFFFF",
            @"textPrimary": @"#262626",
            @"textSecondary": @"#8E8E8E",
            @"separator": @"#DBDBDB",
            @"destructive": @"#ED4956"
        } radius:12],
    ];
}

+ (TSTheme *)presetWithIdentifier:(NSString *)identifier {
    for (TSTheme *preset in [self presets]) {
        if ([preset.identifier isEqualToString:identifier]) return preset;
    }
    return nil;
}

+ (TSTheme *)baseTheme {
    return [self presetWithIdentifier:@"spice"];
}

- (TSTheme *)copyTheme {
    TSTheme *copy = [TSTheme new];
    copy.identifier = self.identifier;
    copy.name = self.name;
    copy.accent = self.accent;
    copy.background = self.background;
    copy.surface = self.surface;
    copy.surfaceElevated = self.surfaceElevated;
    copy.textPrimary = self.textPrimary;
    copy.textSecondary = self.textSecondary;
    copy.separator = self.separator;
    copy.destructive = self.destructive;
    copy.cornerRadius = self.cornerRadius;
    return copy;
}

- (NSDictionary *)dictionary {
    return @{
        @"format": @"tikspice-theme",
        @"version": @1,
        @"identifier": self.identifier ?: @"custom",
        @"name": self.name ?: @"Custom",
        @"accent": [TSTheme hexForColor:self.accent],
        @"background": [TSTheme hexForColor:self.background],
        @"surface": [TSTheme hexForColor:self.surface],
        @"surfaceElevated": [TSTheme hexForColor:self.surfaceElevated],
        @"textPrimary": [TSTheme hexForColor:self.textPrimary],
        @"textSecondary": [TSTheme hexForColor:self.textSecondary],
        @"separator": [TSTheme hexForColor:self.separator],
        @"destructive": [TSTheme hexForColor:self.destructive],
        @"cornerRadius": @(self.cornerRadius)
    };
}

- (NSData *)jsonData {
    return [NSJSONSerialization dataWithJSONObject:[self dictionary]
                                           options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys
                                             error:nil];
}

+ (NSError *)themeError:(NSString *)message {
    return [NSError errorWithDomain:@"com.tikspice.theme" code:1 userInfo:@{NSLocalizedDescriptionKey: message ?: @"Invalid theme"}];
}

+ (TSTheme *)themeFromDictionary:(NSDictionary *)dict error:(NSError **)error {
    if (![dict isKindOfClass:[NSDictionary class]]) {
        if (error) *error = [self themeError:@"Theme JSON must be an object."];
        return nil;
    }
    id format = dict[@"format"];
    if (format && ![format isEqual:@"tikspice-theme"]) {
        if (error) *error = [self themeError:@"This JSON is not a TikSpice theme."];
        return nil;
    }
    NSArray<NSString *> *colorKeys = @[@"accent", @"background", @"surface", @"surfaceElevated", @"textPrimary", @"textSecondary", @"separator", @"destructive"];
    BOOL anyColor = NO;
    for (NSString *key in colorKeys) {
        if ([dict[key] isKindOfClass:[NSString class]]) anyColor = YES;
    }
    if (!anyColor && !dict[@"cornerRadius"]) {
        if (error) *error = [self themeError:@"Add at least one color, such as accent or background."];
        return nil;
    }
    TSTheme *theme = [[self baseTheme] copyTheme];
    theme.identifier = @"custom";
    theme.name = [dict[@"name"] isKindOfClass:[NSString class]] && [dict[@"name"] length] ? dict[@"name"] : @"Custom";
    for (NSString *key in colorKeys) {
        id value = dict[key];
        if (!value) continue;
        if (![value isKindOfClass:[NSString class]]) {
            if (error) *error = [self themeError:[NSString stringWithFormat:@"%@ should be a hex color.", key]];
            return nil;
        }
        UIColor *color = [self colorFromHex:value];
        if (!color) {
            if (error) *error = [self themeError:[NSString stringWithFormat:@"%@ is not a hex color.", key]];
            return nil;
        }
        [theme setValue:color forKey:key];
    }
    if ([dict[@"cornerRadius"] isKindOfClass:[NSNumber class]]) {
        CGFloat radius = [dict[@"cornerRadius"] doubleValue];
        theme.cornerRadius = fmax(8, fmin(28, radius));
    }
    return theme;
}

+ (TSTheme *)themeFromJSONData:(NSData *)data error:(NSError **)error {
    if (data.length == 0) {
        if (error) *error = [self themeError:@"The theme file is empty."];
        return nil;
    }
    NSError *parseError = nil;
    id object = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError];
    if (!object) {
        if (error) *error = parseError ?: [self themeError:@"Could not read that JSON."];
        return nil;
    }
    return [self themeFromDictionary:object error:error];
}

+ (TSTheme *)current {
    NSString *identifier = [[TSPrefs shared] stringForKey:TSKeyThemePreset];
    if (identifier.length == 0) identifier = @"spice";
    if ([identifier isEqualToString:@"custom"]) {
        NSDictionary *saved = [[TSPrefs shared] dictionaryForKey:TSKeyThemeCustom];
        TSTheme *custom = [self themeFromDictionary:saved error:nil];
        if (custom) return custom;
    }
    return [self presetWithIdentifier:identifier] ?: [self baseTheme];
}

+ (void)selectPreset:(TSTheme *)preset {
    if (preset.identifier.length == 0) return;
    if ([preset.identifier isEqualToString:@"custom"]) {
        TSTheme *existing = [self themeFromDictionary:[[TSPrefs shared] dictionaryForKey:TSKeyThemeCustom] error:nil];
        [self saveCustomTheme:existing ?: [[self baseTheme] copyTheme]];
        return;
    }
    [[TSPrefs shared] setString:preset.identifier forKey:TSKeyThemePreset];
}

+ (void)saveCustomTheme:(TSTheme *)theme {
    TSTheme *stored = [theme copyTheme];
    stored.identifier = @"custom";
    if (stored.name.length == 0) stored.name = @"Custom";
    stored.cornerRadius = fmax(8, fmin(28, stored.cornerRadius));
    [[TSPrefs shared] setDictionary:[stored dictionary] forKey:TSKeyThemeCustom];
    [[TSPrefs shared] setString:@"custom" forKey:TSKeyThemePreset];
}

@end
