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
        SSPageSettings:     @{@"class": @"SSSettingsPageController",
                              @"tabbar_name": SSTabBarName, @"singleton": @YES},
        SSPageReader:       @{@"class": @"SSReaderPageController"},
        SSPageTemplate:     @{@"class": @"SSTemplatePageController"},
        SSPageSubscription: @{@"class": @"SSSubscriptionPageController"},
        SSPageHelp:         @{@"class": @"SSHelpPageController"},
    };
    NSDictionary *base = map[pageName];
    if (!base) return nil;
    NSMutableDictionary *config = [NSMutableDictionary dictionaryWithDictionary:base];
    config[@"pageName"] = pageName;
    // Use the safe-area-aware navigation bar on all pages.
    config[@"navi_class"] = @"SSNaviBar";
    return config;
}

- (FusionTabBar *)generateFusionTabbar:(NSString *)tabbarName {
    FusionTabBar *tabBar = [[NSClassFromString(@"TestTabBar") alloc]
                            initWithConfig:@{@"tabbar_name": tabbarName}];
    return SafeAutoRelease(tabBar);
}

@end
