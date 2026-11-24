//
//  PCSceneDelegate.m
//  PhotoCleaner
//

#import "PCSceneDelegate.h"
#import <FusionUI/FusionUI.h>
#import "PCAdapter.h"
#import "TRIPPageMacro.h"

@interface PCSceneDelegate ()
@property (nonatomic, strong) FusionPageNavigator *navigator;
@end

@implementation PCSceneDelegate

- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)connectionOptions {
    if (![scene isKindOfClass:[UIWindowScene class]]) return;

    self.window = [[UIWindow alloc] initWithWindowScene:(UIWindowScene *)scene];
    self.navigator = [FusionPageNavigator new];
    self.navigator.view.backgroundColor = [UIColor systemBackgroundColor];
    [self.navigator setRewriter:nil];
    [self.navigator setAdapter:[PCAdapter sharedAdapter]];
    self.window.rootViewController = self.navigator;
    [self.window makeKeyAndVisible];

    FusionPageMessage *message = [[FusionPageMessage alloc] initWithPageName:HOMEPAGE_PAGE
                                                                    pageNick:nil
                                                                     command:@"init"
                                                                        args:@{}
                                                                    callback:nil];
    [self.navigator gotoPage:message];
}

@end
