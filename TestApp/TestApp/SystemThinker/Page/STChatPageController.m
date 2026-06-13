//
//  STChatPageController.m
//  SystemThinker
//

#import "STChatPageController.h"
#import "STMessageCell.h"
#import "STModels.h"
#import "STStorageService.h"
#import "STDefines.h"
#import "STSpeechRecognizer.h"
#import "STVoiceHUD.h"
#import "TRIPServiceMacro.h"
#import "TRIPPageMacro.h"
#import <FusionCore/FusionCore.h>
#import <FusionBase/FusionBase.h>
#import <WebViewKit/WebViewKit.h>

static NSString *const kCellId = @"STMessageCell";
static const CGFloat kInputBarHeight = 132.0;  // 输入区固定高度（快捷标签+开关+输入行）
static const CGFloat kContextCardHeight = 52.0;

@interface STChatPageController () <STMessageCellDelegate> {
    UIView          *_contextCard;
    UILabel         *_contextLabel;
    UITableView     *_tableView;

    UIView          *_inputBar;
    UITextView      *_inputView;
    UIButton        *_sendButton;
    UIButton        *_micButton;
    UISwitch        *_urgentSwitch;
    UIView          *_quickTagsBar;
    UIActivityIndicatorView *_loading;

    UIButton        *_holdToTalkButton;  // 语音模式下的「按住 说话」按钮
    BOOL             _voiceMode;          // 是否处于语音输入模式
    BOOL             _cancelArmed;        // 当前是否处于上滑取消态
    STSpeechRecognizer *_speech;
    STVoiceHUD      *_voiceHUD;

    NSMutableArray<STMessage *> *_messages;
    STSession       *_session;
    BOOL             _sending;
    CGFloat          _keyboardHeight;  // 当前键盘遮挡高度（已弹起时 >0）
    STMessage       *_thinkingMessage; // 助手"思考中"占位气泡（收到回复后替换/移除）
    NSMutableDictionary<NSString *, NSNumber *> *_webHeightCache; // messageId -> 助手气泡行高
    NSString        *_typewriterMessageId; // 需走打字机的最新助手消息
    FusionNativeMessage *_currentMessage;  // 当前进行中的流式消息
}
@end

@implementation STChatPageController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.view setBackgroundColor:[UIColor systemBackgroundColor]];
    _messages = [NSMutableArray array];
    _webHeightCache = [NSMutableDictionary dictionary];

    [self setupNaviBar];
    [self setupContextCard];
    [self setupTableView];
    [self setupInputBar];

    [self registerKeyboardObservers];
    [self startNewSessionIfNeeded];

    // 预热 WebView 池，降低首条助手气泡渲染延迟
    [[WKWebViewPool sharedPool] prewarm:2];
}

#pragma mark - 键盘

- (void)registerKeyboardObservers {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onKeyboardWillChange:)
                                                 name:UIKeyboardWillChangeFrameNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onKeyboardWillHide:)
                                                 name:UIKeyboardWillHideNotification object:nil];
}

