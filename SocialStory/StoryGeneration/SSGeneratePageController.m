//
//  SSGeneratePageController.m
//  StoryGeneration
//

#import "SSGeneratePageController.h"
#import <FusionUI/FusionPageNavigator+Auto.h>
#import <FusionUI/FusionNaviAnimeHelper.h>
#import <SocialStoryCore/SocialStoryCore-Swift.h>

@interface SSGeneratePageController () <UITextViewDelegate>
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UITextView *sceneTextView;
@property (nonatomic, strong) UILabel *scenePlaceholder;
@property (nonatomic, strong) UITextView *difficultyTextView;
@property (nonatomic, strong) UILabel *difficultyPlaceholder;
@property (nonatomic, strong) UISegmentedControl *toneControl;
@property (nonatomic, strong) UITextField *interestField;
@property (nonatomic, strong) UIButton *generateButton;
@property (nonatomic, strong) UIView *loadingOverlay;
@property (nonatomic, copy) NSString *pendingScene;

// Current-child card
@property (nonatomic, strong) UIView *childCard;
@property (nonatomic, strong) UILabel *childNameLabel;
@property (nonatomic, strong) UILabel *childMetaLabel;
@property (nonatomic, strong) UIButton *changeChildButton;
@property (nonatomic, strong) SSChild *selectedChild;
@end

@implementation SSGeneratePageController

- (NSString *)pageTitle { return @"生成故事"; }

- (void)viewDidLoad {
    [super viewDidLoad];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onChildrenChanged)
                                                 name:SSChildrenDidChangeNotification
                                               object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)buildPageContent {
    [self buildForm];
    // Pull the latest children so the card reflects the current default.
    [[SSChildStore shared] reloadWithCompletion:nil];
    [self refreshChildCard];
}

- (void)enterAnimeFinish {
    [super enterAnimeFinish];
    if ([self contentBuilt]) {
        [[SSChildStore shared] reloadWithCompletion:nil];
        [self refreshChildCard];
    }
}

- (void)onChildrenChanged {
    if ([self contentBuilt]) { [self refreshChildCard]; }
}

