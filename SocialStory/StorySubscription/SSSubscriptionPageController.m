//
//  SSSubscriptionPageController.m
//  StorySubscription
//

#import "SSSubscriptionPageController.h"
#import <SocialStoryCore/SocialStoryCore-Swift.h>
#import <objc/runtime.h>

@interface SSSubscriptionPageController ()
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIStackView *cardsStack;
@property (nonatomic, strong) UIButton *restoreButton;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, copy)   NSArray<SSProductInfo *> *products;
@end

@implementation SSSubscriptionPageController

- (NSString *)pageTitle { return @"订阅会员"; }
- (BOOL)showsBackButton { return YES; }

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)buildPageContent {
    [self buildUI];
    [self loadProducts];
    [self refreshStatus];
}

- (void)buildUI {
    CGFloat top = [self naviBarBottom] + 16;
    CGFloat margin = 16;
    CGFloat width = self.view.bounds.size.width - margin * 2;

    UILabel *header = [[UILabel alloc] initWithFrame:CGRectMake(margin, top, width, 28)];
    header.text = @"订阅后无限生成故事";
    header.font = [UIFont boldSystemFontOfSize:20];
    header.textColor = [SSTheme primaryTextColor];
    [self.view addSubview:header];

    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(margin, top + 34, width, 22)];
    self.statusLabel.font = [UIFont systemFontOfSize:15];
    self.statusLabel.textColor = [SSTheme secondaryTextColor];
    [self.view addSubview:self.statusLabel];

    self.cardsStack = [[UIStackView alloc] initWithFrame:CGRectMake(margin, top + 70, width, 200)];
    self.cardsStack.axis = UILayoutConstraintAxisVertical;
    self.cardsStack.spacing = 12;
    self.cardsStack.distribution = UIStackViewDistributionFillEqually;
    self.cardsStack.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:self.cardsStack];

    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.spinner.center = CGPointMake(self.view.bounds.size.width / 2, top + 140);
    [self.view addSubview:self.spinner];
    [self.spinner startAnimating];

    self.restoreButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.restoreButton.frame = CGRectMake(margin, top + 290, width, 44);
    self.restoreButton.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.restoreButton setTitle:@"恢复购买" forState:UIControlStateNormal];
    [self.restoreButton setTitleColor:[SSTheme accentColor] forState:UIControlStateNormal];
    [self.restoreButton addTarget:self action:@selector(onRestore) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.restoreButton];
}

- (void)loadProducts {
    __weak typeof(self) weakSelf = self;
    [SubscriptionManager.shared loadProductsWithCompletion:^(NSArray<SSProductInfo *> *infos) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [self.spinner stopAnimating];
        self.products = infos;
        [self renderCards];
    }];
}

- (void)renderCards {
    for (UIView *v in self.cardsStack.arrangedSubviews) { [v removeFromSuperview]; }
    if (self.products.count == 0) {
        UILabel *empty = [UILabel new];
        empty.text = @"暂时无法加载产品\n（需在 App Store Connect 或 .storekit 配置）";
        empty.numberOfLines = 0;
        empty.textAlignment = NSTextAlignmentCenter;
        empty.font = [UIFont systemFontOfSize:14];
        empty.textColor = [SSTheme secondaryTextColor];
        [self.cardsStack addArrangedSubview:empty];
        return;
    }
    for (SSProductInfo *info in self.products) {
        [self.cardsStack addArrangedSubview:[self cardForProduct:info]];
    }
}

- (UIView *)cardForProduct:(SSProductInfo *)info {
    UIButton *card = [UIButton buttonWithType:UIButtonTypeCustom];
    card.backgroundColor = [SSTheme cardColor];
    card.layer.cornerRadius = 12;
    card.layer.borderWidth = 1.5;
    card.layer.borderColor = [SSTheme accentColor].CGColor;
    [card setTitle:[NSString stringWithFormat:@"%@   %@", info.displayName, info.displayPrice]
          forState:UIControlStateNormal];
    [card setTitleColor:[SSTheme primaryTextColor] forState:UIControlStateNormal];
    card.titleLabel.font = [UIFont boldSystemFontOfSize:17];
    card.accessibilityLabel = [NSString stringWithFormat:@"订阅 %@，价格 %@", info.displayName, info.displayPrice];
    objc_setAssociatedObject(card, "pid", info.identifier, OBJC_ASSOCIATION_COPY_NONATOMIC);
    [card addTarget:self action:@selector(onBuy:) forControlEvents:UIControlEventTouchUpInside];
    return card;
}

- (void)onBuy:(UIButton *)sender {
    NSString *pid = objc_getAssociatedObject(sender, "pid");
    if (!pid) return;
    [self.spinner startAnimating];
    __weak typeof(self) weakSelf = self;
    [SubscriptionManager.shared purchaseWithProductID:pid completion:^(BOOL success, NSString *errorMessage) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [self.spinner stopAnimating];
        if (success) {
            [self showAlert:@"订阅成功" message:@"感谢你的支持！现在可以无限生成故事了。"];
            [self refreshStatus];
        } else if (errorMessage) {
            [self showAlert:@"购买未完成" message:errorMessage];
        }
    }];
}

- (void)onRestore {
    [self.spinner startAnimating];
    __weak typeof(self) weakSelf = self;
    [SubscriptionManager.shared restorePurchasesWithCompletion:^(BOOL success, NSString *errorMessage) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [self.spinner stopAnimating];
        [self showAlert:(success ? @"恢复成功" : @"恢复购买") message:(errorMessage ?: @"订阅已恢复")];
        [self refreshStatus];
    }];
}

- (void)refreshStatus {
    __weak typeof(self) weakSelf = self;
    [SubscriptionManager.shared refreshSubscriptionStatusWithCompletion:^(BOOL active) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        self.statusLabel.text = active ? @"当前状态：已订阅 ✓" : @"当前状态：未订阅";
    }];
}

- (void)showAlert:(NSString *)title message:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