- (void)onKeyboardWillChange:(NSNotification *)note {
    CGRect endFrame = [note.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    NSTimeInterval duration = [note.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    // 键盘顶部在本视图坐标系中的位置，换算出遮挡高度
    CGRect kbInView = [self.view convertRect:endFrame fromView:nil];
    CGFloat overlap = CGRectGetMaxY(self.view.bounds) - CGRectGetMinY(kbInView);
    _keyboardHeight = MAX(0, overlap);
    [UIView animateWithDuration:(duration > 0 ? duration : 0.25) animations:^{
        [self.view setNeedsLayout];
        [self.view layoutIfNeeded];
    } completion:^(BOOL finished) {
        [self scrollToBottom];
    }];
}

- (void)onKeyboardWillHide:(NSNotification *)note {
    NSTimeInterval duration = [note.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    _keyboardHeight = 0;
    [UIView animateWithDuration:(duration > 0 ? duration : 0.25) animations:^{
        [self.view setNeedsLayout];
        [self.view layoutIfNeeded];
    }];
}

#pragma mark - 布局

// 集中布局：在 safeArea 生效后计算各容器 frame，并响应键盘弹起。
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    CGFloat width = self.view.bounds.size.width;
    CGFloat height = self.view.bounds.size.height;
    CGFloat naviH = [_naviBar getNaviBarHeight];
    CGFloat bottomInset = 0;
    if (@available(iOS 11.0, *)) {
        bottomInset = self.view.safeAreaInsets.bottom;
    }

    // 上下文卡片紧贴导航栏下方
    _contextCard.frame = CGRectMake(8, naviH + 6, width - 16, kContextCardHeight);
    _contextLabel.frame = CGRectInset(_contextCard.bounds, 12, 8);

    // 输入区：键盘弹起时整体上移 _keyboardHeight；未弹起时贴底部安全区
    CGFloat inputBarY;
    if (_keyboardHeight > 0) {
        inputBarY = height - _keyboardHeight - kInputBarHeight;
    } else {
        inputBarY = height - bottomInset - kInputBarHeight;
    }
    _inputBar.frame = CGRectMake(0, inputBarY, width, kInputBarHeight);

    // 输入区内部右对齐元素按 _inputBar 真实宽度重新布局（避免用 viewDidLoad 阶段的旧宽度）
    CGFloat barW = _inputBar.bounds.size.width;
    _quickTagsBar.frame = CGRectMake(0, 6, barW, 34);
    _sendButton.frame = CGRectMake(barW - 8 - 64, 42, 64, 30);
    _loading.center = CGPointMake(_sendButton.center.x, _sendButton.center.y);
    _micButton.frame = CGRectMake(barW - 8 - 40, 80, 40, 44);
    _inputView.frame = CGRectMake(8, 80, barW - 8 - 40 - 8 - 8, 44);
    _holdToTalkButton.frame = _inputView.frame;

    // 消息列表填充卡片与输入区之间
    CGFloat tableTop = CGRectGetMaxY(_contextCard.frame) + 4;
    _tableView.frame = CGRectMake(0, tableTop, width, inputBarY - tableTop);
}

- (void)setupNaviBar {
    [_naviBar setBackgroundColor:[UIColor systemBlueColor]];

    UILabel *title = [UILabel new];
    [title setText:@"SystemThinker"];
    [title setTextColor:[UIColor whiteColor]];
    [title setFont:[UIFont boldSystemFontOfSize:17]];
    [title setTextAlignment:NSTextAlignmentCenter];
    [_naviBar setCenterView:title];

    // 右侧：新会话 "+"
    UIButton *newBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [newBtn setTitle:@"+" forState:UIControlStateNormal];
    [newBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [newBtn.titleLabel setFont:[UIFont systemFontOfSize:28]];
    [newBtn addTarget:self action:@selector(onTapNewSession) forControlEvents:UIControlEventTouchUpInside];
    [_naviBar setRightView:newBtn];

    // 左侧：历史
    UIButton *historyBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [historyBtn setTitle:@"历史" forState:UIControlStateNormal];
    [historyBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [historyBtn.titleLabel setFont:[UIFont systemFontOfSize:15]];
    [historyBtn addTarget:self action:@selector(onTapHistory) forControlEvents:UIControlEventTouchUpInside];
    [_naviBar setLeftView:historyBtn];
}

- (void)setupContextCard {
    _contextCard = [[UIView alloc] initWithFrame:CGRectZero];
    _contextCard.backgroundColor = [UIColor secondarySystemBackgroundColor];
    _contextCard.layer.cornerRadius = 10;

    _contextLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    _contextLabel.numberOfLines = 2;
    _contextLabel.font = [UIFont systemFontOfSize:13];
    _contextLabel.textColor = [UIColor secondaryLabelColor];
    _contextLabel.text = @"当前问题：（新会话）";
    _contextLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [_contextCard addSubview:_contextLabel];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onTapContextCard)];
    [_contextCard addGestureRecognizer:tap];
    [self.view addSubview:_contextCard];
}

- (void)setupTableView {
    _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    _tableView.dataSource = self;
    _tableView.delegate = self;
    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    _tableView.backgroundColor = [UIColor systemBackgroundColor];
    _tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    [_tableView registerClass:[STMessageCell class] forCellReuseIdentifier:kCellId];
    [self.view addSubview:_tableView];

    // 点击空白收起键盘
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissKeyboard)];
    tap.cancelsTouchesInView = NO;
    [_tableView addGestureRecognizer:tap];
}

