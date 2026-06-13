//
//  STHistoryPageController.m
//  SystemThinker
//
//  历史会话列表：从 SQLite 读取，长按删除/重命名。
//

#import "STHistoryPageController.h"
#import "STStorageService.h"
#import "STModels.h"
#import <FusionUI/FusionUI.h>

static NSString *const kHistoryCellId = @"STHistoryCell";

@interface STHistoryPageController () {
    UITableView *_tableView;
    NSArray<STSession *> *_sessions;
}
@end

@implementation STHistoryPageController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.view setBackgroundColor:[UIColor systemBackgroundColor]];

    [_naviBar setBackgroundColor:[UIColor systemBlueColor]];
    UILabel *title = [UILabel new];
    [title setText:@"历史记录"];
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

    CGFloat top = [_naviBar getNaviBarHeight];
    _tableView = [[UITableView alloc] initWithFrame:
                  CGRectMake(0, top, self.view.bounds.size.width, self.view.bounds.size.height - top)
                                              style:UITableViewStylePlain];
    _tableView.dataSource = self;
    _tableView.delegate = self;
    _tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:_tableView];

    [self reload];
}

- (void)reload {
    _sessions = [[STStorageService sharedInstance] allSessions];
    [_tableView reloadData];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _sessions.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kHistoryCellId];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:kHistoryCellId];
    }
    STSession *s = _sessions[indexPath.row];
    cell.textLabel.text = s.title.length > 0 ? s.title : @"未命名会话";
    cell.detailTextLabel.text = s.problemSummary;
    cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    STSession *s = _sessions[indexPath.row];
    // 回到 ChatPage（singleton）并载入该会话历史
    FusionPageMessage *message = [[FusionPageMessage alloc] initWithPageName:@"ChatPage"
                                                                    pageNick:nil
                                                                     command:@"init"
                                                                        args:@{@"session_id": s.sessionId ?: @""}
                                                                    callback:nil];
    [message setNaviAnimeType:[self getNaviAnimeType]];
    [message setNaviAnimeDirection:FusionNaviAnimeBackward];
    [[self getNavigator] poptoPage:message];
}

// 长按 -> 删除/重命名
- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView
trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    STSession *s = _sessions[indexPath.row];
    __weak typeof(self) weakSelf = self;
    UIContextualAction *del = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive
                                                                      title:@"删除"
                                                                    handler:^(UIContextualAction *a, UIView *v, void (^done)(BOOL)) {
        [[STStorageService sharedInstance] deleteSession:s.sessionId];
        [weakSelf reload];
        done(YES);
    }];
    UIContextualAction *rename = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                                        title:@"重命名"
                                                                      handler:^(UIContextualAction *a, UIView *v, void (^done)(BOOL)) {
        [weakSelf promptRename:s];
        done(YES);
    }];
    return [UISwipeActionsConfiguration configurationWithActions:@[del, rename]];
}

- (void)promptRename:(STSession *)session {
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"重命名会话" message:nil preferredStyle:UIAlertControllerStyleAlert];
    [ac addTextFieldWithConfigurationHandler:^(UITextField *tf) { tf.text = session.title; }];
    [ac addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    __weak typeof(self) weakSelf = self;
    [ac addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        NSString *name = ac.textFields.firstObject.text;
        [[STStorageService sharedInstance] updateSessionTitle:name forId:session.sessionId];
        [weakSelf reload];
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
    if ([command isEqualToString:@"init"]) {
        [self reload];
    }
}

@end