- (void)buildForm {
    CGFloat top = [self naviBarBottom];
    CGFloat bottom = [self contentBottomInset];
    self.scrollView = [[UIScrollView alloc] initWithFrame:
        CGRectMake(0, top, self.view.bounds.size.width, self.view.bounds.size.height - top - bottom)];
    self.scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.scrollView.alwaysBounceVertical = YES;
    self.scrollView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    [self.view addSubview:self.scrollView];

    CGFloat margin = 16;
    CGFloat width = self.view.bounds.size.width - margin * 2;
    CGFloat y = 16;

    // Current-child card (replaces the manual name/gender/age/diagnosis/level form).
    y = [self addSectionLabel:@"为谁创建" atY:y margin:margin];
    self.childCard = [[UIView alloc] initWithFrame:CGRectMake(margin, y, width, 72)];
    self.childCard.backgroundColor = [SSTheme cardColor];
    self.childCard.layer.cornerRadius = 12;
    self.childCard.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.scrollView addSubview:self.childCard];

    self.childNameLabel = [[UILabel alloc] initWithFrame:CGRectMake(14, 12, width - 90, 24)];
    self.childNameLabel.font = [UIFont boldSystemFontOfSize:17];
    self.childNameLabel.textColor = [SSTheme primaryTextColor];
    self.childNameLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.childCard addSubview:self.childNameLabel];

    self.childMetaLabel = [[UILabel alloc] initWithFrame:CGRectMake(14, 38, width - 90, 20)];
    self.childMetaLabel.font = [UIFont systemFontOfSize:13];
    self.childMetaLabel.textColor = [SSTheme secondaryTextColor];
    self.childMetaLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.childCard addSubview:self.childMetaLabel];

    self.changeChildButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.changeChildButton.frame = CGRectMake(width - 76, 20, 64, 32);
    [self.changeChildButton setTitle:@"更换" forState:UIControlStateNormal];
    [self.changeChildButton setTitleColor:[SSTheme accentColor] forState:UIControlStateNormal];
    self.changeChildButton.titleLabel.font = [UIFont systemFontOfSize:15];
    self.changeChildButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [self.changeChildButton addTarget:self action:@selector(onChangeChild) forControlEvents:UIControlEventTouchUpInside];
    [self.childCard addSubview:self.changeChildButton];
    y += 72 + 16;

    // Social scenario
    y = [self addSectionLabel:@"社交情境描述（50-500字）" atY:y margin:margin];
    self.sceneTextView = [self addTextViewAtY:y margin:margin width:width height:90];
    self.scenePlaceholder = [self addPlaceholder:@"例如：课间想和同学聊天，但不知道怎么开口" forTextView:self.sceneTextView];
    y += 90 + 8;

    UIButton *tplButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [tplButton setTitle:@"从模板选择 →" forState:UIControlStateNormal];
    [tplButton setTitleColor:[SSTheme accentColor] forState:UIControlStateNormal];
    tplButton.titleLabel.font = [UIFont systemFontOfSize:15];
    tplButton.frame = CGRectMake(margin, y, width, 28);
    tplButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    [tplButton addTarget:self action:@selector(onSelectTemplate) forControlEvents:UIControlEventTouchUpInside];
    [self.scrollView addSubview:tplButton];
    y += 28 + 16;

    // Difficulty detail
    y = [self addSectionLabel:@"具体困难表现" atY:y margin:margin];
    self.difficultyTextView = [self addTextViewAtY:y margin:margin width:width height:70];
    self.difficultyPlaceholder = [self addPlaceholder:@"例如：会紧张、不敢主动说话" forTextView:self.difficultyTextView];
    y += 70 + 16;

    // Tone style
    y = [self addSectionLabel:@"语气风格" atY:y margin:margin];
    self.toneControl = [self addSegmentAtY:y margin:margin width:width items:@[@"温和", @"欢快", @"平静"]];
    y += 36 + 16;

    // Interest (optional; overrides the child's interests for this story)
    y = [self addSectionLabel:@"兴趣点（选填，覆盖默认）" atY:y margin:margin];
    self.interestField = [self addTextFieldAtY:y margin:margin width:width placeholder:@"如：恐龙、火车、太空"];
    y += 44 + 28;

    self.generateButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.generateButton.frame = CGRectMake(margin, y, width, 50);
    self.generateButton.backgroundColor = [SSTheme accentColor];
    [self.generateButton setTitle:@"生成故事" forState:UIControlStateNormal];
    [self.generateButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.generateButton.titleLabel.font = [UIFont boldSystemFontOfSize:18];
    self.generateButton.layer.cornerRadius = 12;
    self.generateButton.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.generateButton addTarget:self action:@selector(onGenerate) forControlEvents:UIControlEventTouchUpInside];
    [self.scrollView addSubview:self.generateButton];
    y += 50 + 24;

    self.scrollView.contentSize = CGSizeMake(self.view.bounds.size.width, y);

    if (self.pendingScene.length) {
        self.sceneTextView.text = self.pendingScene;
        self.scenePlaceholder.hidden = YES;
        self.pendingScene = nil;
    }
}

#pragma mark - Child card

- (void)refreshChildCard {
    SSChild *child = [SSChildStore shared].defaultChild;
    self.selectedChild = child;
    if (child) {
        self.childNameLabel.text = child.name;
        self.childMetaLabel.text = [NSString stringWithFormat:@"%ld岁 · %@ · %@",
            (long)child.age, [self diagnosisLabel:child.diagnosisType], [self levelLabel:child.level]];
        [self.changeChildButton setTitle:@"更换" forState:UIControlStateNormal];
    } else {
        self.childNameLabel.text = @"还没有孩子档案";
        self.childMetaLabel.text = @"点这里添加一个孩子";
        [self.changeChildButton setTitle:@"添加" forState:UIControlStateNormal];
    }
}

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

