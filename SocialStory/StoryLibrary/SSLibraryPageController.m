//
//  SSLibraryPageController.m
//  StoryLibrary
//

#import "SSLibraryPageController.h"
#import "SSSegmentTabBar.h"
#import "SSStoryCardCell.h"
#import <CoreData/CoreData.h>
#import <FusionUI/FusionPageNavigator+Auto.h>
#import <FusionUI/FusionNaviAnimeHelper.h>

typedef NS_ENUM(NSInteger, SSLibraryTab) {
    SSLibraryTabDemo = 0,   // 精选故事
    SSLibraryTabUser = 1,   // 我创建的故事
};

static const CGFloat kTabBarHeight = 44.0;
static const CGFloat kColumnGap = 12.0;
static const CGFloat kLineGap = 12.0;
static const CGFloat kSectionInset = 12.0;
static const NSInteger kColumnCount = 2;

@interface SSLibraryPageController () <UICollectionViewDataSource, UICollectionViewDelegateFlowLayout,
                                       NSFetchedResultsControllerDelegate, UIGestureRecognizerDelegate>
@property (nonatomic, strong) SSSegmentTabBar *segmentTabBar;
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) NSFetchedResultsController *frc;
@property (nonatomic, strong) NSArray<SSStory *> *demoStories;
@property (nonatomic, assign) SSLibraryTab currentTab;
@property (nonatomic, strong) UILabel *emptyLabel;
@end

@implementation SSLibraryPageController

- (NSString *)pageTitle { return @"我的故事"; }

- (void)viewDidLoad {
    [super viewDidLoad];
    self.currentTab = SSLibraryTabDemo;
    self.demoStories = [SSDemoStories allStories];

    self.frc = [[SSStoryStore shared] fetchedResultsControllerWithDelegate:self];
    [self.frc performFetch:NULL];
}

#pragma mark - Build UI

- (void)buildPageContent {
    CGFloat top = [self naviBarBottom];
    CGFloat bottom = [self contentBottomInset];
    CGFloat width = self.view.bounds.size.width;

    self.segmentTabBar = [[SSSegmentTabBar alloc] initWithTitles:@[@"精选故事", @"我创建的故事"]];
    self.segmentTabBar.frame = CGRectMake(0, top, width, kTabBarHeight);
    self.segmentTabBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.segmentTabBar.selectedIndex = self.currentTab;
    __weak typeof(self) weakSelf = self;
    self.segmentTabBar.onSelect = ^(NSInteger index) {
        [weakSelf switchToTab:(SSLibraryTab)index];
    };
    [self.view addSubview:self.segmentTabBar];

    CGFloat listTop = top + kTabBarHeight;
    UICollectionViewFlowLayout *layout = [UICollectionViewFlowLayout new];
    layout.minimumInteritemSpacing = kColumnGap;
    layout.minimumLineSpacing = kLineGap;
    layout.sectionInset = UIEdgeInsetsMake(kSectionInset, kSectionInset, kSectionInset, kSectionInset);

    self.collectionView = [[UICollectionView alloc] initWithFrame:
        CGRectMake(0, listTop, width, self.view.bounds.size.height - listTop - bottom)
                                                            collectionViewLayout:layout];
    self.collectionView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.collectionView.backgroundColor = [SSTheme backgroundColor];
    self.collectionView.alwaysBounceVertical = YES;
    self.collectionView.dataSource = self;
    self.collectionView.delegate = self;
    [self.collectionView registerClass:[SSStoryCardCell class]
            forCellWithReuseIdentifier:[SSStoryCardCell reuseID]];
    [self.view addSubview:self.collectionView];

    UIRefreshControl *refresh = [UIRefreshControl new];
    [refresh addTarget:self action:@selector(onRefresh:) forControlEvents:UIControlEventValueChanged];
    self.collectionView.refreshControl = refresh;

    // Long-press to delete (user stories only).
    UILongPressGestureRecognizer *longPress =
        [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(onLongPress:)];
    longPress.delegate = self;
    [self.collectionView addGestureRecognizer:longPress];

    // Empty-state label, shown via collectionView.backgroundView when needed.
    self.emptyLabel = [UILabel new];
    self.emptyLabel.numberOfLines = 0;
    self.emptyLabel.textAlignment = NSTextAlignmentCenter;
    self.emptyLabel.font = [UIFont systemFontOfSize:15];
    self.emptyLabel.textColor = [SSTheme secondaryTextColor];
    self.emptyLabel.text = @"还没有故事\n去「生成」创建一个吧";

    [self.collectionView reloadData];
    [self updateEmptyState];
}

#pragma mark - Tab switching

- (void)switchToTab:(SSLibraryTab)tab {
    if (tab == self.currentTab) { return; }
    self.currentTab = tab;
    [self.collectionView setContentOffset:CGPointZero animated:NO];
    [self.collectionView reloadData];
    [self updateEmptyState];
}

