//
//  SSSegmentTabBar.h
//  StoryLibrary
//
//  Custom top tab bar: equal-width title buttons with a sliding underline
//  indicator under the selected tab.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SSSegmentTabBar : UIView

- (instancetype)initWithTitles:(NSArray<NSString *> *)titles;

/// Currently selected tab. Setting this animates the underline.
@property (nonatomic, assign) NSInteger selectedIndex;

/// Fired when the user taps a tab (not when set programmatically).
@property (nonatomic, copy, nullable) void (^onSelect)(NSInteger index);

@end

NS_ASSUME_NONNULL_END
