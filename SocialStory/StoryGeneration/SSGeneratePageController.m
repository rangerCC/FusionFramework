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
@property (nonatomic, strong) UITextField *nameField;
@property (nonatomic, strong) UIStepper *ageStepper;
@property (nonatomic, strong) UILabel *ageLabel;
@property (nonatomic, strong) UISegmentedControl *levelControl;
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
    CGFloat top = [_naviBar getNaviBarHeight];
    CGFloat bottom = [self contentBottomInset];
    self.scrollView = [[UIScrollView alloc] initWithFrame:
        CGRectMake(0, top, self.view.bounds.size.width, self.view.bounds.size.height - top - bottom)];
    self.scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.scrollView.alwaysBounceVertical = YES;
    [self.view addSubview:self.scrollView];

    CGFloat margin = 16;
    CGFloat width = self.view.bounds.size.width - margin * 2;
    CGFloat y = 16;

    y = [self addSectionLabel:@"场景描述" atY:y margin:margin];
    self.sceneTextView = [[UITextView alloc] initWithFrame:CGRectMake(margin, y, width, 100)];
    self.sceneTextView.font = [UIFont systemFontOfSize:16];
    self.sceneTextView.layer.cornerRadius = 8;
    self.sceneTextView.layer.borderWidth = 1;
    self.sceneTextView.layer.borderColor = [SSTheme secondaryTextColor].CGColor;
    self.sceneTextView.backgroundColor = [SSTheme cardColor];
    self.sceneTextView.textColor = [SSTheme primaryTextColor];
    self.sceneTextView.delegate = self;
    self.sceneTextView.accessibilityLabel = @"场景描述输入框";
    self.sceneTextView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.scrollView addSubview:self.sceneTextView];

    self.scenePlaceholder = [[UILabel alloc] initWithFrame:CGRectMake(margin + 5, y + 8, width - 10, 22)];
    self.scenePlaceholder.text = @"例如：第一次去医院打针";
    self.scenePlaceholder.font = [UIFont systemFontOfSize:16];
    self.scenePlaceholder.textColor = [SSTheme secondaryTextColor];
    [self.scrollView addSubview:self.scenePlaceholder];
    y += 100 + 8;

    UIButton *tplButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [tplButton setTitle:@"从模板选择 →" forState:UIControlStateNormal];
    [tplButton setTitleColor:[SSTheme accentColor] forState:UIControlStateNormal];
    tplButton.titleLabel.font = [UIFont systemFontOfSize:15];
    tplButton.frame = CGRectMake(margin, y, width, 28);
    tplButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    [tplButton addTarget:self action:@selector(onSelectTemplate) forControlEvents:UIControlEventTouchUpInside];
    [self.scrollView addSubview:tplButton];
    y += 28 + 16;

    y = [self addSectionLabel:@"儿童名字" atY:y margin:margin];
    self.nameField = [[UITextField alloc] initWithFrame:CGRectMake(margin, y, width, 44)];
    self.nameField.borderStyle = UITextBorderStyleRoundedRect;
    self.nameField.placeholder = @"小朋友";
    self.nameField.font = [UIFont systemFontOfSize:16];
    self.nameField.accessibilityLabel = @"儿童名字";
    self.nameField.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.scrollView addSubview:self.nameField];
    y += 44 + 16;

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

    y = [self addSectionLabel:@"语言水平" atY:y margin:margin];
    self.levelControl = [[UISegmentedControl alloc] initWithItems:@[@"简单", @"标准"]];
    self.levelControl.frame = CGRectMake(margin, y, width, 36);
    self.levelControl.selectedSegmentIndex = 0;
    self.levelControl.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.scrollView addSubview:self.levelControl];
    y += 36 + 32;

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
    self.scenePlaceholder.hidden = textView.text.length > 0;
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
    if (![SubscriptionManager.shared canGenerateStory]) {
        [self promptSubscription];
        return;
    }
    [self.view endEditing:YES];
    [self showLoading:YES];

    SSStoryGenerationRequest *req = [SSStoryGenerationRequest new];
    req.sceneText = self.sceneTextView.text;
    req.childName = self.nameField.text;
    req.childAge = (NSInteger)self.ageStepper.value;
    req.level = (self.levelControl.selectedSegmentIndex == 0) ? SSLanguageLevelSimple : SSLanguageLevelStandard;

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
