//
//  SSReaderPageController.m
//  StoryReader
//
//  Paged story player: each page shows an illustration + text, auto-plays its
//  audio, and advances to the next page when the audio finishes.
//

#import "SSReaderPageController.h"
#import <AVFoundation/AVFoundation.h>

@interface SSReaderPageController () <UIScrollViewDelegate>
@property (nonatomic, strong) SSStory *story;
@property (nonatomic, strong) UIScrollView *pager;
@property (nonatomic, strong) UIPageControl *pageControl;
@property (nonatomic, strong) NSMutableArray<UIImageView *> *imageViews;

// controls
@property (nonatomic, strong) UIView *controlBar;
@property (nonatomic, strong) UIButton *prevButton;
@property (nonatomic, strong) UIButton *playButton;
@property (nonatomic, strong) UIButton *nextButton;

// audio
@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, assign) NSInteger currentIndex;
@property (nonatomic, assign) BOOL isPlaying;

@property (nonatomic, strong) NSCache *imageCache;
@end

@implementation SSReaderPageController

- (NSString *)pageTitle { return @"故事播放"; }
- (BOOL)showsBackButton { return YES; }

- (void)processPageCommand:(NSString *)command args:(NSDictionary *)args {
    NSString *storyID = args[SSArgStoryID];
    if (storyID.length) {
        self.story = [[SSStoryStore shared] storyWithID:storyID];
        [[SSStoryStore shared] markStoryReadWithID:storyID];
        if ([self contentBuilt]) { [self reloadStory]; }
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.imageCache = [NSCache new];
    self.imageViews = [NSMutableArray array];
    self.currentIndex = 0;
    [self configureAudioSession];
}

- (void)configureAudioSession {
    NSError *err = nil;
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:&err];
    [[AVAudioSession sharedInstance] setActive:YES error:&err];
}

- (void)buildPageContent {
    [self buildUI];
    [self reloadStory];
}

- (NSArray<SSStoryPage *> *)pages { return self.story.pages ?: @[]; }

#pragma mark - UI

- (void)buildUI {
    CGFloat top = [self naviBarBottom];
    CGFloat controlsH = 88;
    CGFloat width = self.view.bounds.size.width;
    CGFloat pagerH = self.view.bounds.size.height - top - controlsH;

    self.pager = [[UIScrollView alloc] initWithFrame:CGRectMake(0, top, width, pagerH)];
    self.pager.pagingEnabled = YES;
    self.pager.showsHorizontalScrollIndicator = NO;
    self.pager.delegate = self;
    self.pager.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.pager];

    // Bottom control bar
    self.controlBar = [[UIView alloc] initWithFrame:CGRectMake(0, top + pagerH, width, controlsH)];
    self.controlBar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    self.controlBar.backgroundColor = [SSTheme cardColor];
    [self.view addSubview:self.controlBar];

    self.pageControl = [[UIPageControl alloc] initWithFrame:CGRectMake(0, 6, width, 20)];
    self.pageControl.currentPageIndicatorTintColor = [SSTheme accentColor];
    self.pageControl.pageIndicatorTintColor = [SSTheme secondaryTextColor];
    self.pageControl.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.pageControl addTarget:self action:@selector(onPageControlChanged) forControlEvents:UIControlEventValueChanged];
    [self.controlBar addSubview:self.pageControl];

    CGFloat btnY = 32; CGFloat btnH = 44;
    self.prevButton = [self controlButton:@"⏮ 上一页" action:@selector(onPrev)];
    self.playButton = [self controlButton:@"⏸ 暂停" action:@selector(onPlayPause)];
    self.nextButton = [self controlButton:@"下一页 ⏭" action:@selector(onNext)];
    CGFloat third = width / 3.0;
    self.prevButton.frame = CGRectMake(0, btnY, third, btnH);
    self.playButton.frame = CGRectMake(third, btnY, third, btnH);
    self.nextButton.frame = CGRectMake(third * 2, btnY, third, btnH);
    self.prevButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin;
    self.playButton.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.nextButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleLeftMargin;
    [self.controlBar addSubview:self.prevButton];
    [self.controlBar addSubview:self.playButton];
    [self.controlBar addSubview:self.nextButton];
}