- (void)setupInputBar {
    CGFloat width = self.view.bounds.size.width;
    _inputBar = [[UIView alloc] initWithFrame:CGRectZero];
    _inputBar.backgroundColor = [UIColor secondarySystemBackgroundColor];
    [self.view addSubview:_inputBar];

    // 快捷标签栏
    _quickTagsBar = [[UIView alloc] initWithFrame:CGRectMake(0, 6, width, 34)];
    _quickTagsBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    NSArray *tags = @[@"🔍 发现问题", @"📊 分析原因", @"🚀 制定方案", @"🎤 组织汇报"];
    CGFloat tagX = 8;
    for (NSInteger i = 0; i < tags.count; i++) {
        UIButton *tagBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        [tagBtn setTitle:tags[i] forState:UIControlStateNormal];
        [tagBtn.titleLabel setFont:[UIFont systemFontOfSize:12]];
        tagBtn.tag = i;
        tagBtn.backgroundColor = [UIColor tertiarySystemBackgroundColor];
        tagBtn.layer.cornerRadius = 12;
        [tagBtn addTarget:self action:@selector(onTapQuickTag:) forControlEvents:UIControlEventTouchUpInside];
        CGSize sz = [tags[i] sizeWithAttributes:@{NSFontAttributeName:[UIFont systemFontOfSize:12]}];
        tagBtn.frame = CGRectMake(tagX, 2, sz.width + 20, 28);
        tagX += sz.width + 28;
        [_quickTagsBar addSubview:tagBtn];
    }
    [_inputBar addSubview:_quickTagsBar];

    // 第二行：左侧"紧急模式"开关，右侧"发送"按钮（一左一右对称）
    UILabel *urgentLabel = [[UILabel alloc] initWithFrame:CGRectMake(8, 44, 80, 28)];
    urgentLabel.text = @"⏱️ 紧急模式";
    urgentLabel.font = [UIFont systemFontOfSize:13];
    urgentLabel.textColor = [UIColor labelColor];
    [_inputBar addSubview:urgentLabel];

    _urgentSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(92, 42, 50, 28)];
    _urgentSwitch.transform = CGAffineTransformMakeScale(0.8, 0.8);
    _urgentSwitch.on = [[NSUserDefaults standardUserDefaults] boolForKey:ST_PREF_DEFAULT_URGENT];
    [_inputBar addSubview:_urgentSwitch];

    // 发送按钮：与紧急模式同一行，置于最右侧
    _sendButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [_sendButton setTitle:@"发送" forState:UIControlStateNormal];
    [_sendButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [_sendButton setTitleColor:[UIColor lightGrayColor] forState:UIControlStateDisabled];
    _sendButton.backgroundColor = [UIColor systemBlueColor];
    _sendButton.layer.cornerRadius = 6;
    _sendButton.frame = CGRectMake(width - 72, 42, 64, 30);
    _sendButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    _sendButton.enabled = NO;
    [_sendButton addTarget:self action:@selector(onTapSend) forControlEvents:UIControlEventTouchUpInside];
    [_inputBar addSubview:_sendButton];

    // 加载指示器（覆盖发送按钮位置）
    _loading = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    _loading.center = CGPointMake(_sendButton.center.x, _sendButton.center.y);
    _loading.hidesWhenStopped = YES;
    _loading.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [_inputBar addSubview:_loading];

    // 第三行：多行自动折行输入框（固定宽度）+ 右侧麦克风
    _micButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [_micButton setTitle:@"🎙️" forState:UIControlStateNormal];
    _micButton.frame = CGRectMake(width - 48, 80, 40, 44);
    _micButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [_micButton addTarget:self action:@selector(onTapMic) forControlEvents:UIControlEventTouchUpInside];
    [_inputBar addSubview:_micButton];

    _inputView = [[UITextView alloc] initWithFrame:CGRectMake(8, 80, width - 8 - 52, 44)];
    _inputView.font = [UIFont systemFontOfSize:16];
    _inputView.layer.cornerRadius = 8;
    _inputView.backgroundColor = [UIColor systemBackgroundColor];
    _inputView.delegate = self;
    _inputView.scrollEnabled = YES;        // 超出高度后内部滚动，宽度固定自动折行
    _inputView.textContainer.lineBreakMode = NSLineBreakByWordWrapping;
    _inputView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [_inputBar addSubview:_inputView];

    // 语音模式下的「按住 说话」按钮（与输入框同位置，默认隐藏）
    _holdToTalkButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [_holdToTalkButton setTitle:@"按住 说话" forState:UIControlStateNormal];
    [_holdToTalkButton setTitleColor:[UIColor labelColor] forState:UIControlStateNormal];
    _holdToTalkButton.titleLabel.font = [UIFont systemFontOfSize:16];
    _holdToTalkButton.backgroundColor = [UIColor systemBackgroundColor];
    _holdToTalkButton.layer.cornerRadius = 8;
    _holdToTalkButton.frame = CGRectMake(8, 80, width - 8 - 52, 44);
    _holdToTalkButton.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _holdToTalkButton.hidden = YES;
    [_holdToTalkButton addTarget:self action:@selector(onTalkTouchDown:) forControlEvents:UIControlEventTouchDown];
    [_holdToTalkButton addTarget:self action:@selector(onTalkTouchDrag:withEvent:) forControlEvents:UIControlEventTouchDragInside | UIControlEventTouchDragOutside];
    [_holdToTalkButton addTarget:self action:@selector(onTalkTouchUp:withEvent:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside];
    [_holdToTalkButton addTarget:self action:@selector(onTalkTouchCancel:) forControlEvents:UIControlEventTouchCancel];
    [_inputBar addSubview:_holdToTalkButton];
}

#pragma mark - 会话管理

- (void)startNewSessionIfNeeded {
    if (_session != nil) return;
    _session = [STSession new];
    _session.sessionId = [[NSUUID UUID] UUIDString];
    _session.title = @"新会话";
    _session.lastContext = ST_CONTEXT_NONE;
    _session.lastUpdateTime = [[NSDate date] timeIntervalSince1970];
    _thinkingMessage = nil;
    [_messages removeAllObjects];
    [_tableView reloadData];
    _contextLabel.text = @"当前问题：（新会话）";
}

// 从历史载入会话，设为当前活动会话（替换当前）
- (void)loadSession:(NSString *)sessionId {
    STSession *session = [[STStorageService sharedInstance] sessionById:sessionId];
    if (session == nil) return;
    _session = session;
    if (_session.lastContext.length == 0) {
        _session.lastContext = ST_CONTEXT_NONE;
    }
    _thinkingMessage = nil;
    [_messages removeAllObjects];
    [_messages addObjectsFromArray:[[STStorageService sharedInstance] messagesForSession:sessionId]];
    [_tableView reloadData];
    [self scrollToBottom];

    // 恢复上下文卡片
    if (_session.problemSummary.length > 0 || _session.completedStages.length > 0) {
        NSString *stagesStr = @"";
        id stages = [_session.completedStages jsonObject];
        if ([stages isKindOfClass:[NSArray class]]) {
            stagesStr = [(NSArray *)stages componentsJoinedByString:@" → "];
        }
        _contextLabel.text = [NSString stringWithFormat:@"当前问题：%@\n已完成：%@",
                              _session.problemSummary ?: @"", stagesStr];
    } else {
        _contextLabel.text = @"当前问题：（新会话）";
    }
}

#pragma mark - 消息流

- (void)onTapSend {
    NSString *text = [_inputView.text stringByTrimmingCharactersInSet:
                      [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (text.length == 0 || _sending) return;

    // 追加用户消息
    STMessage *userMsg = [STMessage new];
    userMsg.messageId = [[NSUUID UUID] UUIDString];
    userMsg.sessionId = _session.sessionId;
    userMsg.role = STMessageRoleUser;
    userMsg.content = text;
    userMsg.timestamp = [[NSDate date] timeIntervalSince1970];
    [self appendMessage:userMsg];
    [[STStorageService sharedInstance] saveMessage:userMsg];

    _inputView.text = @"";
    [self setSending:YES];

    // 助手侧"思考中"占位气泡（非持久化，收到回复后替换/失败后移除）
    _thinkingMessage = [STMessage new];
    _thinkingMessage.messageId = [[NSUUID UUID] UUIDString];
    _thinkingMessage.sessionId = _session.sessionId;
    _thinkingMessage.role = STMessageRoleAssistant;
    _thinkingMessage.content = @"思考中…";
    _thinkingMessage.timestamp = [[NSDate date] timeIntervalSince1970];
    [self appendMessage:_thinkingMessage];

    // 组装 FusionNativeMessage 投递 CozeService
    NSString *level = [[NSUserDefaults standardUserDefaults] stringForKey:ST_PREF_OUTPUT_LEVEL] ?: ST_OUTPUT_STANDARD;
    NSDictionary *args = @{
        ST_ARG_USER_INPUT:      text,
        ST_ARG_SESSION_CONTEXT: _session.lastContext ?: ST_CONTEXT_NONE,
        ST_ARG_OUTPUT_LEVEL:    level,
        ST_ARG_IS_URGENT:       @(_urgentSwitch.isOn)
    };
    FusionNativeMessage *msg = [[FusionNativeMessage alloc] initWithSerivice:COZESERVICE_SERVICE
                                                                       actor:WORKFLOW_ACTOR
                                                                        args:args];
    _currentMessage = msg;
    __weak typeof(self) weakSelf = self;
    // 监听消息完成（回调在发起线程，即主线程）
    [[NSNotificationCenter defaultCenter] addObserverForName:FusionNativeMessageNotification
                                                      object:msg
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note) {
        [weakSelf handleCozeResult:(FusionNativeMessage *)note.object];
    }];
    // 监听流式节点进度（升级"思考中"为节点名）
    [[NSNotificationCenter defaultCenter] addObserverForName:ST_STREAM_PROGRESS_NOTIFICATION
                                                      object:msg
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note) {
        [weakSelf handleStreamProgress:note.userInfo[ST_PROGRESS_TEXT]];
    }];
    [[FusionCore getInstance] asyncSendMessage:msg];
}

// 流式节点进度：更新"思考中"气泡文案
- (void)handleStreamProgress:(NSString *)text {
    if (text.length == 0 || _thinkingMessage == nil) return;
    _thinkingMessage.content = text;
    NSInteger row = [self rowForMessageId:_thinkingMessage.messageId];
    if (row != NSNotFound) {
        [_tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:row inSection:0]]
                          withRowAnimation:UITableViewRowAnimationNone];
    }
}

