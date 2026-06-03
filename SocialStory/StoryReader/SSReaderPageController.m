//
//  SSReaderPageController.m
//  StoryReader
//

#import "SSReaderPageController.h"
#import <AVFoundation/AVFoundation.h>

@interface SSReaderPageController () <AVSpeechSynthesizerDelegate>
@property (nonatomic, strong) SSStory *story;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) UITextView *bodyView;

@property (nonatomic, strong) AVSpeechSynthesizer *synth;
@property (nonatomic, strong) UIButton *playButton;
@property (nonatomic, strong) UISlider *rateSlider;
@property (nonatomic, strong) UIStepper *fontStepper;
@property (nonatomic, assign) CGFloat bodyFontSize;
@property (nonatomic, assign) BOOL isSpeaking;
@end

@implementation SSReaderPageController

- (NSString *)pageTitle { return @"阅读"; }
- (BOOL)showsBackButton { return YES; }

- (void)processPageCommand:(NSString *)command args:(NSDictionary *)args {
    NSString *storyID = args[SSArgStoryID];
    if (storyID.length) {
        self.story = [[SSStoryStore shared] storyWithID:storyID];
        [[SSStoryStore shared] markStoryReadWithID:storyID];
        if ([self contentBuilt]) {
            [self render];
        }
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.bodyFontSize = [SSTheme defaultBodyFontSize];
    self.synth = [AVSpeechSynthesizer new];
    self.synth.delegate = self;
}

- (void)buildPageContent {
    [self buildUI];
    [self render];
}

- (void)buildUI {
    CGFloat top = [self naviBarBottom];
    CGFloat controlsHeight = 96;
    CGFloat width = self.view.bounds.size.width;

    self.scrollView = [[UIScrollView alloc] initWithFrame:
        CGRectMake(0, top, width, self.view.bounds.size.height - top - controlsHeight)];
    self.scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.scrollView];

    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.numberOfLines = 0;
    self.titleLabel.font = [UIFont boldSystemFontOfSize:24];
    self.titleLabel.textColor = [SSTheme primaryTextColor];
    [self.scrollView addSubview:self.titleLabel];

    self.imageView = [[UIImageView alloc] init];
    self.imageView.contentMode = UIViewContentModeScaleAspectFill;
    self.imageView.clipsToBounds = YES;
    self.imageView.layer.cornerRadius = 10;
    [self.scrollView addSubview:self.imageView];

    self.bodyView = [[UITextView alloc] init];
    self.bodyView.editable = NO;
    self.bodyView.scrollEnabled = NO;
    self.bodyView.backgroundColor = [UIColor clearColor];
    self.bodyView.textColor = [SSTheme primaryTextColor];
    [self.scrollView addSubview:self.bodyView];

    // Bottom controls bar
    UIView *bar = [[UIView alloc] initWithFrame:
        CGRectMake(0, self.view.bounds.size.height - controlsHeight, width, controlsHeight)];
    bar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    bar.backgroundColor = [SSTheme cardColor];
    [self.view addSubview:bar];

    self.playButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.playButton.frame = CGRectMake(16, 12, 80, 36);
    [self.playButton setTitle:@"▶ 朗读" forState:UIControlStateNormal];
    [self.playButton setTitleColor:[SSTheme accentColor] forState:UIControlStateNormal];
    self.playButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    self.playButton.accessibilityLabel = @"朗读全文";
    [self.playButton addTarget:self action:@selector(onPlayPause) forControlEvents:UIControlEventTouchUpInside];
    [bar addSubview:self.playButton];

    UILabel *rateTag = [[UILabel alloc] initWithFrame:CGRectMake(108, 12, 40, 36)];
    rateTag.text = @"语速"; rateTag.font = [UIFont systemFontOfSize:13];
    rateTag.textColor = [SSTheme secondaryTextColor];
    [bar addSubview:rateTag];

    self.rateSlider = [[UISlider alloc] initWithFrame:CGRectMake(150, 12, width - 166, 36)];
    self.rateSlider.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.rateSlider.minimumValue = 0.4;
    self.rateSlider.maximumValue = 0.8;
    self.rateSlider.value = [[NSUserDefaults standardUserDefaults] objectForKey:@"ss_speech_rate"]
        ? [[NSUserDefaults standardUserDefaults] floatForKey:@"ss_speech_rate"] : 0.5;
    self.rateSlider.accessibilityLabel = @"朗读语速";
    [self.rateSlider addTarget:self action:@selector(onRateChanged) forControlEvents:UIControlEventValueChanged];
    [bar addSubview:self.rateSlider];

    UILabel *fontTag = [[UILabel alloc] initWithFrame:CGRectMake(16, 54, 40, 32)];
    fontTag.text = @"字号"; fontTag.font = [UIFont systemFontOfSize:13];
    fontTag.textColor = [SSTheme secondaryTextColor];
    [bar addSubview:fontTag];

    self.fontStepper = [[UIStepper alloc] initWithFrame:CGRectMake(60, 54, 0, 0)];
    self.fontStepper.minimumValue = [SSTheme minBodyFontSize];
    self.fontStepper.maximumValue = [SSTheme maxBodyFontSize];
    self.fontStepper.stepValue = 2;
    self.fontStepper.value = self.bodyFontSize;
    self.fontStepper.accessibilityLabel = @"调节字号";
    [self.fontStepper addTarget:self action:@selector(onFontChanged) forControlEvents:UIControlEventValueChanged];
    [bar addSubview:self.fontStepper];
}

