//
//  SSUITool.h
//  Utility
//
//  Created by Eva on 2026/6/3.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// 判断是否为刘海屏（iPhone X 及以上全面屏）
#define isHaveBangScreen \
({\
    BOOL isBang = NO;\
    if (@available(iOS 11.0, *)) {\
        UIWindow *mainWindow = [UIApplication sharedApplication].keyWindow;\
        if (mainWindow.safeAreaInsets.bottom > 0) {\
            isBang = YES;\
        }\
    }\
    isBang;\
})

@interface SSUITool : NSObject

@end

NS_ASSUME_NONNULL_END
