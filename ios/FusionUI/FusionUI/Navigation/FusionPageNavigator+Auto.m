//
//  FusionPageNavigator+Manual.m
//  FusionUI
//
//  Created by Ryou Zhang on 1/12/15.
//  Copyright (c) 2015 Ryou Zhang. All rights reserved.
//

#import "FusionPageNavigator+Auto.h"
#import "FusionPageNavigator+Internal.h"
#import "FusionPageNavigator+NaviAnime.h"
#import "FusionPageNavigator+Tab.h"
#import "FusionPageMessage.h"
#import "Anime/FusionNaviAnimeHelper.h"
#import "FusionTabBar.h"
#import "SafeARC.h"

@implementation FusionPageNavigator(Auto)
+ (NSURL *)generateCallbackUrl:(UIViewController<IFusionPageProtocol>*)controller {
    // The callback URL must round-trip through -[FusionPageMessage initWithURL:],
    // which reads the PAGE NAME from the path and the instance NICK from the
    // "nick" query parameter. A non-singleton page's nick is "pageName_<ts>",
    // so putting it in the path (as the old code did) made initWithURL: treat
    // the whole string as the page name → getPageConfig: lookup failed → back
    // button did nothing. Mirror -[FusionPageMessage generateURL]: path = page
    // name, nick only in the query when it differs from the page name.
    NSString *pageName = [controller getPageName];
    NSString *pageNick = [controller getPageNick];
    NSString *path;
    if (pageName.length && ![pageNick isEqualToString:pageName]) {
        NSMutableDictionary *queryDic = [NSMutableDictionary new];
        [queryDic setValue:pageNick forKey:@"nick"];
        NSString *queryText = [NSURL generateQueryText:queryDic];
        SafeRelease(queryDic);
        path = [NSString stringWithFormat:@"/%@?%@", pageName, queryText];
    } else {
        // Singleton (nick == page name) or missing page name: page name alone.
        path = [NSString stringWithFormat:@"/%@", (pageName.length ? pageName : pageNick)];
    }
    NSURL *url = [[NSURL alloc] initWithScheme:FusionScheme
                                          host:FusionPageHost
                                          path:path];
    return SafeAutoRelease(url);
}

- (void)openPage:(FusionPageMessage *)message {
    if (message.naviAnimeDirection == FusionNaviAnimeForward) {
        [self gotoPage:message];
    } else {
        [self poptoPage:message];
    }
}

- (void)gotoPage:(FusionPageMessage *)message {
    if (message == nil) {
        return;
    }
    if (_targetController) {
        [message setNaviAnimeDirection:FusionNaviAnimeForward];
        [_waittingArray addObject:message];
        return;
    }
    
    if (_rewriter) {
        message = [_rewriter rewriteFusionPageMessage:message];
    }
    
    _targetController = SafeRetain([self findTargetPageController:message]);
    if (_targetController == nil) {
        return;
    }
    
    if (_targetController == _currentController) {
        SafeRelease(_targetController)
        return;
    }
    
    if([_targetController respondsToSelector:@selector(setPrevSnapView:)]) {
        [_targetController setPrevSnapView:nil];
    }
    if ([_targetController respondsToSelector:@selector(setPrevMaskView:)]) {
        [_targetController setPrevMaskView:nil];
    }
    if (message.isDestory == NO) {
        [_targetController setNaviAnimeType:message.naviAnimeType];
    } else if (_currentController) {
        [_targetController setNaviAnimeType:[_currentController getNaviAnimeType]];
    }
    
    if (message.callbackUrl) {
        [_targetController setCallbackUrl:message.callbackUrl];
    } else if (_currentController) {
        if (message.isDestory) {
            [_targetController setCallbackUrl:[_currentController getCallbackUrl]];
        } else {
            [_targetController setCallbackUrl:[FusionPageNavigator generateCallbackUrl:_currentController]];
        }
    }
    
    [self processTabBarForPageController:_targetController];
    
    SafeRelease(_targetContentView)
    _targetContentView = SafeRetain([self createPageContentView:_targetController]);
    [_targetContentView setFrame:CGRectMake(0.0, 0.0, _containerView.frame.size.width, _containerView.frame.size.height)];
    
    SafeRelease(_maskView);
    _maskView = [UIView new];
    [_maskView setUserInteractionEnabled:NO];
    [_maskView setFrame:_currentContentView.frame];
    [_containerView addSubview:_maskView];
    if ([_targetController respondsToSelector:@selector(setPrevMaskView:)]) {
        [_targetController performSelector:@selector(setPrevMaskView:) withObject:_maskView];
    }
    [_containerView addSubview:_targetContentView];
    
    [_targetController processPageCommand:message.command
                                     args:message.args];
    
    FusionNaviAnime *anime = [FusionNaviAnimeHelper createPageNaviAnime:message.naviAnimeType
                                                         animeDirection:FusionNaviAnimeForward];
    if (anime == nil || _currentController == _targetController) {
        [self onGotoAnimeFinish:message.isDestory];
    } else {
        if (NO == [anime isKindOfClass:NSClassFromString(@"FusionNavi2DAnime")]) {
            CATransform3D aTransform = CATransform3DIdentity;
            aTransform.m34 = - 1.0 / 1000;
            [_containerView.layer setSublayerTransform:aTransform];
        }
        
        [anime setBackgroundView:_currentContentView];
        [anime setMaskView:_maskView];
        [anime setForegroundView:_targetContentView];
        
        if (message.isDestory) {
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(gotoAndDestoryAnimeFinish:)
                                                         name:FusionNaviAnime_Finish
                                                       object:anime];
        } else {
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(gotoAnimeFinish:)
                                                         name:FusionNaviAnime_Finish
                                                       object:anime];
        }
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(gotoAnimeCancel:)
                                                     name:FusionNaviAnime_Cancel
                                                   object:anime];
        [anime prepare];
        [anime play];
    }
}

