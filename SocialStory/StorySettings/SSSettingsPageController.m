//
//  SSSettingsPageController.m
//  StorySettings
//

#import "SSSettingsPageController.h"
#import <FusionUI/FusionPageNavigator+Auto.h>
#import <FusionUI/FusionNaviAnimeHelper.h>
#import <SocialStoryCore/SocialStoryCore-Swift.h>

@interface SSSettingsPageController ()
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UILabel *quotaLabel;
@property (nonatomic, strong) UISlider *rateSlider;
@property (nonatomic, strong) UILabel *rateValueLabel;
@end

@implementation SSSettingsPageController

- (NSString *)pageTitle { return @"设置"; }
- (BOOL)showsBackButton { return YES; }

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)buildPageContent {
    [self buildUI];
    [self refreshStatus];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if ([self contentBuilt]) {
        [self refreshStatus];
    }
}

- (void)buildUI {
    CGFloat top = [self naviBarBottom];
    CGFloat bottomInset = [self contentBottomInset];
    CGFloat margin = 16;
    CGFloat width = self.view.bounds.size.width - margin * 2;
    self.scrollView = [[UIScrollView alloc] initWithFrame:
        CGRectMake(0, top, self.view.bounds.size.width, self.view.bounds.size.height - top - bottomInset)];
    self.scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.scrollView];

    CGFloat y = 16;

    // Subscription status
    y = [self sectionTitle:@"会员" atY:y margin:margin];
    self.statusLabel = [self valueLabelAtY:y margin:margin width:width];
    y += 26;
    self.quotaLabel = [self valueLabelAtY:y margin:margin width:width];
    y += 34;

    UIButton *subBtn = [self linkButton:@"订阅 / 升级会员" atY:y margin:margin width:width
                                 action:@selector(onSubscribe)];
    (void)subBtn; y += 44;
    UIButton *restoreBtn = [self linkButton:@"恢复购买" atY:y margin:margin width:width
                                     action:@selector(onRestore)];
    (void)restoreBtn; y += 56;

    // Speech rate
    y = [self sectionTitle:@"默认朗读语速" atY:y margin:margin];
    self.rateSlider = [[UISlider alloc] initWithFrame:CGRectMake(margin, y, width - 56, 36)];
    self.rateSlider.minimumValue = 0.4;
    self.rateSlider.maximumValue = 0.8;
    self.rateSlider.value = [self storedRate];
    self.rateSlider.accessibilityLabel = @"默认朗读语速";
    [self.rateSlider addTarget:self action:@selector(onRateChanged) forControlEvents:UIControlEventValueChanged];
    [self.scrollView addSubview:self.rateSlider];
    self.rateValueLabel = [[UILabel alloc] initWithFrame:CGRectMake(margin + width - 48, y, 48, 36)];
    self.rateValueLabel.font = [UIFont systemFontOfSize:14];
    self.rateValueLabel.textColor = [SSTheme secondaryTextColor];
    [self.scrollView addSubview:self.rateValueLabel];
    [self updateRateLabel];
    y += 36 + 24;

    // Help
    y = [self sectionTitle:@"关于" atY:y margin:margin];
    UIButton *helpBtn = [self linkButton:@"社交故事法 & 使用帮助" atY:y margin:margin width:width
                                  action:@selector(onHelp)];
    (void)helpBtn; y += 56;

    // Destructive
    y = [self sectionTitle:@"数据" atY:y margin:margin];
    UIButton *clearBtn = [self linkButton:@"清空所有故事" atY:y margin:margin width:width
                                   action:@selector(onClearAll)];
    [clearBtn setTitleColor:[UIColor systemRedColor] forState:UIControlStateNormal];
    y += 56;

    self.scrollView.contentSize = CGSizeMake(self.view.bounds.size.width, y);
}

- (CGFloat)sectionTitle:(NSString *)text atY:(CGFloat)y margin:(CGFloat)margin {
    UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(margin, y, self.view.bounds.size.width - margin*2, 22)];
    l.text = text; l.font = [UIFont boldSystemFontOfSize:15];
    l.textColor = [SSTheme secondaryTextColor];
    [self.scrollView addSubview:l];
    return y + 28;
}

- (UILabel *)valueLabelAtY:(CGFloat)y margin:(CGFloat)margin width:(CGFloat)width {
    UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(margin, y, width, 24)];
    l.font = [UIFont systemFontOfSize:16];
    l.textColor = [SSTheme primaryTextColor];
    [self.scrollView addSubview:l];
    return l;
}

- (UIButton *)linkButton:(NSString *)title atY:(CGFloat)y margin:(CGFloat)margin width:(CGFloat)width action:(SEL)action {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    b.frame = CGRectMake(margin, y, width, 44);
    b.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    b.backgroundColor = [SSTheme cardColor];
    b.layer.cornerRadius = 8;
    [b setTitle:[@"  " stringByAppendingString:title] forState:UIControlStateNormal];
    [b setTitleColor:[SSTheme accentColor] forState:UIControlStateNormal];
    b.titleLabel.font = [UIFont systemFontOfSize:16];
    [b addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [self.scrollView addSubview:b];
    return b;
}

#pragma mark - State

- (float)storedRate {
    id v = [[NSUserDefaults standardUserDefaults] objectForKey:@"ss_speech_rate"];
    return v ? [v floatValue] : 0.5f;
}

- (void)refreshStatus {
    __weak typeof(self) weakSelf = self;
    [SubscriptionManager.shared refreshSubscriptionStatusWithCompletion:^(BOOL active) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        self.statusLabel.text = active ? @"会员状态：已订阅 ✓" : @"会员状态：免费用户";
        if (active) {
            self.quotaLabel.text = @"可无限生成故事";
        } else {
            self.quotaLabel.text = [NSString stringWithFormat:@"本月剩余免费次数：%ld",
                                    (long)SubscriptionManager.shared.remainingFreeCount];
        }
    }];
}

- (void)onRateChanged {
    [[NSUserDefaults standardUserDefaults] setFloat:self.rateSlider.value forKey:@"ss_speech_rate"];
    [self updateRateLabel];
}

- (void)updateRateLabel {
    self.rateValueLabel.text = [NSString stringWithFormat:@"%.1f", self.rateSlider.value];
}

#pragma mark - Actions

- (void)onSubscribe { [self gotoPage:SSPageSubscription]; }
- (void)onHelp { [self gotoPage:SSPageHelp]; }

- (void)gotoPage:(NSString *)pageName {
    FusionPageMessage *m = [[FusionPageMessage alloc] initWithPageName:pageName
                                                              pageNick:nil command:nil args:nil callback:nil];
    [m setNaviAnimeType:SlideR2L_NaviAnime];
    [[self getNavigator] gotoPage:m];
}

- (void)onRestore {
    [SubscriptionManager.shared restorePurchasesWithCompletion:^(BOOL success, NSString *errorMessage) {
        [self showAlert:(success ? @"恢复成功" : @"恢复购买") message:(errorMessage ?: @"订阅已恢复")];
        [self refreshStatus];
    }];
}

- (void)onClearAll {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"清空所有故事"
                                                                  message:@"此操作不可撤销，确定要删除全部故事吗？"
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"全部删除" style:UIAlertActionStyleDestructive
                                            handler:^(UIAlertAction *a) {
        [[SSStoryStore shared] deleteAllStories];
        [self showAlert:@"已清空" message:@"所有故事已删除"];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showAlert:(NSString *)title message:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
