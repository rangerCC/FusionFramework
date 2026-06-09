//
//  SSChildListPageController.m
//  StoryProfile
//
//  Lists the account's children; tap a row to make it the default child used by
//  story generation. Top-right "添加" pushes the edit page.
//

#import "SSChildListPageController.h"
#import <FusionUI/FusionPageNavigator+Auto.h>
#import <FusionUI/FusionNaviAnimeHelper.h>
#import <SocialStoryCore/SocialStoryCore-Swift.h>

@interface SSChildListPageController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, copy) NSArray<SSChild *> *children;
@property (nonatomic, strong) UILabel *emptyLabel;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@end

@implementation SSChildListPageController

- (NSString *)pageTitle { return @"我的孩子"; }
- (BOOL)showsBackButton { return YES; }

- (void)buildPageContent {
    CGFloat top = [self naviBarBottom];
    CGFloat bottom = [self contentBottomInset];

    // "添加" button in the nav bar's right slot.
    UIButton *add = [UIButton buttonWithType:UIButtonTypeSystem];
    [add setTitle:@"添加" forState:UIControlStateNormal];
    [add setTitleColor:[SSTheme accentColor] forState:UIControlStateNormal];
    add.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    add.frame = CGRectMake(0, 0, 44, 44);
    [add addTarget:self action:@selector(onAdd) forControlEvents:UIControlEventTouchUpInside];
    [_naviBar setRightView:add];

    self.tableView = [[UITableView alloc] initWithFrame:
        CGRectMake(0, top, self.view.bounds.size.width, self.view.bounds.size.height - top - bottom)
                                                  style:UITableViewStyleGrouped];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.backgroundColor = [SSTheme backgroundColor];
    self.tableView.rowHeight = 64;
    [self.view addSubview:self.tableView];

    UILongPressGestureRecognizer *longPress =
        [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(onLongPress:)];
    [self.tableView addGestureRecognizer:longPress];

    self.emptyLabel = [UILabel new];
    self.emptyLabel.numberOfLines = 0;
    self.emptyLabel.textAlignment = NSTextAlignmentCenter;
    self.emptyLabel.font = [UIFont systemFontOfSize:15];
    self.emptyLabel.textColor = [SSTheme secondaryTextColor];
    self.emptyLabel.text = @"还没有孩子档案\n点击右上角「添加」创建";

    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.spinner.center = CGPointMake(self.tableView.bounds.size.width / 2, 80);
    [self.tableView addSubview:self.spinner];

    [self reload];
}

- (void)enterAnimeFinish {
    [super enterAnimeFinish];
    if ([self contentBuilt]) { [self reload]; }
}

- (void)reload {
    [self.spinner startAnimating];
    __weak typeof(self) weakSelf = self;
    [[SSChildrenClient shared] fetchChildren:^(NSArray<SSChild *> *children, NSError *error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [self.spinner stopAnimating];
        if (error) {
            self.tableView.backgroundView = [self errorLabel:error.localizedDescription];
            return;
        }
        self.children = children;
        self.tableView.backgroundView = (children.count == 0) ? self.emptyLabel : nil;
        [self.tableView reloadData];
    }];
}

- (UILabel *)errorLabel:(NSString *)msg {
    UILabel *l = [UILabel new];
    l.numberOfLines = 0;
    l.textAlignment = NSTextAlignmentCenter;
    l.font = [UIFont systemFontOfSize:15];
    l.textColor = [SSTheme secondaryTextColor];
    l.text = msg ?: @"加载失败";
    return l;
}

#pragma mark - Actions

- (void)onAdd {
    FusionPageMessage *m = [[FusionPageMessage alloc] initWithPageName:SSPageChildEdit
                                                              pageNick:nil command:nil args:nil callback:nil];
    [m setNaviAnimeType:SlideR2L_NaviAnime];
    [[self getNavigator] gotoPage:m];
}