- (UIButton *)controlButton:(NSString *)title action:(SEL)action {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    [b setTitle:title forState:UIControlStateNormal];
    [b setTitleColor:[SSTheme accentColor] forState:UIControlStateNormal];
    b.titleLabel.font = [UIFont systemFontOfSize:16];
    b.accessibilityLabel = title;
    [b addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return b;
}

#pragma mark - Load story into pages

- (void)reloadStory {
    if (!self.pager) { return; }
    NSArray<SSStoryPage *> *pages = [self pages];
    for (UIView *v in self.pager.subviews) { [v removeFromSuperview]; }
    [self.imageViews removeAllObjects];

    CGFloat w = self.pager.bounds.size.width;
    CGFloat h = self.pager.bounds.size.height;
    self.pageControl.numberOfPages = pages.count;

    for (NSUInteger i = 0; i < pages.count; i++) {
        SSStoryPage *page = pages[i];
        UIView *pageView = [[UIView alloc] initWithFrame:CGRectMake(i * w, 0, w, h)];
        pageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

        CGFloat margin = 16;
        CGFloat imgH = h * 0.5;
        UIImageView *iv = [[UIImageView alloc] initWithFrame:CGRectMake(margin, 12, w - margin * 2, imgH)];
        iv.contentMode = UIViewContentModeScaleAspectFit;
        iv.clipsToBounds = YES;
        iv.layer.cornerRadius = 10;
        iv.backgroundColor = [SSTheme cardColor];
        iv.isAccessibilityElement = YES;
        iv.accessibilityLabel = page.pageTitle ?: @"故事插图";
        [pageView addSubview:iv];
        [self.imageViews addObject:iv];
        [self loadImage:page.illustrationURL into:iv];

        UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(margin, 12 + imgH + 8, w - margin*2, 26)];
        titleLabel.font = [UIFont boldSystemFontOfSize:18];
        titleLabel.textColor = [SSTheme primaryTextColor];
        titleLabel.text = page.pageTitle;
        [pageView addSubview:titleLabel];

        UITextView *body = [[UITextView alloc] initWithFrame:
            CGRectMake(margin, 12 + imgH + 38, w - margin*2, h - (12 + imgH + 38) - 12)];
        body.editable = NO;
        body.backgroundColor = [UIColor clearColor];
        body.textColor = [SSTheme primaryTextColor];
        body.font = [UIFont systemFontOfSize:18];
        body.text = page.content;
        [pageView addSubview:body];

        [self.pager addSubview:pageView];
    }
    self.pager.contentSize = CGSizeMake(w * pages.count, h);

    if (pages.count > 0) {
        self.currentIndex = 0;
        self.pageControl.currentPage = 0;
        [self playCurrentPage];
    }
}

#pragma mark - Image loading

- (void)loadImage:(NSString *)urlString into:(UIImageView *)iv {
    if (urlString.length == 0) { return; }
    UIImage *cached = [self.imageCache objectForKey:urlString];
    if (cached) { iv.image = cached; return; }
    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) { return; }
    __weak typeof(self) weakSelf = self;
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL:url
        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        UIImage *image = data ? [UIImage imageWithData:data] : nil;
        if (!image) { return; }
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) self = weakSelf;
            if (!self) return;
            [self.imageCache setObject:image forKey:urlString];
            iv.image = image;
        });
    }];
    [task resume];
}

#pragma mark - Audio playback

