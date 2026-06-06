//
//  SSProfilePageController.m
//  StoryProfile
//
//  The "我的" tab: account header (avatar / login state / membership), a
//  membership section, settings entry points, and about / logout. Built as a
//  grouped table; the header hosts the avatar area.
//

#import "SSProfilePageController.h"
#import <FusionUI/FusionPageNavigator+Auto.h>
#import <FusionUI/FusionNaviAnimeHelper.h>
#import <SocialStoryCore/SocialStoryCore-Swift.h>
#import <AccountKit/AccountKit-Swift.h>

typedef NS_ENUM(NSInteger, SSProfileSection) {
    SSProfileSectionMembership = 0,
    SSProfileSectionSettings,
    SSProfileSectionAbout,
    SSProfileSectionCount
};

@interface SSProfilePageController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *tableView;
// Header
@property (nonatomic, strong) UIView *headerView;
@property (nonatomic, strong) UIImageView *avatarView;
@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *subLabel;
@property (nonatomic, strong) UIButton *loginButton;
@property (nonatomic, strong) UILabel *badgeLabel;
// Membership state text (refreshed async)
@property (nonatomic, copy) NSString *memberStatusText;
@property (nonatomic, copy) NSString *memberQuotaText;
@end

@implementation SSProfilePageController

- (NSString *)pageTitle { return @"我的"; }

- (void)viewDidLoad {
    [super viewDidLoad];
    self.memberStatusText = @"会员状态：加载中…";
    self.memberQuotaText = @"";
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onAccountChanged)
                                                 name:[AccountManager didChangeNotificationName]
                                               object:nil];
}

- (void)buildPageContent {
    CGFloat top = [self naviBarBottom];
    CGFloat bottom = [self contentBottomInset];
    self.tableView = [[UITableView alloc] initWithFrame:
        CGRectMake(0, top, self.view.bounds.size.width, self.view.bounds.size.height - top - bottom)
                                                  style:UITableViewStyleGrouped];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.backgroundColor = [SSTheme backgroundColor];
    self.tableView.rowHeight = 52;
    [self.view addSubview:self.tableView];

    [self buildHeader];
    [self refreshAccountHeader];
    [self refreshMembership];
}

#pragma mark - Header

- (void)buildHeader {
    CGFloat width = self.view.bounds.size.width;
    self.headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 168)];

    self.avatarView = [[UIImageView alloc] initWithFrame:CGRectMake((width - 72) / 2, 28, 72, 72)];
    self.avatarView.layer.cornerRadius = 36;
    self.avatarView.clipsToBounds = YES;
    self.avatarView.backgroundColor = [SSTheme cardColor];
    self.avatarView.contentMode = UIViewContentModeScaleAspectFill;
    self.avatarView.userInteractionEnabled = YES;
    [self.avatarView addGestureRecognizer:
        [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onTapHeader)]];
    [self.headerView addSubview:self.avatarView];

    self.nameLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 106, width, 24)];
    self.nameLabel.textAlignment = NSTextAlignmentCenter;
    self.nameLabel.font = [UIFont boldSystemFontOfSize:18];
    self.nameLabel.textColor = [SSTheme primaryTextColor];
    [self.headerView addSubview:self.nameLabel];

    self.subLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 132, width, 20)];
    self.subLabel.textAlignment = NSTextAlignmentCenter;
    self.subLabel.font = [UIFont systemFontOfSize:13];
    self.subLabel.textColor = [SSTheme secondaryTextColor];
    [self.headerView addSubview:self.subLabel];

    // PRO badge (hidden unless subscribed)
    self.badgeLabel = [[UILabel alloc] initWithFrame:CGRectMake(width / 2 + 24, 28, 40, 20)];
    self.badgeLabel.text = @"PRO";
    self.badgeLabel.font = [UIFont boldSystemFontOfSize:11];
    self.badgeLabel.textAlignment = NSTextAlignmentCenter;
    self.badgeLabel.textColor = [UIColor whiteColor];
    self.badgeLabel.backgroundColor = [SSTheme accentColor];
    self.badgeLabel.layer.cornerRadius = 9;
    self.badgeLabel.clipsToBounds = YES;
    self.badgeLabel.hidden = YES;
    [self.headerView addSubview:self.badgeLabel];

    // Login button (shown only when logged out), overlays name/sub area.
    self.loginButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.loginButton.frame = CGRectMake((width - 160) / 2, 106, 160, 40);
    self.loginButton.backgroundColor = [SSTheme accentColor];
    self.loginButton.layer.cornerRadius = 20;
    [self.loginButton setTitle:@"登录 / 注册" forState:UIControlStateNormal];
    [self.loginButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.loginButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    [self.loginButton addTarget:self action:@selector(onTapHeader) forControlEvents:UIControlEventTouchUpInside];
    [self.headerView addSubview:self.loginButton];

    self.tableView.tableHeaderView = self.headerView;
}

- (void)refreshAccountHeader {
    BOOL loggedIn = [AccountManager shared].isLoggedIn;
    SSUser *user = [AccountManager shared].currentUser;

    self.loginButton.hidden = loggedIn;
    self.nameLabel.hidden = !loggedIn;
    self.subLabel.hidden = !loggedIn;

    if (loggedIn) {
        self.nameLabel.text = user.nickname;
        self.subLabel.text = [self maskedPhone:user.phone];
        [[SSImageLoader shared] loadImageURL:user.avatarURL into:self.avatarView];
        if (user.avatarURL.length == 0) {
            self.avatarView.image = [self defaultAvatar];
        }
    } else {
        self.avatarView.image = [self defaultAvatar];
    }
}