- (void)onChangeChild {
    NSArray<SSChild *> *children = [SSChildStore shared].children;
    if (children.count == 0) {
        [self gotoChildList];
        return;
    }
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"选择孩子" message:nil
                                                           preferredStyle:UIAlertControllerStyleActionSheet];
    for (SSChild *c in children) {
        NSString *title = c.isDefault ? [c.name stringByAppendingString:@"（默认）"] : c.name;
        [sheet addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction *a) {
            [[SSChildStore shared] selectChild:c];
            [self refreshChildCard];
        }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"管理孩子…" style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *a) { [self gotoChildList]; }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    sheet.popoverPresentationController.sourceView = self.changeChildButton;
    sheet.popoverPresentationController.sourceRect = self.changeChildButton.bounds;
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)gotoChildList {
    FusionPageMessage *m = [[FusionPageMessage alloc] initWithPageName:SSPageChildList
                                                              pageNick:nil command:nil args:nil callback:nil];
    [m setNaviAnimeType:SlideR2L_NaviAnime];
    [[self getNavigator] gotoPage:m];
}

#pragma mark - Form helpers

- (UITextView *)addTextViewAtY:(CGFloat)y margin:(CGFloat)margin width:(CGFloat)width height:(CGFloat)height {
    UITextView *tv = [[UITextView alloc] initWithFrame:CGRectMake(margin, y, width, height)];
    tv.font = [UIFont systemFontOfSize:16];
    tv.layer.cornerRadius = 8;
    tv.layer.borderWidth = 1;
    tv.layer.borderColor = [SSTheme secondaryTextColor].CGColor;
    tv.backgroundColor = [SSTheme cardColor];
    tv.textColor = [SSTheme primaryTextColor];
    tv.delegate = self;
    tv.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.scrollView addSubview:tv];
    return tv;
}

- (UILabel *)addPlaceholder:(NSString *)text forTextView:(UITextView *)tv {
    UILabel *ph = [[UILabel alloc] initWithFrame:CGRectMake(tv.frame.origin.x + 5, tv.frame.origin.y + 8, tv.frame.size.width - 10, 22)];
    ph.text = text;
    ph.font = [UIFont systemFontOfSize:16];
    ph.textColor = [SSTheme secondaryTextColor];
    [self.scrollView addSubview:ph];
    return ph;
}

- (UITextField *)addTextFieldAtY:(CGFloat)y margin:(CGFloat)margin width:(CGFloat)width placeholder:(NSString *)placeholder {
    UITextField *tf = [[UITextField alloc] initWithFrame:CGRectMake(margin, y, width, 44)];
    tf.borderStyle = UITextBorderStyleRoundedRect;
    tf.placeholder = placeholder;
    tf.font = [UIFont systemFontOfSize:16];
    tf.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.scrollView addSubview:tf];
    return tf;
}

- (UISegmentedControl *)addSegmentAtY:(CGFloat)y margin:(CGFloat)margin width:(CGFloat)width items:(NSArray *)items {
    UISegmentedControl *seg = [[UISegmentedControl alloc] initWithItems:items];
    seg.frame = CGRectMake(margin, y, width, 36);
    seg.selectedSegmentIndex = 0;
    seg.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.scrollView addSubview:seg];
    return seg;
}

- (CGFloat)addSectionLabel:(NSString *)text atY:(CGFloat)y margin:(CGFloat)margin {
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(margin, y, self.view.bounds.size.width - margin * 2, 22)];
    label.text = text;
    label.font = [UIFont boldSystemFontOfSize:15];
    label.textColor = [SSTheme secondaryTextColor];
    [self.scrollView addSubview:label];
    return y + 22 + 6;
}

- (void)textViewDidChange:(UITextView *)textView {
    if (textView == self.sceneTextView) {
        self.scenePlaceholder.hidden = textView.text.length > 0;
    } else if (textView == self.difficultyTextView) {
        self.difficultyPlaceholder.hidden = textView.text.length > 0;
    }
}

#pragma mark - Actions

- (void)onSelectTemplate {
    NSURL *callback = [FusionPageNavigator generateCallbackUrl:self];
    callback = [NSURL URLWithString:[NSString stringWithFormat:@"%@#%@",
                                     [callback absoluteString], SSCommandFillScene]];
    FusionPageMessage *message = [[FusionPageMessage alloc] initWithPageName:SSPageTemplate
                                                                    pageNick:nil
                                                                     command:nil
                                                                        args:nil
                                                                    callback:callback];
    [message setNaviAnimeType:SlideR2L_NaviAnime];
    [[self getNavigator] gotoPage:message];
}

