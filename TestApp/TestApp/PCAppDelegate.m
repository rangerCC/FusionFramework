//
//  PCAppDelegate.m
//  PhotoCleaner
//

#import "PCAppDelegate.h"
#import <FusionCore/FusionCore.h>
#import <PhotoClean/PCLog.h>
#import "PCFusionConfig.h"

@implementation PCAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    PCLogSetup();
    [PCFusionConfig installBundledConfigIfNeeded];
    [[FusionCore getInstance] prepareWithConfig:[PCFusionConfig sharedConfig]];
    return YES;
}

- (UISceneConfiguration *)application:(UIApplication *)application
configurationForConnectingSceneSession:(UISceneSession *)connectingSceneSession
                              options:(UISceneConnectionOptions *)options {
    return [[UISceneConfiguration alloc] initWithName:@"Default Configuration" sessionRole:connectingSceneSession.role];
}

@end
