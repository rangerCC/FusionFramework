//
//  STSettingsPageController.m
//  SystemThinker
//
//  设置：输出详细程度（简洁/标准/完整）、默认紧急模式、清除本地缓存。
//  持久化到 NSUserDefaults。
//

#import "STSettingsPageController.h"
#import "STDefines.h"
#import "STStorageService.h"
#import <FusionUI/FusionUI.h>

@interface STSettingsPageController () {
    UISegmentedControl *_levelSeg;
    UISwitch           *_urgentSwitch;
}
@end

@implementation STSettingsPageController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.view setBackgroundColor:[UIColor systemBackgroundColor]];

    [_naviBar setBackgroundColor:[UIColor systemBlueColor]];
    UILabel *title = [UILabel new];
    [title setText:@"设置"];
    [title setTextColor:[UIColor whiteColor]];
    [title setFont:[UIFont boldSystemFontOfSize:17]];
    [title setTextAlignment:NSTextAlignmentCenter];
    [_naviBar setCenterView:title];

    UIButton *back = [UIButton buttonWithType:UIButtonTypeSystem];
    [back setTitle:@"返回" forState:UIControlStateNormal];
    [back setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [back.titleLabel setFont:[UIFont systemFontOfSize:15]];
    [back addTarget:self action:@selector(onTapBack) forControlEvents:UIControlEventTouchUpInside];
    [_naviBar setLeftView:back];

    CGFloat top = [_naviBar getNaviBarHeight] + 20;
    CGFloat width = self.view.bounds.size.width;
    NSUserDefaults *def = [NSUserDefaults standardUserDefaults];

    // 输出详细程度
    UILabel *levelLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, top, width - 32, 24)];
    levelLabel.text = @"输出详细程度";
    levelLabel.font = [UIFont systemFontOfSize:15];
    [self.view addSubview:levelLabel];

    _levelSeg = [[UISegmentedControl alloc] initWithItems:@[@"简洁", @"标准", @"完整"]];
    _levelSeg.frame = CGRectMake(16, top + 30, width - 32, 36);
    _levelSeg.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    NSString *level = [def stringForKey:ST_PREF_OUTPUT_LEVEL] ?: ST_OUTPUT_STANDARD;
    _levelSeg.selectedSegmentIndex = [self indexForLevel:level];
    [_levelSeg addTarget:self action:@selector(onLevelChanged) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:_levelSeg];

    // 默认紧急模式
    UILabel *urgentLabel = [[UILabel alloc] initWithFrame:CGRectMake(16, top + 90, width - 100, 28)];
    urgentLabel.text = @"默认紧急模式";
    urgentLabel.font = [UIFont systemFontOfSize:15];
    [self.view addSubview:urgentLabel];

    _urgentSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(width - 70, top + 88, 50, 28)];
    _urgentSwitch.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    _urgentSwitch.on = [def boolForKey:ST_PREF_DEFAULT_URGENT];
    [_urgentSwitch addTarget:self action:@selector(onUrgentChanged) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:_urgentSwitch];

    // 清除本地缓存
    UIButton *clearBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    clearBtn.frame = CGRectMake(16, top + 140, width - 32, 44);
    clearBtn.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [clearBtn setTitle:@"清除本地缓存" forState:UIControlStateNormal];
    [clearBtn setTitleColor:[UIColor systemRedColor] forState:UIControlStateNormal];
    [clearBtn addTarget:self action:@selector(onTapClear) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:clearBtn];
}

- (NSInteger)indexForLevel:(NSString *)level {
    if ([level isEqualToString:ST_OUTPUT_BRIEF]) return 0;
    if ([level isEqualToString:ST_OUTPUT_FULL]) return 2;
    return 1;
}

- (void)onLevelChanged {
    NSArray *levels = @[ST_OUTPUT_BRIEF, ST_OUTPUT_STANDARD, ST_OUTPUT_FULL];
    [[NSUserDefaults standardUserDefaults] setObject:levels[_levelSeg.selectedSegmentIndex]
                                              forKey:ST_PREF_OUTPUT_LEVEL];
}

- (void)onUrgentChanged {
    [[NSUserDefaults standardUserDefaults] setBool:_urgentSwitch.isOn forKey:ST_PREF_DEFAULT_URGENT];
}

- (void)onTapClear {
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"清除本地缓存"
                                                               message:@"将删除全部历史会话与消息，不可恢复。"
                                                        preferredStyle:UIAlertControllerStyleAlert];
    [ac addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [ac addAction:[UIAlertAction actionWithTitle:@"清除" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
        [[STStorageService sharedInstance] clearAll];
    }]];
    [self presentViewController:ac animated:YES completion:nil];
}

- (void)onTapBack {
    FusionPageMessage *message = [[FusionPageMessage alloc] initWithURL:[self getCallbackUrl] args:@{}];
    [message setNaviAnimeType:[self getNaviAnimeType]];
    [message setNaviAnimeDirection:FusionNaviAnimeBackward];
    [[self getNavigator] poptoPage:message];
}

- (void)processPageCommand:(NSString *)command args:(NSDictionary *)args {
    if (command == nil || [command isEqualToString:@"init"]) {
        NSLog(@"[SettingsPage] init: %@", args);
    }
}

@end