- (NSString *)maskedPhone:(NSString *)phone {
    if (phone.length < 11) { return phone ?: @""; }
    return [NSString stringWithFormat:@"%@****%@",
            [phone substringToIndex:3], [phone substringFromIndex:7]];
}

- (UIImage *)defaultAvatar {
    // Simple tinted system person glyph as a placeholder.
    UIImage *img = [UIImage systemImageNamed:@"person.crop.circle.fill"];
    return [img imageWithTintColor:[SSTheme secondaryTextColor]
                     renderingMode:UIImageRenderingModeAlwaysOriginal] ?: img;
}

#pragma mark - Refresh hooks

- (void)onAccountChanged {
    if (![self contentBuilt]) { return; }
    [self refreshAccountHeader];
    [self refreshMembership];
    [self.tableView reloadData];
}

- (void)enterAnimeFinish {
    [super enterAnimeFinish];
    if (![self contentBuilt]) { return; }
    [self refreshAccountHeader];
    [self refreshMembership];
}

- (void)refreshMembership {
    __weak typeof(self) weakSelf = self;
    [SubscriptionManager.shared refreshSubscriptionStatusWithCompletion:^(BOOL active) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        self.badgeLabel.hidden = !active;
        self.memberStatusText = active ? @"会员状态：已订阅 ✓" : @"会员状态：免费用户";
        self.memberQuotaText = active ? @"可无限生成故事"
            : [NSString stringWithFormat:@"本月剩余免费次数：%ld",
               (long)SubscriptionManager.shared.remainingFreeCount];
        [self.tableView reloadData];
    }];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Hide "logout" row (last About row) when logged out — handled in row count.
    return SSProfileSectionCount;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case SSProfileSectionMembership: return 2;   // upgrade, restore
        case SSProfileSectionSettings:   return 3;   // speech rate, help, data
        case SSProfileSectionAbout:      return [AccountManager shared].isLoggedIn ? 2 : 1; // about(+logout)
        default: return 0;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (section) {
        case SSProfileSectionMembership: return self.memberStatusText;
        case SSProfileSectionSettings:   return @"设置";
        case SSProfileSectionAbout:      return @"关于";
        default: return nil;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    // Show quota as the membership section footer.
    return (section == SSProfileSectionMembership) ? self.memberQuotaText : nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cid = @"ProfileCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cid];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:cid];
        cell.textLabel.font = [UIFont systemFontOfSize:16];
    }
    cell.textLabel.textColor = [SSTheme primaryTextColor];
    cell.detailTextLabel.text = nil;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

    switch (indexPath.section) {
        case SSProfileSectionMembership:
            cell.textLabel.text = (indexPath.row == 0) ? @"订阅 / 升级会员" : @"恢复购买";
            break;
        case SSProfileSectionSettings:
            if (indexPath.row == 0) {
                cell.textLabel.text = @"默认朗读语速";
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%.1f", [self storedRate]];
            } else if (indexPath.row == 1) {
                cell.textLabel.text = @"社交故事法 & 使用帮助";
            } else {
                cell.textLabel.text = @"数据管理";
            }
            break;
        case SSProfileSectionAbout:
            if (indexPath.row == 0) {
                cell.textLabel.text = @"关于 / 版本";
                cell.detailTextLabel.text = [self appVersion];
                cell.accessoryType = UITableViewCellAccessoryNone;
            } else {
                cell.textLabel.text = @"退出登录";
                cell.textLabel.textColor = [UIColor systemRedColor];
                cell.accessoryType = UITableViewCellAccessoryNone;
            }
            break;
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    switch (indexPath.section) {
        case SSProfileSectionMembership:
            if (indexPath.row == 0) { [self gotoPage:SSPageSubscription]; }
            else { [self onRestore]; }
            break;
        case SSProfileSectionSettings:
            // All settings detail lives in the existing settings page.
            [self gotoPage:(indexPath.row == 1) ? SSPageHelp : SSPageSettings];
            break;
        case SSProfileSectionAbout:
            if (indexPath.row == 1) { [self onLogout]; }
            break;
    }
}

#pragma mark - Actions

- (void)onTapHeader {
    if ([AccountManager shared].isLoggedIn) { return; }
    [self gotoPage:SSPageLogin];
}

- (void)onRestore {
    [SubscriptionManager.shared restorePurchasesWithCompletion:^(BOOL success, NSString *errorMessage) {
        [self showAlert:(success ? @"恢复成功" : @"恢复购买") message:(errorMessage ?: @"订阅已恢复")];
        [self refreshMembership];
    }];
}

- (void)onLogout {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"退出登录"
                                                                  message:@"确定要退出当前账户吗？"
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"退出" style:UIAlertActionStyleDestructive
                                            handler:^(UIAlertAction *a) {
        [[AccountManager shared] logout];
        // logout posts SSAccountDidChange → onAccountChanged refreshes UI.
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)gotoPage:(NSString *)pageName {
    FusionPageMessage *m = [[FusionPageMessage alloc] initWithPageName:pageName
                                                              pageNick:nil command:nil args:nil callback:nil];
    [m setNaviAnimeType:SlideR2L_NaviAnime];
    [[self getNavigator] gotoPage:m];
}

- (float)storedRate {
    id v = [[NSUserDefaults standardUserDefaults] objectForKey:@"ss_speech_rate"];
    return v ? [v floatValue] : 0.5f;
}

- (NSString *)appVersion {
    NSString *v = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    return v.length ? [@"v" stringByAppendingString:v] : @"";
}

- (void)showAlert:(NSString *)title message:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