- (void)handleCozeResult:(FusionNativeMessage *)msg {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:FusionNativeMessageNotification object:msg];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:ST_STREAM_PROGRESS_NOTIFICATION object:msg];
    _currentMessage = nil;
    [self setSending:NO];

    // 移除"思考中"占位气泡
    if (_thinkingMessage) {
        [_messages removeObject:_thinkingMessage];
        _thinkingMessage = nil;
    }

    if (msg.state != FusionNativeMessageFinish) {
        [_tableView reloadData];
        NSString *err = [msg getValueFromDataTableWith:ST_RESULT_ERROR_MSG] ?: @"请求失败，请稍后重试";
        [self showAlert:err];
        return;
    }

    NSString *analysis = [msg getValueFromDataTableWith:ST_RESULT_ANALYSIS];
    NSString *newContext = [msg getValueFromDataTableWith:ST_RESULT_NEW_CONTEXT];

    // 追加助手消息（标记为打字机目标）
    STMessage *aMsg = [STMessage new];
    aMsg.messageId = [[NSUUID UUID] UUIDString];
    aMsg.sessionId = _session.sessionId;
    aMsg.role = STMessageRoleAssistant;
    aMsg.content = analysis;
    aMsg.timestamp = [[NSDate date] timeIntervalSince1970];
    aMsg.contextSnapshot = newContext;
    _typewriterMessageId = aMsg.messageId;  // 仅这条走打字机
    [self appendMessage:aMsg];
    [[STStorageService sharedInstance] saveMessage:aMsg];

    // 更新会话状态 + 上下文卡片
    if (newContext.length > 0) {
        _session.lastContext = newContext;
        [self updateContextCardWithJson:newContext];
    }
    _session.lastUpdateTime = [[NSDate date] timeIntervalSince1970];
    if ([_session.title isEqualToString:@"新会话"] && _session.problemSummary.length > 0) {
        _session.title = [_session.problemSummary length] > 20
            ? [[_session.problemSummary substringToIndex:20] stringByAppendingString:@"…"]
            : _session.problemSummary;
    }
    [[STStorageService sharedInstance] saveSession:_session];
}

