//
//  AppDelegate.m
//  TestApp
//
//  Created by Ryou Zhang on 1/12/15.
//  Copyright (c) 2015 Ryou Zhang. All rights reserved.
//

#import "AppDelegate.h"
#import "TestAdapter.h"
#import <FusionUI/FusionUI.h>
#import <FusionUI/FusionPageNavigator+Auto.h>
#import <SocialStoryCore/SocialStoryCore.h>
#import <SocialStoryCore/SocialStoryCore-Swift.h>

@interface AppDelegate () {
@private
    FusionPageNavigator *_navigator;
}
@end

@implementation AppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Warm up the store and subscription status.
    [SSStoryStore shared];
    [[SubscriptionManager shared] refreshSubscriptionStatusWithCompletion:nil];

    // Featured stories: seed from bundled demos on first launch (offline-ready),
    // then pull the server list (ETag-cached; refreshes the library if changed).
    [[SSStoryDB shared] seedFeaturedIfEmpty:[SSDemoStories allStories]];
    [[SSFeaturedStoryClient shared] refreshWithCompletion:nil];

    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    _navigator = [FusionPageNavigator new];
    [_navigator.view setBackgroundColor:[SSTheme backgroundColor]];
    [_navigator setRewriter:nil];
    [_navigator setAdapter:[TestAdapter getInstance]];
    [self.window setRootViewController:_navigator];
    [self.window makeKeyAndVisible];

    FusionPageMessage *message = [[FusionPageMessage alloc] initWithPageName:SSPageLibrary
                                                                    pageNick:nil
                                                                     command:@"init"
                                                                        args:nil
                                                                    callback:nil];
    [_navigator gotoPage:message];

    // Register device with server on first launch (async, non-blocking).
    [self registerDeviceIfNeeded];

    return YES;
}

- (void)registerDeviceIfNeeded {
    NSString *key = @"ss_device_registered";
    if ([[NSUserDefaults standardUserDefaults] boolForKey:key]) { return; }

    // Read AccountBaseURL from LocalConfig.plist; fall back to localhost.
    NSString *baseURL = @"http://localhost:8080";
    NSString *path = [[NSBundle mainBundle] pathForResource:@"LocalConfig" ofType:@"plist"];
    NSDictionary *config = path ? [NSDictionary dictionaryWithContentsOfFile:path] : nil;
    if (config[@"AccountBaseURL"]) { baseURL = config[@"AccountBaseURL"]; }

    NSString *deviceID = [SSDeviceIdentity deviceID];
    NSDictionary *body = @{@"device_id": deviceID};
    NSData *bodyData = [NSJSONSerialization dataWithJSONObject:body options:0 error:NULL];

    NSURL *url = [NSURL URLWithString:[baseURL stringByAppendingString:@"/v1/device/register"]];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    req.HTTPMethod = @"POST";
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    req.HTTPBody = bodyData;
    req.timeoutInterval = 15;

    [[NSURLSession.sharedSession dataTaskWithRequest:req
        completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
        if (!err && [(NSHTTPURLResponse *)resp statusCode] == 200) {
            [[NSUserDefaults standardUserDefaults] setBool:YES forKey:key];
            NSLog(@"[AppDelegate] 设备注册成功: %@", deviceID);
        } else {
            NSLog(@"[AppDelegate] 设备注册失败，下次启动重试: %@", err.localizedDescription ?: @"unknown");
        }
    }] resume];
}

- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
