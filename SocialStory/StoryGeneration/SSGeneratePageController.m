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
@property (nonatomic, strong) UITextField *nameField;
@property (nonatomic, strong) UISegmentedControl *genderControl;
@property (nonatomic, strong) UIStepper *ageStepper;
@property (nonatomic, strong) UILabel *ageLabel;
@property (nonatomic, strong) UISegmentedControl *diagnosisControl;
@property (nonatomic, strong) UISegmentedControl *levelControl;
@property (nonatomic, strong) UITextField *interestField;
@property (nonatomic, strong) UISegmentedControl *toneControl;
@property (nonatomic, strong) UIButton *generateButton;
@property (nonatomic, strong) UIView *loadingOverlay;
@property (nonatomic, copy) NSString *pendingScene;
@end

@implementation SSGeneratePageController

- (NSString *)pageTitle { return @"生成故事"; }

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)buildPageContent {
    [self buildForm];
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

    // Child name
    y = [self addSectionLabel:@"孩子名字" atY:y margin:margin];
    self.nameField = [self addTextFieldAtY:y margin:margin width:width placeholder:@"小朋友"];
    y += 44 + 16;

    // Gender
    y = [self addSectionLabel:@"性别" atY:y margin:margin];
    self.genderControl = [self addSegmentAtY:y margin:margin width:width items:@[@"男孩", @"女孩"]];
    y += 36 + 16;

    // Age
    y = [self addSectionLabel:@"年龄" atY:y margin:margin];
    self.ageStepper = [[UIStepper alloc] initWithFrame:CGRectMake(margin, y, 0, 0)];
    self.ageStepper.minimumValue = 2;
    self.ageStepper.maximumValue = 16;
    self.ageStepper.value = 6;
    [self.ageStepper addTarget:self action:@selector(onAgeChanged) forControlEvents:UIControlEventValueChanged];
    [self.scrollView addSubview:self.ageStepper];
    self.ageLabel = [[UILabel alloc] initWithFrame:CGRectMake(margin + 110, y, width - 110, 32)];
    self.ageLabel.font = [UIFont systemFontOfSize:16];
    self.ageLabel.textColor = [SSTheme primaryTextColor];
    [self.scrollView addSubview:self.ageLabel];
    [self onAgeChanged];
    y += 40 + 16;

    // Diagnosis type
    y = [self addSectionLabel:@"诊断类型" atY:y margin:margin];
    self.diagnosisControl = [self addSegmentAtY:y margin:margin width:width
                                          items:@[@"自闭症", @"多动症", @"社交焦虑", @"其他"]];
    self.diagnosisControl.apportionsSegmentWidthsByContent = YES;
    y += 36 + 16;

    // Language level
    y = [self addSectionLabel:@"语言水平" atY:y margin:margin];
    self.levelControl = [self addSegmentAtY:y margin:margin width:width items:@[@"简单句", @"复合句", @"复杂句"]];
    y += 36 + 16;

    // Tone style
    y = [self addSectionLabel:@"语气风格" atY:y margin:margin];
    self.toneControl = [self addSegmentAtY:y margin:margin width:width items:@[@"温和", @"欢快", @"平静"]];
    y += 36 + 16;

    // Interest (optional)
    y = [self addSectionLabel:@"兴趣点（选填）" atY:y margin:margin];
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

- (void)onAgeChanged {
    self.ageLabel.text = [NSString stringWithFormat:@"%d 岁", (int)self.ageStepper.value];
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
    req.childName = self.nameField.text;
    req.gender = (self.genderControl.selectedSegmentIndex == 0) ? SSGenderBoy : SSGenderGirl;
    req.childAge = (NSInteger)self.ageStepper.value;
    req.diagnosisType = (SSDiagnosisType)self.diagnosisControl.selectedSegmentIndex;
    req.level = (SSLanguageLevel)self.levelControl.selectedSegmentIndex;
    req.tone = (SSToneStyle)self.toneControl.selectedSegmentIndex;
    req.preferredInterest = self.interestField.text;

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