- (void)updateContextCardWithJson:(NSString *)json {
    NSDictionary *ctx = [json jsonObject];
    if (![ctx isKindOfClass:[NSDictionary class]]) return;
    NSString *summary = ctx[@"problem_summary"] ?: @"";
    _session.problemSummary = summary;
    id stages = ctx[@"completed_stages"];
    NSString *stagesStr = @"";
    if ([stages isKindOfClass:[NSArray class]]) {
        stagesStr = [(NSArray *)stages componentsJoinedByString:@" → "];
        _session.completedStages = [(NSArray *)stages jsonString];
    }
    _contextLabel.text = [NSString stringWithFormat:@"当前问题：%@\n已完成：%@", summary, stagesStr];
}

#pragma mark - 列表

- (void)appendMessage:(STMessage *)message {
    [_messages addObject:message];
    [_tableView reloadData];
    [self scrollToBottom];
}

- (void)scrollToBottom {
    if (_messages.count == 0) return;
    NSIndexPath *ip = [NSIndexPath indexPathForRow:_messages.count - 1 inSection:0];
    [_tableView scrollToRowAtIndexPath:ip atScrollPosition:UITableViewScrollPositionBottom animated:YES];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _messages.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    STMessageCell *cell = [tableView dequeueReusableCellWithIdentifier:kCellId forIndexPath:indexPath];
    cell.delegate = self;
    STMessage *m = _messages[indexPath.row];
    BOOL typewriter = (m.role == STMessageRoleAssistant &&
                       [m.messageId isEqualToString:_typewriterMessageId]);
    [cell configureWithMessage:m typewriter:typewriter];
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    STMessage *m = _messages[indexPath.row];
    CGFloat width = tableView.bounds.size.width;
    if (m.role == STMessageRoleUser) {
        return [STMessageCell userBubbleHeightForMessage:m width:width];
    }
    // 助手气泡：用 WebView 回传缓存的高度；未测得前给估算值
    NSNumber *cached = _webHeightCache[m.messageId ?: @""];
    if (cached) return cached.doubleValue;
    return 80.0;  // 估算占位，WebView 测得后通过 delegate 刷新
}

