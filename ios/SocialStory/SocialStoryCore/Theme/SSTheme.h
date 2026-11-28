//
//  SSTheme.h
//  SocialStoryCore
//
//  Dark-mode-aware colors and shared font sizes.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SSTheme : NSObject

/// Warm accent color (buttons, highlights).
+ (UIColor *)accentColor;
/// Primary page background.
+ (UIColor *)backgroundColor;
/// Card / cell background.
+ (UIColor *)cardColor;
/// Primary text.
+ (UIColor *)primaryTextColor;
/// Secondary / subtitle text.
+ (UIColor *)secondaryTextColor;

/// Default body font size used by the reader.
+ (CGFloat)defaultBodyFontSize;
+ (CGFloat)minBodyFontSize;
+ (CGFloat)maxBodyFontSize;

@end

NS_ASSUME_NONNULL_END