- (void)processPageCommand:(NSString *)command args:(NSDictionary *)args {
    if ([command isEqualToString:SSCommandFillScene]) {
        NSString *scene = args[SSArgSceneText];
        if (scene.length) {
            self.pendingScene = scene;
            if (self.sceneTextView) {
                self.sceneTextView.text = scene;
                self.scenePlaceholder.hidden = YES;
                self.pendingScene = nil;
            }
        }
    }
}

- (void)onGenerate {
    // Require at least one child profile before generating.
    if (![SSChildStore shared].hasAnyChild) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"还没有孩子档案"
                                                                      message:@"请先添加一位孩子，才能生成专属故事。"
                                                               preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"去添加" style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction *a) { [self gotoChildList]; }]];
        [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    SSChild *child = self.selectedChild ?: [SSChildStore shared].defaultChild;
    if (!child) { [self gotoChildList]; return; }

    if (self.sceneTextView.text.length < 4) {
        [self showAlert:@"请完善信息" message:@"请先描述社交情境"];
        return;
    }
    if (![SubscriptionManager.shared canGenerateStory]) {
        [self promptSubscription];
        return;
    }
    [self.view endEditing:YES];
    [self showLoading:YES];

    SSStoryGenerationRequest *req = [SSStoryGenerationRequest new];
    req.socialScenario = self.sceneTextView.text;
    req.difficultyDetail = self.difficultyTextView.text;
    req.childName = child.name;
    req.gender = child.gender;
    req.childAge = child.age;
    req.diagnosisType = child.diagnosisType;
    req.level = child.level;
    req.tone = (SSToneStyle)self.toneControl.selectedSegmentIndex;
    // The optional interest field overrides the child's stored interests for
    // this story; otherwise fall back to the child's first interest.
    NSString *typedInterest = [self.interestField.text stringByTrimmingCharactersInSet:
        [NSCharacterSet whitespaceCharacterSet]];
    req.preferredInterest = typedInterest.length ? typedInterest : [child.interests firstObject];

    __weak typeof(self) weakSelf = self;
    [[SSStoryAPIClient shared] generateStoryWithRequest:req completion:^(SSStory *story, NSError *error) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) return;
        [self showLoading:NO];
        if (error || !story) {
            [self showAlert:@"生成失败" message:error.localizedDescription ?: @"请稍后重试"];
            return;
        }
        [[SSStoryStore shared] saveStory:story];
        [SubscriptionManager.shared consumeFreeQuota];
        [self openReaderForStory:story];
    }];
}

- (void)promptSubscription {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"本月免费次数已用完"
                                                                  message:@"订阅后可无限生成故事"
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"去订阅" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        FusionPageMessage *m = [[FusionPageMessage alloc] initWithPageName:SSPageSubscription
                                                                  pageNick:nil command:nil args:nil callback:nil];
        [m setNaviAnimeType:SlideR2L_NaviAnime];
        [[self getNavigator] gotoPage:m];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)openReaderForStory:(SSStory *)story {
    FusionPageMessage *m = [[FusionPageMessage alloc] initWithPageName:SSPageReader
                                                              pageNick:nil
                                                               command:nil
                                                                  args:@{SSArgStoryID: story.storyID}
                                                              callback:nil];
    [m setNaviAnimeType:SlideR2L_NaviAnime];
    [[self getNavigator] gotoPage:m];
}

- (void)showAlert:(NSString *)title message:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showLoading:(BOOL)show {
    if (show) {
        if (!self.loadingOverlay) {
            self.loadingOverlay = [[UIView alloc] initWithFrame:self.view.bounds];
            self.loadingOverlay.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.4];
            self.loadingOverlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc]
                initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
            spinner.color = [UIColor whiteColor];
            spinner.center = CGPointMake(self.loadingOverlay.bounds.size.width / 2,
                                         self.loadingOverlay.bounds.size.height / 2);
            spinner.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin |
                                       UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
            [spinner startAnimating];
            [self.loadingOverlay addSubview:spinner];
            self.loadingOverlay.accessibilityLabel = @"正在生成故事";
        }
        [self.view addSubview:self.loadingOverlay];
    } else {
        [self.loadingOverlay removeFromSuperview];
    }
}

@end