#pragma mark - STMessageCellDelegate

- (void)messageCell:(STMessageCell *)cell didMeasureHeight:(CGFloat)height forMessageId:(NSString *)messageId {
    if (messageId.length == 0) return;
    NSNumber *old = _webHeightCache[messageId];
    if (old && fabs(old.doubleValue - height) < 1.0) return;  // 高度没变，跳过
    _webHeightCache[messageId] = @(height);
    // 找到该消息所在行，局部刷新高度（避免整表 reload 打断打字机）
    NSInteger row = [self rowForMessageId:messageId];
    if (row == NSNotFound) return;
    [UIView performWithoutAnimation:^{
        [self->_tableView beginUpdates];
        [self->_tableView endUpdates];
    }];
}

- (NSInteger)rowForMessageId:(NSString *)messageId {
    for (NSInteger i = 0; i < _messages.count; i++) {
        if ([_messages[i].messageId isEqualToString:messageId]) return i;
    }
    return NSNotFound;
}

#pragma mark - 动作

- (void)onTapQuickTag:(UIButton *)sender {
    NSArray *texts = @[
        @"我遇到了一个困扰，但说不清楚问题出在哪里……",
        @"请帮我分析这个现象背后的原因……",
        @"针对这个问题，帮我制定解决方案……",
        @"帮我把以下内容组织成汇报稿……"
    ];
    if (sender.tag >= texts.count) return;
    NSString *text = texts[sender.tag];
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"发送该示例？"
                                                               message:text
                                                        preferredStyle:UIAlertControllerStyleAlert];
    [ac addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    __weak typeof(self) weakSelf = self;
    [ac addAction:[UIAlertAction actionWithTitle:@"发送" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf == nil) return;
        [strongSelf setInputText:text];
        [strongSelf onTapSend];
    }]];
    [self presentViewController:ac animated:YES completion:nil];
}