#pragma mark - Data

- (NSInteger)currentCount {
    return (self.currentTab == SSLibraryTabDemo) ? (NSInteger)self.demoStories.count
                                                 : (NSInteger)self.frc.fetchedObjects.count;
}

- (SSStory *)storyAtIndex:(NSInteger)index {
    if (self.currentTab == SSLibraryTabDemo) {
        if (index < 0 || index >= (NSInteger)self.demoStories.count) { return nil; }
        return self.demoStories[index];
    }
    NSManagedObject *obj = [self.frc objectAtIndexPath:[NSIndexPath indexPathForRow:index inSection:0]];
    return [[SSStoryStore shared] storyFromManagedObject:obj];
}

- (void)updateEmptyState {
    BOOL empty = (self.currentTab == SSLibraryTabUser) && ([self currentCount] == 0);
    self.collectionView.backgroundView = empty ? self.emptyLabel : nil;
}

#pragma mark - Refresh

- (void)onRefresh:(UIRefreshControl *)refresh {
    [self.frc performFetch:NULL];
    [self.collectionView reloadData];
    [self updateEmptyState];
    [refresh endRefreshing];
}

// The navigator adds pages via addSubview (no UIViewController containment), so
// viewWillAppear is not reliably re-driven on pop — enterAnimeFinish is. Refresh
// user stories here so a story created and then backed-out-to shows up. (User
// edits made while this page is live already arrive via the FRC delegate.)
- (void)enterAnimeFinish {
    [super enterAnimeFinish];
    if (![self contentBuilt]) { return; }
    [self.frc performFetch:NULL];
    if (self.currentTab == SSLibraryTabUser) {
        [self.collectionView reloadData];
        [self updateEmptyState];
    }
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return [self currentCount];
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                  cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    SSStoryCardCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:[SSStoryCardCell reuseID]
                                                                     forIndexPath:indexPath];
    SSStory *story = [self storyAtIndex:indexPath.item];
    [cell configureWithStory:story isDemo:(self.currentTab == SSLibraryTabDemo)];
    return cell;
}

#pragma mark - UICollectionViewDelegateFlowLayout

- (CGFloat)columnWidth {
    CGFloat available = self.collectionView.bounds.size.width - kSectionInset * 2;
    available -= kColumnGap * (kColumnCount - 1);
    return floor(available / (CGFloat)kColumnCount);
}

- (CGSize)collectionView:(UICollectionView *)collectionView
                  layout:(UICollectionViewLayout *)collectionViewLayout
  sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    CGFloat w = [self columnWidth];
    SSStory *story = [self storyAtIndex:indexPath.item];
    CGFloat h = story ? [SSStoryCardCell heightForStory:story width:w] : w;
    return CGSizeMake(w, h);
}

#pragma mark - Selection

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    SSStory *story = [self storyAtIndex:indexPath.item];
    if (!story) { return; }
    FusionPageMessage *m = [[FusionPageMessage alloc] initWithPageName:SSPageReader
                                                              pageNick:nil
                                                               command:nil
                                                                  args:@{SSArgStoryID: story.storyID}
                                                              callback:nil];
    [m setNaviAnimeType:SlideR2L_NaviAnime];
    [[self getNavigator] gotoPage:m];
}

#pragma mark - Long-press delete (user stories only)

- (void)onLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) { return; }
    if (self.currentTab != SSLibraryTabUser) { return; }

    CGPoint point = [gesture locationInView:self.collectionView];
    NSIndexPath *indexPath = [self.collectionView indexPathForItemAtPoint:point];
    if (!indexPath) { return; }

    SSStory *story = [self storyAtIndex:indexPath.item];
    if (!story) { return; }

    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:story.title
                                                                  message:@"删除这个故事？此操作不可撤销。"
                                                           preferredStyle:UIAlertControllerStyleActionSheet];
    [sheet addAction:[UIAlertAction actionWithTitle:@"删除" style:UIAlertActionStyleDestructive
                                            handler:^(UIAlertAction *a) {
        [[SSStoryStore shared] deleteStoryWithID:story.storyID];
        // FRC's controllerDidChangeContent: will refresh the list.
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];

    // iPad: anchor the action sheet to the pressed cell.
    UICollectionViewCell *cell = [self.collectionView cellForItemAtIndexPath:indexPath];
    sheet.popoverPresentationController.sourceView = cell ?: self.collectionView;
    sheet.popoverPresentationController.sourceRect = cell ? cell.bounds : CGRectMake(point.x, point.y, 1, 1);

    [self presentViewController:sheet animated:YES completion:nil];
}

#pragma mark - FRC

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller {
    if (self.currentTab == SSLibraryTabUser) {
        [self.collectionView reloadData];
        [self updateEmptyState];
    }
}

@end
