//
//  SSUITool.m
//  Utility
//
//  Created by Eva on 2026/6/3.
//

#import "SSUITool.h"

@implementation SSUITool

+ (BOOL)isNotchScreen {
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

@end