- (void)onTapNewSession {
    // 当前会话为空（无任何消息）时无需确认，直接开
    if (_messages.count == 0) {
        _session = nil;
        [self startNewSessionIfNeeded];
        return;
    }
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"开启新会话"
                                                               message:@"将清空当前对话，历史记录仍可在「历史」中查看。"
                                                        preferredStyle:UIAlertControllerStyleAlert];
    [ac addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    __weak typeof(self) weakSelf = self;
    [ac addAction:[UIAlertAction actionWithTitle:@"新会话" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        strongSelf->_session = nil;
        [strongSelf startNewSessionIfNeeded];
    }]];
    [self presentViewController:ac animated:YES completion:nil];
}

- (void)onTapHistory {
    NSURL *callbackUrl = [FusionPageNavigator generateCallbackUrl:self];
    FusionPageMessage *m = [[FusionPageMessage alloc] initWithPageName:HISTORYPAGE_PAGE
                                                              pageNick:nil command:@"init" args:@{} callback:callbackUrl];
    [m setNaviAnimeType:SlideR2L_NaviAnime];
    [[self getNavigator] gotoPage:m];
}

- (void)onTapContextCard {
    if (_session.lastContext.length == 0) return;
    [self showAlert:_session.lastContext];
}

- (void)onTapMic {
    [self setVoiceMode:!_voiceMode];
}

#pragma mark - 语音输入（按住说话）

- (void)setVoiceMode:(BOOL)voiceMode {
    _voiceMode = voiceMode;
    _inputView.hidden = voiceMode;
    _holdToTalkButton.hidden = !voiceMode;
    [_micButton setTitle:(voiceMode ? @"🔴" : @"🎙️") forState:UIControlStateNormal];
    if (voiceMode) {
        [_inputView resignFirstResponder];
    }
}

// 按下：请求权限 → 启动识别 + 显示 HUD
- (void)onTalkTouchDown:(UIButton *)btn {
    if (_speech == nil) {
        _speech = [STSpeechRecognizer new];
    }
    if (_voiceHUD == nil) {
        _voiceHUD = [STVoiceHUD new];
    }
    __weak typeof(self) weakSelf = self;
    [_speech requestAuthorization:^(STSpeechAuthStatus status) {
        __strong typeof(weakSelf) self = weakSelf;
        if (self == nil) return;
        if (status != STSpeechAuthStatusAuthorized) {
            [self showAuthDeniedAlert:status];
            return;
        }
        [self beginRecording];
    }];
}

- (void)beginRecording {
    _cancelArmed = NO;
    [_holdToTalkButton setTitle:@"松开 发送" forState:UIControlStateNormal];
    _holdToTalkButton.backgroundColor = [UIColor systemGray4Color];
    [_voiceHUD showInView:self.view];

    STVoiceHUD *hud = _voiceHUD;
    _speech.onPartialText = ^(NSString *text) {
        [hud updateText:text];
    };
    NSError *error = nil;
    if (![_speech startRecording:&error]) {
        [_voiceHUD hide];
        [_holdToTalkButton setTitle:@"按住 说话" forState:UIControlStateNormal];
        _holdToTalkButton.backgroundColor = [UIColor systemBackgroundColor];
        [self showAlert:@"录音启动失败，请重试"];
    }
}