#pragma mark - Table

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.children.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return self.children.count ? @"点击查看 · 长按设为默认 · 左滑删除" : nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cid = @"ChildCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cid];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cid];
        cell.textLabel.textColor = [SSTheme primaryTextColor];
        cell.detailTextLabel.textColor = [SSTheme secondaryTextColor];
    }
    SSChild *c = self.children[indexPath.row];
    cell.textLabel.text = c.name;
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%ld岁 · %@ · %@",
        (long)c.age, [self diagnosisLabel:c.diagnosisType], [self levelLabel:c.level]];
    cell.accessoryType = c.isDefault ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    SSChild *c = self.children[indexPath.row];
    // Tap opens the (read-only) detail page, which can switch to edit.
    FusionPageMessage *m = [[FusionPageMessage alloc] initWithPageName:SSPageChildEdit
                                                              pageNick:nil
                                                               command:nil
                                                                  args:@{SSArgChildID: c.childID}
                                                              callback:nil];
    [m setNaviAnimeType:SlideR2L_NaviAnime];
    [[self getNavigator] gotoPage:m];
}

#pragma mark - Long-press: set default

- (void)onLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) { return; }
    CGPoint point = [gesture locationInView:self.tableView];
    NSIndexPath *ip = [self.tableView indexPathForRowAtPoint:point];
    if (!ip || ip.row >= (NSInteger)self.children.count) { return; }
    SSChild *c = self.children[ip.row];
    if (c.isDefault) {
        [self showAlert:@"已是默认" message:[NSString stringWithFormat:@"%@ 已是生成故事的默认孩子", c.name]];
        return;
    }
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:c.name
                                                                  message:@"设为生成故事时默认使用的孩子？"
                                                           preferredStyle:UIAlertControllerStyleActionSheet];
    [sheet addAction:[UIAlertAction actionWithTitle:@"设为默认" style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *a) { [self setDefaultChild:c]; }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:ip];
    sheet.popoverPresentationController.sourceView = cell ?: self.tableView;
    sheet.popoverPresentationController.sourceRect = cell ? cell.bounds : CGRectMake(point.x, point.y, 1, 1);
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)setDefaultChild:(SSChild *)c {
    __weak typeof(self) weakSelf = self;
    [[SSChildrenClient shared] setDefaultChildID:c.childID completion:^(BOOL success, NSError *error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        if (success) {
            [[SSChildStore shared] reloadWithCompletion:nil];
            [self reload];
        } else {
            [self showAlert:@"设置失败" message:error.localizedDescription ?: @"请重试"];
        }
    }];
}

#pragma mark - Swipe to delete

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (NSString *)tableView:(UITableView *)tableView
    titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath {
    return @"删除";
}

- (void)tableView:(UITableView *)tableView
    commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
     forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle != UITableViewCellEditingStyleDelete) { return; }
    if (indexPath.row >= (NSInteger)self.children.count) { return; }
    SSChild *c = self.children[indexPath.row];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"删除孩子档案"
        message:[NSString stringWithFormat:@"确定删除「%@」吗？此操作不可撤销。", c.name]
        preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"删除" style:UIAlertActionStyleDestructive
                                            handler:^(UIAlertAction *a) { [self deleteChild:c]; }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)deleteChild:(SSChild *)c {
    __weak typeof(self) weakSelf = self;
    [[SSChildrenClient shared] deleteChildID:c.childID completion:^(BOOL success, NSError *error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        if (success) {
            [[SSChildStore shared] reloadWithCompletion:nil];
            [self reload];
        } else {
            [self showAlert:@"删除失败" message:error.localizedDescription ?: @"请重试"];
        }
    }];
}

#pragma mark - Labels

- (NSString *)diagnosisLabel:(SSDiagnosisType)d {
    switch (d) {
        case SSDiagnosisASD: return @"自闭症";
        case SSDiagnosisADHD: return @"多动症";
        case SSDiagnosisSocialAnxiety: return @"社交焦虑";
        default: return @"其他";
    }
}
- (NSString *)levelLabel:(SSLanguageLevel)l {
    switch (l) {
        case SSLanguageLevelSimple: return @"简单句";
        case SSLanguageLevelModerate: return @"复合句";
        default: return @"复杂句";
    }
}

- (void)showAlert:(NSString *)title message:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
