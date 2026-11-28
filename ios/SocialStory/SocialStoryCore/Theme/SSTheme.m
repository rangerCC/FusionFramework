//
//  SSTheme.m
//  SocialStoryCore
//

#import "SSTheme.h"

@implementation SSTheme

+ (UIColor *)accentColor {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *tc) {
        if (tc.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor colorWithRed:1.0 green:0.62 blue:0.40 alpha:1.0];
        }
        return [UIColor colorWithRed:0.95 green:0.45 blue:0.22 alpha:1.0];
    }];
}

+ (UIColor *)backgroundColor {
    return [UIColor systemBackgroundColor];
}

+ (UIColor *)cardColor {
    return [UIColor secondarySystemBackgroundColor];
}

+ (UIColor *)primaryTextColor {
    return [UIColor labelColor];
}

+ (UIColor *)secondaryTextColor {
    return [UIColor secondaryLabelColor];
}

+ (CGFloat)defaultBodyFontSize { return 18.0; }
+ (CGFloat)minBodyFontSize { return 14.0; }
+ (CGFloat)maxBodyFontSize { return 32.0; }

@end