- (void)render {
    if (!self.story) return;
    self.titleLabel.text = self.story.title;
    self.bodyView.font = [UIFont systemFontOfSize:self.bodyFontSize];
    self.bodyView.text = self.story.content;

    if (self.story.imageURL.length) {
        [self loadImage:self.story.imageURL];
    } else {
        self.imageView.hidden = YES;
    }
    [self.view setNeedsLayout];
    [self layoutContent];
}

- (void)layoutContent {
    CGFloat margin = 16;
    CGFloat width = self.scrollView.bounds.size.width - margin * 2;
    CGFloat y = 16;

    CGSize titleSize = [self.titleLabel sizeThatFits:CGSizeMake(width, CGFLOAT_MAX)];
    self.titleLabel.frame = CGRectMake(margin, y, width, titleSize.height);
    y += titleSize.height + 12;

    if (!self.imageView.hidden) {
        self.imageView.frame = CGRectMake(margin, y, width, width * 0.56);
        y += width * 0.56 + 12;
    }

    CGSize bodySize = [self.bodyView sizeThatFits:CGSizeMake(width, CGFLOAT_MAX)];
    self.bodyView.frame = CGRectMake(margin, y, width, bodySize.height);
    y += bodySize.height + 24;

    self.scrollView.contentSize = CGSizeMake(self.scrollView.bounds.size.width, y);
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self layoutContent];
}
- (void)loadImage:(NSString *)urlString {
    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) { self.imageView.hidden = YES; return; }
    __weak typeof(self) weakSelf = self;
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL:url
        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        UIImage *image = data ? [UIImage imageWithData:data] : nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            if (image) {
                self.imageView.hidden = NO;
                self.imageView.image = image;
            } else {
                self.imageView.hidden = YES;
            }
            [self layoutContent];
        });
    }];
    [task resume];
}

#pragma mark - Speech

- (void)onPlayPause {
    if (self.synth.isPaused) {
        [self.synth continueSpeaking];
        [self.playButton setTitle:@"⏸ 暂停" forState:UIControlStateNormal];
    } else if (self.synth.isSpeaking) {
        [self.synth pauseSpeakingAtBoundary:AVSpeechBoundaryWord];
        [self.playButton setTitle:@"▶ 继续" forState:UIControlStateNormal];
    } else {
        AVSpeechUtterance *u = [AVSpeechUtterance speechUtteranceWithString:self.story.content ?: @""];
        u.rate = self.rateSlider.value;
        u.voice = [AVSpeechSynthesisVoice voiceWithLanguage:@"zh-CN"];
        [self.synth speakUtterance:u];
        [self.playButton setTitle:@"⏸ 暂停" forState:UIControlStateNormal];
    }
}

- (void)onRateChanged {
    [[NSUserDefaults standardUserDefaults] setFloat:self.rateSlider.value forKey:@"ss_speech_rate"];
}

- (void)onFontChanged {
    self.bodyFontSize = self.fontStepper.value;
    self.bodyView.font = [UIFont systemFontOfSize:self.bodyFontSize];
    [self layoutContent];
}

- (void)speechSynthesizer:(AVSpeechSynthesizer *)synthesizer didFinishSpeechUtterance:(AVSpeechUtterance *)utterance {
    [self.playButton setTitle:@"▶ 朗读" forState:UIControlStateNormal];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    if (self.synth.isSpeaking) {
        [self.synth stopSpeakingAtBoundary:AVSpeechBoundaryImmediate];
    }
}

@end
