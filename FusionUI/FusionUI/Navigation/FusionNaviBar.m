//
//  FusionNavigationBar.m
//  FusionUI
//
//  Created by Ryou Zhang on 1/12/15.
//  Copyright (c) 2015 Ryou Zhang. All rights reserved.
//

#import "FusionNaviBar.h"
#import "SafeARC.h"

#define Default_NavibarItem_Width   60

@implementation FusionNaviBar
@synthesize leftView = _leftView, centerView = _centerView, rightView = _rightView;
@synthesize leftViewWidth = _leftViewWidth, rightViewWidth = _rightViewWidth;
- (instancetype)init {
    self = [super init];
    if (self) {
        _leftViewWidth = Default_NavibarItem_Width;
        _rightViewWidth = Default_NavibarItem_Width;
    }
    return self;
}

- (id)initWithConfig:(NSDictionary *)config {
    self = [super init];
    if (self) {
        _config = SafeRetain(config);
        
        _leftViewWidth = Default_NavibarItem_Width;
        _rightViewWidth = Default_NavibarItem_Width;
    }
    return self;
}

- (CGFloat)getNaviBarHeight {
    if (self.superview.frame.size.width > self.superview.frame.size.height) {
        return 44.0;
    }
    return [self safeTopInset] + 44.0;
}

// 状态栏 / 安全区顶部内边距。iOS 11+ 用 safeAreaInsets.top
// （刘海屏 44/47/59pt，非刘海 20pt）；更早版本回退到 20pt。
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

- (void)setLeftView:(UIView *)leftView {
    if (_leftView) {
        [_leftView removeFromSuperview];
        SafeRelease(_leftView);
    }
    _leftView = SafeRetain(leftView);
    [self addSubview:_leftView];
    [self setNeedsLayout];
}

- (void)setRightView:(UIView *)rightView {
    if (_rightView) {
        [_rightView removeFromSuperview];
        SafeRelease(_rightView);
    }
    _rightView = SafeRetain(rightView);
    [self addSubview:_rightView];
    [self setNeedsLayout];
}

- (void)setCenterView:(UIView *)centerView {
    if (_centerView) {
        [_centerView removeFromSuperview];
        SafeRelease(_centerView);
    }
    _centerView = SafeRetain(centerView);
    [self addSubview:_centerView];
    [self setNeedsLayout];
}

- (void)layoutSubviews {
    [super layoutSubviews];

    CGFloat topOffset = [self isNotchScreen] ? [self safeTopInset] : 0.0;
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

- (BOOL)isNotchScreen {
    // iPad直接返回NO
    if ([[UIDevice currentDevice] userInterfaceIdiom] != UIUserInterfaceIdiomPhone) {
        return NO;
    }
    if (@available(iOS 11.0, *)) {
        UIWindow *window = [UIApplication sharedApplication].windows.firstObject;
        if (!window) return NO;
        if(window.safeAreaInsets.bottom <= 0) return NO;
        
        // iOS16区分灵动岛
        if (@available(iOS 16.0, *)) {
            CGFloat topInset = window.safeAreaInsets.top;
            // top≈44=刘海，top≈59=灵动岛
            return topInset < 50;
        }
        return YES;
    }
    return NO;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    SafeRelease(_leftView);
    SafeRelease(_centerView);
    SafeRelease(_rightView);
    SafeRelease(_config);
    SafeSuperDealloc(super);
}
@end