- (void)poptoPage:(FusionPageMessage *)message {
    if (message == nil) {
        return;
    }
    if (_targetController) {
        [message setNaviAnimeDirection:FusionNaviAnimeBackward];
        [_waittingArray addObject:message];
        return;
    }
    
    if (_rewriter) {
        message = [_rewriter rewriteFusionPageMessage:message];
    }
    
    _targetController = SafeRetain([self findTargetPageController:message]);
    if (_targetController == nil) {
        return;
    }
    
    if (_targetController == _currentController) {
        SafeRelease(_targetController)
        return;
    }
    
    [self processTabBarForPageController:_targetController];
    
    SafeRelease(_targetContentView)
    _targetContentView = SafeRetain([self createPageContentView:_targetController]);
    [_targetContentView setFrame:CGRectMake(0.0, 0.0, _containerView.frame.size.width, _containerView.frame.size.height)];
    [_containerView addSubview:_targetContentView];
    
    if ([_currentController getPrevSnapView]) {
        [[_currentController getPrevSnapView] removeFromSuperview];
    }
    if ([_currentController getPrevMaskView]) {
        [[_currentController getPrevMaskView] removeFromSuperview];
    }
    SafeRelease(_maskView);
    _maskView = SafeRetain([_currentController getPrevMaskView]);
    
    [_containerView insertSubview:_maskView belowSubview:_currentContentView];
    [_containerView sendSubviewToBack:_targetContentView];
    
    [_targetController processPageCommand:message.command
                                     args:message.args];
    
    FusionNaviAnime *anime = [FusionNaviAnimeHelper createPageNaviAnime:message.naviAnimeType
                                                         animeDirection:FusionNaviAnimeBackward];
    if (_currentController) {
        [_currentController exitAnimeStart];
    }
    [_targetController enterAnimeStart];
    if (anime == nil) {
        [self onPopAnimeFinish];
    } else {
        if (NO == [anime isKindOfClass:NSClassFromString(@"FusionNavi2DAnime")]) {
            CATransform3D aTransform = CATransform3DIdentity;
            aTransform.m34 = - 1.0 / 1000;
            [_containerView.layer setSublayerTransform:aTransform];
        }
        
        [anime setForegroundView:_currentContentView];
        [anime setMaskView:_maskView];
        [anime setBackgroundView:_targetContentView];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(poptoAnimeFinish:)
                                                     name:FusionNaviAnime_Finish
                                                   object:anime];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(poptoAnimeCancel:)
                                                     name:FusionNaviAnime_Cancel
                                                   object:anime];
        [anime prepare];
        [anime play];
    }
}
@end