- (void)playCurrentPage {
    NSArray<SSStoryPage *> *pages = [self pages];
    if (self.currentIndex < 0 || self.currentIndex >= (NSInteger)pages.count) { return; }
    SSStoryPage *page = pages[self.currentIndex];

    [self stopAudio];

    if (page.audioURL.length) {
        NSURL *url = [NSURL URLWithString:page.audioURL];
        if (url) {
            self.player = [AVPlayer playerWithURL:url];
            CGFloat rate = self.story.speakingRate > 0 ? self.story.speakingRate : 1.0;
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(onAudioFinished:)
                                                         name:AVPlayerItemDidPlayToEndTimeNotification
                                                       object:self.player.currentItem];
            [self.player play];
            self.player.rate = (float)rate;
            self.isPlaying = YES;
            [self updatePlayButton];
            return;
        }
    }
    // No audio: fall back to auto-advance by duration so the story still flows.
    self.isPlaying = YES;
    [self updatePlayButton];
    NSInteger secs = page.durationSeconds > 0 ? page.durationSeconds : 5;
    [self performSelector:@selector(advanceAfterSilentPage) withObject:nil afterDelay:secs];
}

- (void)advanceAfterSilentPage {
    if (self.isPlaying) { [self autoAdvance]; }
}

- (void)onAudioFinished:(NSNotification *)note {
    if (note.object != self.player.currentItem) { return; }
    [self autoAdvance];
}

- (void)autoAdvance {
    NSArray<SSStoryPage *> *pages = [self pages];
    if (self.currentIndex + 1 < (NSInteger)pages.count) {
        [self goToPage:self.currentIndex + 1 play:YES];
    } else {
        // Reached the end.
        self.isPlaying = NO;
        [self updatePlayButton];
    }
}

- (void)stopAudio {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(advanceAfterSilentPage) object:nil];
    if (self.player) {
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:AVPlayerItemDidPlayToEndTimeNotification
                                                      object:self.player.currentItem];
        [self.player pause];
        self.player = nil;
    }
}

- (void)updatePlayButton {
    [self.playButton setTitle:(self.isPlaying ? @"⏸ 暂停" : @"▶ 播放") forState:UIControlStateNormal];
}

#pragma mark - Controls

- (void)onPlayPause {
    if (self.isPlaying) {
        [self.player pause];
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(advanceAfterSilentPage) object:nil];
        self.isPlaying = NO;
    } else {
        if (self.player) {
            [self.player play];
            self.player.rate = self.story.speakingRate > 0 ? (float)self.story.speakingRate : 1.0;
        } else {
            [self playCurrentPage];
        }
        self.isPlaying = YES;
    }
    [self updatePlayButton];
}

- (void)onPrev {
    if (self.currentIndex > 0) { [self goToPage:self.currentIndex - 1 play:YES]; }
}

- (void)onNext {
    if (self.currentIndex + 1 < (NSInteger)[self pages].count) { [self goToPage:self.currentIndex + 1 play:YES]; }
}

- (void)onPageControlChanged {
    [self goToPage:self.pageControl.currentPage play:YES];
}

- (void)goToPage:(NSInteger)index play:(BOOL)play {
    NSArray *pages = [self pages];
    if (index < 0 || index >= (NSInteger)pages.count) { return; }
    self.currentIndex = index;
    self.pageControl.currentPage = index;
    CGFloat w = self.pager.bounds.size.width;
    [self.pager setContentOffset:CGPointMake(index * w, 0) animated:YES];
    if (play) { [self playCurrentPage]; }
}

#pragma mark - UIScrollViewDelegate (manual paging)

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    CGFloat w = scrollView.bounds.size.width;
    if (w <= 0) { return; }
    NSInteger index = (NSInteger)round(scrollView.contentOffset.x / w);
    if (index != self.currentIndex) {
        self.currentIndex = index;
        self.pageControl.currentPage = index;
        [self playCurrentPage];
    }
}

#pragma mark - Lifecycle

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    // Keep page widths in sync with the pager size.
    CGFloat w = self.pager.bounds.size.width;
    CGFloat h = self.pager.bounds.size.height;
    NSArray *subs = self.pager.subviews;
    for (NSUInteger i = 0; i < subs.count; i++) {
        UIView *v = subs[i];
        v.frame = CGRectMake(i * w, 0, w, h);
    }
    if (subs.count > 0) {
        self.pager.contentSize = CGSizeMake(w * subs.count, h);
        [self.pager setContentOffset:CGPointMake(self.currentIndex * w, 0) animated:NO];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    self.isPlaying = NO;
    [self stopAudio];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
