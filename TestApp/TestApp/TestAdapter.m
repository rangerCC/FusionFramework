//
//  TestAdapter.m
//  社交故事生成器
//

#import "TestAdapter.h"
#import <SocialStoryCore/SocialStoryCore.h>
#import "SafeARC.h"

@implementation TestAdapter

static TestAdapter *_TestAdapter_Instance = nil;

+ (TestAdapter *)getInstance {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _TestAdapter_Instance = [TestAdapter new];
    });
    return _TestAdapter_Instance;
}

- (UIViewController<IFusionPageProtocol> *)generateFusionPageController:(NSDictionary *)pageConfig {
    UIViewController<IFusionPageProtocol> *target =
        [[NSClassFromString([pageConfig valueForKey:@"class"]) alloc] initWithConfig:pageConfig];
    return SafeAutoRelease(target);
}

- (NSDictionary *)getPageConfig:(NSString *)pageName {
    // pageName -> controller class. Tab pages are singletons; others are fresh.
    NSDictionary *map = @{
        SSPageLibrary:      @{@"class": @"SSLibraryPageController",
                              @"tabbar_name": SSTabBarName, @"singleton": @YES},
        SSPageGenerate:     @{@"class": @"SSGeneratePageController",
                              @"tabbar_name": SSTabBarName, @"singleton": @YES},
        SSPageProfile:      @{@"class": @"SSProfilePageController",
                              @"tabbar_name": SSTabBarName, @"singleton": @YES},
        SSPageSettings:     @{@"class": @"SSSettingsPageController", @"singleton": @YES},
        SSPageLogin:        @{@"class": @"SSLoginPageController"},
        SSPageChildList:    @{@"class": @"SSChildListPageController", @"singleton": @YES},
        SSPageChildEdit:    @{@"class": @"SSChildEditPageController"},
        SSPageReader:       @{@"class": @"SSReaderPageController"},
        SSPageTemplate:     @{@"class": @"SSTemplatePageController"},
        SSPageSubscription: @{@"class": @"SSSubscriptionPageController"},
        SSPageHelp:         @{@"class": @"SSHelpPageController", @"singleton": @YES},
    };
    NSDictionary *base = map[pageName];
    if (!base) return nil;
    NSMutableDictionary *config = [NSMutableDictionary dictionaryWithDictionary:base];
    config[@"pageName"] = pageName;
    // Use the safe-area-aware navigation bar on all pages.
    config[@"navi_class"] = @"SSNaviBar";
    // Disable the framework's interactive left-edge swipe-back: every page has a
    // back button, and the gesture's manual-pop path crashes in garbageCollection
    // (nil page-nick key). Back is driven by the nav-bar button instead.
    config[@"no_gesture_navi"] = @YES;
    return config;
}

- (FusionTabBar *)generateFusionTabbar:(NSString *)tabbarName {
    FusionTabBar *tabBar = [[NSClassFromString(@"TestTabBar") alloc]
                            initWithConfig:@{@"tabbar_name": tabbarName}];
    return SafeAutoRelease(tabBar);
}

@end
