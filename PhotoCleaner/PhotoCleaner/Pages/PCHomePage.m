//
//  PCHomePage.m
//  PhotoCleaner
//

#import "PCHomePage.h"
#import <FusionCore/FusionCore.h>
#import <PhotoClean/PhotoClean.h>
#import "TRIPServiceMacro.h"

@interface PCHomePage ()
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) FusionNativeMessage *pingMessage;
@end

@implementation PCHomePage

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithRed:0.93 green:0.96 blue:1.0 alpha:1.0];

    UILabel *title = [UILabel new];
    title.text = @"相册清理";
    title.font = [UIFont systemFontOfSize:28 weight:UIFontWeightSemibold];
    title.textAlignment = NSTextAlignmentCenter;

    self.statusLabel = [UILabel new];
    self.statusLabel.font = [UIFont systemFontOfSize:14];
    self.statusLabel.textColor = [UIColor secondaryLabelColor];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.numberOfLines = 0;
    self.statusLabel.accessibilityIdentifier = @"fusion_status";

    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[title, self.statusLabel]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 12;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [stack.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [stack.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.view.leadingAnchor constant:24],
    ]];

#if DEBUG
    [self runFusionSelfCheck];
#endif
}

- (void)processPageCommand:(NSString *)command args:(NSDictionary *)args {
}

#pragma mark - M0-03 self check

- (void)runFusionSelfCheck {
    self.statusLabel.text = @"Fusion 消息链路：检测中…";
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onMessageFinished:)
                                                 name:FusionNativeMessageNotification
                                               object:nil];
    self.pingMessage = [[FusionNativeMessage alloc] initWithSerivice:DIAGNOSTICSERVICE_SERVICE
                                                               actor:PINGACTOR_ACTOR
                                                                args:@{PCPingPayloadKey: @"ping"}];
    [[FusionCore getInstance] asyncSendMessage:self.pingMessage];

    // A message whose service/actor cannot be resolved is dropped silently,
    // so report a timeout instead of waiting forever.
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (weakSelf.pingMessage != nil) {
            weakSelf.statusLabel.text = @"Fusion 消息链路：超时（检查 config.zip 与 Lua 配置）";
            PCLogError(@"Fusion self check timed out");
        }
    });
}

- (void)onMessageFinished:(NSNotification *)notification {
    FusionNativeMessage *message = notification.object;
    if (message != self.pingMessage) return;
    self.pingMessage = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self name:FusionNativeMessageNotification object:nil];

    BOOL ok = message.state == FusionNativeMessageFinish &&
              [[message getValueFromDataTableWith:PCPingResultKey] isEqual:@"ping"];
    NSString *thread = [message getValueFromDataTableWith:PCPingThreadKey];
    BOOL onMain = [NSThread isMainThread];
    self.statusLabel.text = ok
        ? [NSString stringWithFormat:@"Fusion 消息链路：正常\nActor 线程：%@；回调线程：%@", thread, onMain ? @"main" : @"other"]
        : [NSString stringWithFormat:@"Fusion 消息链路：失败（state=%lu）", (unsigned long)message.state];
    PCLogInfo(@"Fusion self check %@, actor thread=%@, callback on main=%d", ok ? @"passed" : @"FAILED", thread, onMain);
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
