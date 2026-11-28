//
//  SSLoginPageController.m
//  StoryProfile
//
//  Phone + SMS-code login. Talks only to AccountManager (AccountKit), which is
//  backed by a mock today and a real service later — this screen doesn't change.
//

#import "SSLoginPageController.h"
#import <FusionUI/FusionPageNavigator+Auto.h>
#import <FusionUI/FusionNaviAnimeHelper.h>
#import <SocialStoryCore/SocialStoryCore-Swift.h>
#import <AccountKit/AccountKit-Swift.h>

@interface SSLoginPageController ()
@property (nonatomic, strong) UITextField *phoneField;
@property (nonatomic, strong) UITextField *codeField;
@property (nonatomic, strong) UIButton *sendCodeButton;
@property (nonatomic, strong) UIButton *loginButton;
@property (nonatomic, assign) NSInteger countdown;
@property (nonatomic, strong) NSTimer *countdownTimer;
@end

@implementation SSLoginPageController

- (NSString *)pageTitle { return @"登录 / 注册"; }
- (BOOL)showsBackButton { return YES; }

- (void)buildPageContent {
    CGFloat top = [self naviBarBottom];
    CGFloat margin = 24;
    CGFloat width = self.view.bounds.size.width - margin * 2;
    CGFloat y = top + 32;

    UILabel *hint = [[UILabel alloc] initWithFrame:CGRectMake(margin, y, width, 24)];
    hint.text = @"输入手机号，验证后即可登录";
    hint.font = [UIFont systemFontOfSize:15];
    hint.textColor = [SSTheme secondaryTextColor];
    [self.view addSubview:hint];
    y += 24 + 20;

    // Phone field
    self.phoneField = [self fieldAtY:y margin:margin width:width placeholder:@"手机号"];
    self.phoneField.keyboardType = UIKeyboardTypePhonePad;
    y += 50 + 14;

    // Code field + send button on one row
    CGFloat sendW = 116;
    CGFloat codeW = width - sendW - 10;
    self.codeField = [self fieldAtY:y margin:margin width:codeW placeholder:@"验证码"];
    self.codeField.keyboardType = UIKeyboardTypeNumberPad;

    self.sendCodeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.sendCodeButton.frame = CGRectMake(margin + codeW + 10, y, sendW, 50);
    self.sendCodeButton.layer.cornerRadius = 10;
    self.sendCodeButton.layer.borderWidth = 1;
    self.sendCodeButton.layer.borderColor = [SSTheme accentColor].CGColor;
    [self.sendCodeButton setTitle:@"获取验证码" forState:UIControlStateNormal];
    [self.sendCodeButton setTitleColor:[SSTheme accentColor] forState:UIControlStateNormal];
    self.sendCodeButton.titleLabel.font = [UIFont systemFontOfSize:14];
    [self.sendCodeButton addTarget:self action:@selector(onSendCode) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.sendCodeButton];
    y += 50 + 28;

    // Login button
    self.loginButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.loginButton.frame = CGRectMake(margin, y, width, 50);
    self.loginButton.backgroundColor = [SSTheme accentColor];
    self.loginButton.layer.cornerRadius = 12;
    [self.loginButton setTitle:@"登录" forState:UIControlStateNormal];
    [self.loginButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.loginButton.titleLabel.font = [UIFont boldSystemFontOfSize:18];
    [self.loginButton addTarget:self action:@selector(onLogin) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.loginButton];
}

- (UITextField *)fieldAtY:(CGFloat)y margin:(CGFloat)margin width:(CGFloat)width placeholder:(NSString *)placeholder {
    UITextField *tf = [[UITextField alloc] initWithFrame:CGRectMake(margin, y, width, 50)];
    tf.borderStyle = UITextBorderStyleNone;
    tf.backgroundColor = [SSTheme cardColor];
    tf.textColor = [SSTheme primaryTextColor];
    tf.layer.cornerRadius = 10;
    tf.font = [UIFont systemFontOfSize:16];
    tf.placeholder = placeholder;
    // Left padding.
    tf.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 12, 50)];
    tf.leftViewMode = UITextFieldViewModeAlways;
    [self.view addSubview:tf];
    return tf;
}

#pragma mark - Actions

- (void)onSendCode {
    NSString *phone = self.phoneField.text;
    if (phone.length == 0) { [self showAlert:@"提示" message:@"请输入手机号"]; return; }
    [self.view endEditing:YES];
    self.sendCodeButton.enabled = NO;
    __weak typeof(self) weakSelf = self;
    [[AccountManager shared] requestSMSCodeWithPhone:phone completion:^(BOOL success, NSString *errorMessage) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        if (success) {
            [self startCountdown];
        } else {
            self.sendCodeButton.enabled = YES;
            [self showAlert:@"发送失败" message:errorMessage ?: @"请稍后重试"];
        }
    }];
}

- (void)startCountdown {
    self.countdown = 60;
    [self updateSendButtonForCountdown];
    self.countdownTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self
                                                         selector:@selector(onCountdownTick)
                                                         userInfo:nil repeats:YES];
}

- (void)onCountdownTick {
    self.countdown -= 1;
    if (self.countdown <= 0) {
        [self.countdownTimer invalidate];
        self.countdownTimer = nil;
        self.sendCodeButton.enabled = YES;
        [self.sendCodeButton setTitle:@"获取验证码" forState:UIControlStateNormal];
    } else {
        [self updateSendButtonForCountdown];
    }
}

- (void)updateSendButtonForCountdown {
    [self.sendCodeButton setTitle:[NSString stringWithFormat:@"%lds", (long)self.countdown]
                         forState:UIControlStateNormal];
}

- (void)onLogin {
    NSString *phone = self.phoneField.text;
    NSString *code = self.codeField.text;
    if (phone.length == 0 || code.length == 0) {
        [self showAlert:@"提示" message:@"请输入手机号和验证码"];
        return;
    }
    [self.view endEditing:YES];
    self.loginButton.enabled = NO;
    __weak typeof(self) weakSelf = self;
    [[AccountManager shared] loginWithPhone:phone code:code completion:^(BOOL success, NSString *errorMessage) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        self.loginButton.enabled = YES;
        if (success) {
            // AccountManager posts SSAccountDidChange; profile page refreshes itself.
            [self goBack];
        } else {
            [self showAlert:@"登录失败" message:errorMessage ?: @"请稍后重试"];
        }
    }];
}

- (void)showAlert:(NSString *)title message:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)dealloc {
    [self.countdownTimer invalidate];
}

@end
