//
//  FusionPageController.m
//  FusionUI
//
//  Created by Ryou Zhang on 1/12/15.
//  Copyright (c) 2015 Ryou Zhang. All rights reserved.
//

#import "FusionPageController.h"
#import "Navigation/FusionPageNavigator.h"
#import "Navigation/FusionNaviBar.h"
#import "Navigation/FusionTabBar.h"
#import "SafeARC.h"

@interface FusionPageController() {
@private
    NSDictionary    *_pageConfig;
    NSString        *_pageName;
    NSString        *_pageNick;
    NSUInteger      _naviAnimeType;
    NSURL           *_callbackUrl;
    
    UIView              *_prevSnapView;
    UIView              *_prevMaskView;
    
     __unsafe_unretained FusionPageNavigator *_navigator;
}
@end


@implementation FusionPageController
- (id)initWithConfig:(NSDictionary*)pageConfig {
    self = [super init];
    if (self) {
        _pageConfig = SafeRetain(pageConfig);
        if ([_pageConfig valueForKey:@"hide_navi"] &&
            [[_pageConfig valueForKey:@"hide_navi"] boolValue]) {
            _naviBarHidden = YES;
        } else {
            _naviBarHidden = NO;
        }
        if (_naviBarHidden == NO) {
            NSString *naviClass = [_pageConfig valueForKey:@"navi_class"];
            if (naviClass == nil) {
                _naviBar = [FusionNaviBar new];
            } else {
                _naviBar = [NSClassFromString(naviClass) new];
            }
            _naviBar.clipsToBounds = YES;
        }
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    if (_naviBar) {
        [self.view addSubview:_naviBar];
    }
    if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0) {
        if (![_pageConfig objectForKey:@"no_gesture_navi"] ||
            [[_pageConfig objectForKey:@"no_gesture_navi"] boolValue] == NO) {
            Class gestureClass = NSClassFromString(@"UIScreenEdgePanGestureRecognizer");
            if (gestureClass == nil) {
                gestureClass = [UIPanGestureRecognizer class];
            }
            id recognizer = [[gestureClass alloc] initWithTarget:self
                                                          action:@selector(onTriggerPanGesture:)];
            if ([recognizer respondsToSelector:@selector(setEdges:)]) {
                [(UIScreenEdgePanGestureRecognizer *)recognizer setEdges:UIRectEdgeLeft];
            }
            [(UIGestureRecognizer *)recognizer setDelegate:self];
            [(UIGestureRecognizer *)recognizer setDelaysTouchesBegan:YES];
            [self.view addGestureRecognizer:recognizer];
            SafeRelease(recognizer);
        }
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 7) {
        if([_pageConfig valueForKey:@"status_bar_style"]) {
            [[UIApplication sharedApplication] setStatusBarStyle:[[_pageConfig valueForKey:@"status_bar_style"] integerValue]];
        } else {
            [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleLightContent];
        }
    } else {
        [[UIApplication sharedApplication] setStatusBarStyle:3];
    }
    [self updateSubviewsLayout];
}

- (void)updateSubviewsLayout {
    [_naviBar setFrame:CGRectMake(0, 0, self.view.frame.size.width, [_naviBar getNaviBarHeight])];
    [_tabBar setFrame:CGRectMake(0, self.view.frame.size.height - 50, self.view.frame.size.width, 50)];
}

- (void)processPageCommand:(NSString *)command args:(NSDictionary *)args {
    
}

#pragma mark UIViewController+Rotation
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
    return YES;
}

- (BOOL)shouldAutorotate {
    return YES;
}

- (NSUInteger)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}

- (NSDictionary *)getPageConfig {
    return _pageConfig;
}

- (void)setPageName:(NSString *)pageName {
    SafeRelease(_pageName);
    _pageName = SafeRetain(pageName);
}

- (NSString *)getPageName {
    return _pageName;
}

- (void)setPageNick:(NSString *)pageNick {
    SafeRelease(_pageNick);
    _pageNick = SafeRetain(pageNick);
}

- (NSString *)getPageNick {
    return _pageNick;
}

- (void)setNaviAnimeType:(NSUInteger)animeType {
    _naviAnimeType = animeType;
}

- (NSUInteger)getNaviAnimeType {
    return _naviAnimeType;
}

- (void)setCallbackUrl:(NSURL *)callbackUrl {
    SafeRelease(_callbackUrl);
    _callbackUrl = SafeRetain(callbackUrl);
}

- (NSURL*)getCallbackUrl {
    return _callbackUrl;
}

- (void)setNavigator:(FusionPageNavigator *)navigator {
    _navigator = navigator;
}

- (FusionPageNavigator *)getNavigator {
    return _navigator;
}

- (void)setPrevSnapView:(UIView *)prevSnapView {
    SafeRelease(_prevSnapView);
    _prevSnapView = SafeRetain(prevSnapView);
}

- (UIView *)getPrevSnapView {
    return _prevSnapView;
}

- (void)setPrevMaskView:(UIView *)prevMaskView {
    SafeRelease(_prevMaskView);
    _prevMaskView = SafeRetain(prevMaskView);
}

- (UIView *)getPrevMaskView {
    return _prevMaskView;
}

- (void)setTabBar:(FusionTabBar *)tabBar {
    SafeRelease(_tabBar);
    _tabBar = SafeRetain(tabBar);
    [self.view addSubview:_tabBar];
}
- (FusionTabBar *)getTabBar {
    return _tabBar;
}

#pragma Reuse
- (id)dumpPageContext {
    return nil;
}

- (void)reloadPageContext:(id)context {
    
}

#pragma mark Animation Delegate
- (void)enterAnimeStart {
    
}

- (void)enterAnimeFinish {
    
}

- (void)enterAnimeCancel {
    
}

- (void)exitAnimeStart {
    
}

- (void)exitAnimeFinish {
    
}

- (void)exitAnimeCancel {
    
}

#pragma NaviBar
- (void)onNavigationLeftButtonClick:(id)sender {
    
}

- (void)onNavigationRightButtonClick:(id)sender {
    
}

#pragma UserTrack
- (void)trackPageEnter {
    
}

- (void)trackPageLeave {
    
}
#pragma GestureRecognizer
- (void)enableGestureRecognizer {
    for (UIGestureRecognizer *recognizer in [self.view gestureRecognizers]) {
        if ([recognizer isKindOfClass:[UIScreenEdgePanGestureRecognizer class]]) {
            [recognizer setEnabled:YES];
            return;
        }
    }
}

- (void)disableGestureRecognizer {
    for (UIGestureRecognizer *recognizer in [self.view gestureRecognizers]) {
        if ([recognizer isKindOfClass:[UIScreenEdgePanGestureRecognizer class]]) {
            [recognizer setEnabled:NO];
            return;
        }
    }
}

- (void)onTriggerPanGesture:(UIPanGestureRecognizer*)recognizer {
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    objc_removeAssociatedObjects(self);
    _navigator = nil;
    SafeRelease(_manualAnime);
    SafeRelease(_prevSnapView);
    SafeRelease(_prevMaskView);
    SafeRelease(_naviBar);
    SafeRelease(_tabBar);
    SafeRelease(_pageConfig);
    SafeSuperDealloc(super);
}
@end
