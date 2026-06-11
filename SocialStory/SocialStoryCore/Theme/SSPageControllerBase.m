//
//  SSPageControllerBase.m
//  SocialStoryCore
//

#import "SSPageControllerBase.h"
#import "SSTheme.h"
#import <FusionUI/FusionPageNavigator+Auto.h>
#import <FusionUI/FusionPageNavigator+Manual.h>
#import <FusionUI/FusionNaviAnimeHelper.h>
#import <FusionUI/FusionNaviAnime.h>

@implementation SSPageControllerBase {
    BOOL _didBuildContent;
    FusionNaviAnime *_interactiveAnime;
}

- (NSString *)pageTitle { return @""; }
- (BOOL)showsBackButton { return NO; }

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.view setBackgroundColor:[SSTheme backgroundColor]];
    self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self setupNaviBar];
}

// The navigator drives layout through updateSubviewsLayout (and does NOT resize
// the controller's own view), so size self.view to its container here and build
// content once we have a valid size.
- (void)updateSubviewsLayout {
    if (self.view.superview) {
        self.view.frame = self.view.superview.bounds;
    }
    [super updateSubviewsLayout];
    [self buildContentIfNeeded];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self buildContentIfNeeded];
}

- (void)buildContentIfNeeded {
    if (!_didBuildContent && self.view.bounds.size.width > 0) {
        _didBuildContent = YES;
        [self buildPageContent];
    }
}

- (void)buildPageContent {
    // Subclasses override to create their subviews once the view is sized.
}

- (BOOL)contentBuilt { return _didBuildContent; }

- (void)setupNaviBar {
    [_naviBar setBackgroundColor:[SSTheme cardColor]];

    UILabel *titleLabel = [UILabel new];
    [titleLabel setFont:[UIFont boldSystemFontOfSize:18]];
    [titleLabel setTextColor:[SSTheme primaryTextColor]];
    [titleLabel setText:[self pageTitle]];
    [titleLabel setTextAlignment:NSTextAlignmentCenter];
    titleLabel.isAccessibilityElement = YES;
    titleLabel.accessibilityTraits = UIAccessibilityTraitHeader;
    [_naviBar setCenterView:titleLabel];

    if ([self showsBackButton]) {
        UIButton *back = [UIButton buttonWithType:UIButtonTypeSystem];
        [back setTitle:@"返回" forState:UIControlStateNormal];
        [back setTitleColor:[SSTheme accentColor] forState:UIControlStateNormal];
        [back.titleLabel setFont:[UIFont systemFontOfSize:16]];
        back.accessibilityLabel = @"返回上一页";
        [back addTarget:self action:@selector(onNavigationLeftButtonClick:) forControlEvents:UIControlEventTouchUpInside];
        [_naviBar setLeftView:back];
    }
}

- (CGFloat)naviBarBottom {
    CGFloat h = [_naviBar getNaviBarHeight];
    return h > 0 ? h : 64.0;
}

- (CGFloat)contentBottomInset {
    return [self getTabBar] ? 50.0 : 0.0;
}

// The navigator adds pages via addSubview (no UIViewController containment), so
// viewWillAppear/layout are not re-driven on pop. When a transition into this
// page finishes, re-assert the tab bar frame and keep it on top so it survives
// a round-trip through a tab-less detail page.
- (void)enterAnimeFinish {
    [super enterAnimeFinish];
    [self layoutTabBarIfNeeded];
}

- (void)layoutTabBarIfNeeded {
    FusionTabBar *tabBar = [self getTabBar];
    if (!tabBar) { return; }
    if (tabBar.superview != self.view) {
        [self.view addSubview:tabBar];
    }
    tabBar.frame = CGRectMake(0,
                              self.view.bounds.size.height - 50,
                              self.view.bounds.size.width,
                              50);
    [self.view bringSubviewToFront:tabBar];
}

- (BOOL)canPopBack {
    return [self getCallbackUrl] != nil;
}

- (FusionPageMessage *)backMessage {
    // Back is driven by the callback URL captured when this page was pushed.
    // SlideR2L + Backward gives the standard iOS feel: the current page slides
    // off to the right while the previous page is revealed from the left.
    FusionPageMessage *message = [[FusionPageMessage alloc] initWithURL:[self getCallbackUrl] args:nil];
    [message setNaviAnimeType:SlideR2L_NaviAnime];
    [message setNaviAnimeDirection:FusionNaviAnimeBackward];
    return message;
}

- (void)onNavigationLeftButtonClick:(id)sender {
    if (![self canPopBack]) { return; }
    [[self getNavigator] poptoPage:[self backMessage]];
}

#pragma mark - Interactive left-edge swipe back

- (void)onTriggerPanGesture:(UIPanGestureRecognizer *)recognizer {
    if (![self canPopBack]) { return; }

    CGFloat width = self.view.bounds.size.width;
    if (width <= 0) { return; }
    CGFloat tx = [recognizer translationInView:self.view].x;
    CGFloat progress = tx / width;          // 0 at left edge -> 1 fully swiped
    if (progress < 0) progress = 0;
    if (progress > 1) progress = 1;

    switch (recognizer.state) {
        case UIGestureRecognizerStateBegan: {
            // Backward slide animates process 1.0 -> 0.0; start fully shown.
            _interactiveAnime = [[self getNavigator] manualPoptoPage:[self backMessage]];
            [_interactiveAnime updateProcess:1.0];
            break;
        }
        case UIGestureRecognizerStateChanged: {
            [_interactiveAnime updateProcess:(1.0 - progress)];
            break;
        }
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled:
        case UIGestureRecognizerStateFailed: {
            if (_interactiveAnime) {
                CGFloat velocity = [recognizer velocityInView:self.view].x;
                // A fast right-flick should commit the pop even past a short drag:
                // push process below the framework's 0.5 finish threshold.
                if (velocity > 800 && progress > 0.15) {
                    [_interactiveAnime updateProcess:0.0];
                } else {
                    // Otherwise keep the current dragged position and let the
                    // animation settle to finish (<0.5) or cancel (>=0.5).
                    [_interactiveAnime updateProcess:(1.0 - progress)];
                }
                [_interactiveAnime play];
                _interactiveAnime = nil;
            }
            break;
        }
        default:
            break;
    }
}

- (void)processPageCommand:(NSString *)command args:(NSDictionary *)args {
    // Subclasses override.
}

@end
