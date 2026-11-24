//
//  PCAdapter.m
//  PhotoCleaner
//

#import "PCAdapter.h"
#import <Utility/Utility.h>
#import <PhotoClean/PCLog.h>

static NSString *const kPageLoaderScript = @"PageLoader";

@implementation PCAdapter

+ (instancetype)sharedAdapter {
    static PCAdapter *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [PCAdapter new];
    });
    return instance;
}

- (NSDictionary *)queryPageLoader:(NSString *)method name:(NSString *)name {
    if (name.length == 0) return nil;
    id result = nil;
    BOOL ok = [[LuaRT standardLuaRT] callLuaScript:kPageLoaderScript
                                            method:method
                                              args:@[name]
                                        returnType:LuaRT_Table
                                         returnObj:&result];
    if (!ok || ![result isKindOfClass:[NSDictionary class]]) {
        PCLogWarn(@"PageLoader.%@(%@) returned no config", method, name);
        return nil;
    }
    return result;
}

#pragma mark - IFusionPageAdapterProtocol

- (UIViewController<IFusionPageProtocol> *)generateFusionPageController:(NSDictionary *)pageConfig {
    Class cls = NSClassFromString([pageConfig valueForKey:@"class"]);
    if (![cls conformsToProtocol:@protocol(IFusionPageProtocol)]) {
        PCLogError(@"Page class %@ does not conform to IFusionPageProtocol", [pageConfig valueForKey:@"class"]);
        return nil;
    }
    return [(UIViewController<IFusionPageProtocol> *)[cls alloc] initWithConfig:pageConfig];
}

- (NSDictionary *)getPageConfig:(NSString *)pageName {
    NSDictionary *luaConfig = [self queryPageLoader:@"queryPageByName" name:pageName];
    if (luaConfig == nil) return nil;
    // Lua pages use `name`; FusionUI expects `pageName`.
    NSMutableDictionary *config = [luaConfig mutableCopy];
    config[@"pageName"] = luaConfig[@"name"] ?: pageName;
    return config;
}

- (FusionTabBar *)generateFusionTabbar:(NSString *)tabbarName {
    NSDictionary *luaConfig = [self queryPageLoader:@"queryTabbarByName" name:tabbarName];
    NSString *className = luaConfig[@"class"] ?: tabbarName;
    Class cls = NSClassFromString(className);
    if (![cls isSubclassOfClass:[FusionTabBar class]]) {
        PCLogError(@"Tab bar class %@ is not a FusionTabBar", className);
        return nil;
    }
    NSMutableDictionary *config = [(luaConfig ?: @{}) mutableCopy];
    config[@"tabbar_name"] = tabbarName;
    return [[cls alloc] initWithConfig:config];
}

@end
