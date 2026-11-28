//
//  SSPageControllerBase.h
//  SocialStoryCore
//
//  Common base for all feature pages: themed background, a simple titled
//  navigation bar with optional back button, and small nav helpers.
//

#import <FusionUI/FusionUI.h>

NS_ASSUME_NONNULL_BEGIN

@interface SSPageControllerBase : FusionPageController

/// Page title shown centered in the navi bar. Override `pageTitle` to set it.
- (NSString *)pageTitle;

/// Whether to show a back button on the left of the navi bar. Default NO.
- (BOOL)showsBackButton;

/// Build the navi bar (title + optional back). Call from viewDidLoad after super.
- (void)setupNaviBar;

/// Override to create page subviews. Called once the view has a valid size
/// (the navigator triggers viewDidLoad before sizing, so do layout here).
- (void)buildPageContent;

/// YES once buildPageContent has run.
- (BOOL)contentBuilt;

/// Y offset below the navigation bar (safe default if not yet measured).
- (CGFloat)naviBarBottom;

/// Pop back to the previous page.
- (void)goBack;

/// Bottom inset to reserve for the tab bar (50 when this page has a tab bar, else 0).
- (CGFloat)contentBottomInset;

NS_ASSUME_NONNULL_END

@end
