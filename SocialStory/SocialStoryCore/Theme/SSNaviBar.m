//
//  SSNaviBar.m
//  SocialStoryCore
//

#import "SSNaviBar.h"
#import <Utility/SSUITool.h>

static const CGFloat kSSNaviBarContentHeight = 44.0;

@implementation SSNaviBar

- (CGFloat)safeTopInset {
    CGFloat top = 0.0;
    if (@available(iOS 11.0, *)) {
        top = self.safeAreaInsets.top;
        if (top <= 0.0) {
            // Before this bar is in the hierarchy, fall back to the key window.
            UIWindow *window = nil;
            for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
                if ([scene isKindOfClass:[UIWindowScene class]]) {
                    for (UIWindow *w in ((UIWindowScene *)scene).windows) {
                        if (w.isKeyWindow) { window = w; break; }
                    }
                }
            }
            top = window ? window.safeAreaInsets.top : 0.0;
        }
    }
    // Status-bar fallback for non-notched devices.
    if (top <= 0.0) { top = 20.0; }
    return top;
}

- (CGFloat)getNaviBarHeight {
    // Landscape keeps a compact bar; portrait reserves room for the notch.
    if (self.superview.frame.size.width > self.superview.frame.size.height) {
        return kSSNaviBarContentHeight;
    }
    return [self safeTopInset] + kSSNaviBarContentHeight;
}

- (void)layoutSubviews {
    // Re-layout with a safe-area-aware top offset instead of the hardcoded 20pt.
    CGFloat topOffset = isHaveBangScreen ? [self safeTopInset] : 0.0;
    CGFloat h = self.frame.size.height - topOffset;

    if (self.leftView) {
        self.leftView.frame = CGRectMake(0, topOffset, self.leftViewWidth, h);
    }
    if (self.centerView) {
        self.centerView.frame = CGRectMake(self.leftViewWidth, topOffset,
                                           self.frame.size.width - self.leftViewWidth - self.rightViewWidth, h);
    }
    if (self.rightView) {
        self.rightView.frame = CGRectMake(self.frame.size.width - self.rightViewWidth, topOffset,
                                          self.rightViewWidth, h);
    }
}

@end