// 拖动：根据手指是否上滑出按钮上方，切换取消态
- (void)onTalkTouchDrag:(UIButton *)btn withEvent:(UIEvent *)event {
    if (!_speech.isRecording) return;
    UITouch *touch = [[event touchesForView:btn] anyObject];
    if (touch == nil) return;
    CGPoint p = [touch locationInView:btn];
    // 手指移到按钮顶部以上 20pt 即进入取消区
    BOOL armed = (p.y < -20);
    if (armed != _cancelArmed) {
        _cancelArmed = armed;
        [_voiceHUD setCancelHighlighted:armed];
        [_holdToTalkButton setTitle:(armed ? @"松开手指，取消" : @"松开 发送") forState:UIControlStateNormal];
    }
}

// 松手：取消态丢弃，正常态取最终文本并发送
- (void)onTalkTouchUp:(UIButton *)btn withEvent:(UIEvent *)event {
    [_holdToTalkButton setTitle:@"按住 说话" forState:UIControlStateNormal];
    _holdToTalkButton.backgroundColor = [UIColor systemBackgroundColor];
    [_voiceHUD hide];

    if (!_speech.isRecording) return;

    if (_cancelArmed) {
        [_speech cancelRecording];
        _cancelArmed = NO;
        return;
    }

    __weak typeof(self) weakSelf = self;
    [_speech stopRecordingWithCompletion:^(NSString *finalText) {
        __strong typeof(weakSelf) self = weakSelf;
        if (self == nil) return;
        NSString *text = [finalText stringByTrimmingCharactersInSet:
                          [NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (text.length == 0) {
            [self showAlert:@"没听清，请重试"];
            return;
        }
        // 复用现有发送流程：写入隐藏的输入框后触发发送
        [self setInputText:text];
        [self onTapSend];
    }];
}

- (void)onTalkTouchCancel:(UIButton *)btn {
    [_holdToTalkButton setTitle:@"按住 说话" forState:UIControlStateNormal];
    _holdToTalkButton.backgroundColor = [UIColor systemBackgroundColor];
    [_voiceHUD hide];
    [_speech cancelRecording];
    _cancelArmed = NO;
}

- (void)showAuthDeniedAlert:(STSpeechAuthStatus)status {
    NSString *msg = (status == STSpeechAuthStatusUnavailable)
        ? @"当前设备不支持语音识别"
        : @"未获得麦克风/语音识别权限，请在「设置」中开启";
    [self showAlert:msg];
}

#pragma mark - 辅助

- (void)setSending:(BOOL)sending {
    _sending = sending;
    _sendButton.hidden = sending;
    if (sending) { [_loading startAnimating]; } else { [_loading stopAnimating]; }
    [self updateSendEnabled];
}

- (void)updateSendEnabled {
    NSString *text = [_inputView.text stringByTrimmingCharactersInSet:
                      [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    _sendButton.enabled = (text.length > 0 && !_sending);
}

- (void)dismissKeyboard {
    [_inputView resignFirstResponder];
}

- (void)setInputText:(NSString *)text {
    _inputView.text = text;
}

- (void)showAlert:(NSString *)message {
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:nil message:message preferredStyle:UIAlertControllerStyleAlert];
    [ac addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:ac animated:YES completion:nil];
}

#pragma mark - UITextViewDelegate

- (void)textViewDidChange:(UITextView *)textView {
    [self updateSendEnabled];
}

#pragma mark - 页面命令

- (void)processPageCommand:(NSString *)command args:(NSDictionary *)args {
    // 从历史记录载入指定会话（携带 session_id）
    NSString *sessionId = [args objectForKey:@"session_id"];
    if (sessionId.length > 0) {
        // 视图未加载时（singleton 首次）确保已初始化
        [self view];
        if (_voiceMode) { [self setVoiceMode:NO]; }
        [self loadSession:sessionId];
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end


