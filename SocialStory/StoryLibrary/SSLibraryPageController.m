//
//  SSLibraryPageController.m
//  StoryLibrary
//

#import "SSLibraryPageController.h"
#import <CoreData/CoreData.h>
#import <FusionUI/FusionPageNavigator+Auto.h>
#import <FusionUI/FusionNaviAnimeHelper.h>

static const NSInteger kSectionDemo = 0;
static const NSInteger kSectionUser = 1;

@interface SSLibraryPageController () <UITableViewDataSource, UITableViewDelegate, NSFetchedResultsControllerDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSFetchedResultsController *frc;
@property (nonatomic, strong) NSArray<SSStory *> *demoStories;
@property (nonatomic, strong) NSDateFormatter *dateFormatter;
@end

@implementation SSLibraryPageController

- (NSString *)pageTitle { return @"我的故事"; }

- (void)viewDidLoad {
    [super viewDidLoad];

    self.dateFormatter = [NSDateFormatter new];
    self.dateFormatter.dateFormat = @"yyyy-MM-dd HH:mm";
    self.demoStories = [SSDemoStories allStories];

    self.frc = [[SSStoryStore shared] fetchedResultsControllerWithDelegate:self];
    [self.frc performFetch:NULL];
}

- (void)buildPageContent {
    CGFloat top = [self naviBarBottom];
    CGFloat bottom = [self contentBottomInset];
    self.tableView = [[UITableView alloc] initWithFrame:
        CGRectMake(0, top, self.view.bounds.size.width, self.view.bounds.size.height - top - bottom)
                                                   style:UITableViewStyleGrouped];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.rowHeight = 72;
    self.tableView.backgroundColor = [SSTheme backgroundColor];
    [self.view addSubview:self.tableView];

    UIRefreshControl *refresh = [UIRefreshControl new];
    [refresh addTarget:self action:@selector(onRefresh:) forControlEvents:UIControlEventValueChanged];
    self.tableView.refreshControl = refresh;

    [self.tableView reloadData];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.frc performFetch:NULL];
    [self.tableView reloadData];
}

- (void)onRefresh:(UIRefreshControl *)refresh {
    [self.frc performFetch:NULL];
    [self.tableView reloadData];
    [refresh endRefreshing];
}

#pragma mark - Helpers

- (NSInteger)userCount { return self.frc.fetchedObjects.count; }

- (SSStory *)storyAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == kSectionDemo) {
        return self.demoStories[indexPath.row];
    }
    NSManagedObject *obj = [self.frc objectAtIndexPath:[NSIndexPath indexPathForRow:indexPath.row inSection:0]];
    return [[SSStoryStore shared] storyFromManagedObject:obj];
}

#pragma mark - Table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 2; }

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return (section == kSectionDemo) ? self.demoStories.count : [self userCount];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == kSectionDemo) { return @"精选故事"; }
    return ([self userCount] > 0) ? @"我创建的故事" : @"我创建的故事（还没有，去「生成」创建吧）";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cid = @"StoryCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cid];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cid];
        cell.textLabel.textColor = [SSTheme primaryTextColor];
        cell.detailTextLabel.textColor = [SSTheme secondaryTextColor];
    }
    SSStory *story = [self storyAtIndexPath:indexPath];
    cell.textLabel.text = story.title;
    if (indexPath.section == kSectionDemo) {
        cell.detailTextLabel.text = [NSString stringWithFormat:@"内置 · %ld 页", (long)story.pages.count];
    } else {
        NSString *dateStr = story.createdAt ? [self.dateFormatter stringFromDate:story.createdAt] : @"";
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ · %ld 字", dateStr, (long)story.wordCount];
    }
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    SSStory *story = [self storyAtIndexPath:indexPath];
    FusionPageMessage *m = [[FusionPageMessage alloc] initWithPageName:SSPageReader
                                                              pageNick:nil
                                                               command:nil
                                                                  args:@{SSArgStoryID: story.storyID}
                                                              callback:nil];
    [m setNaviAnimeType:SlideR2L_NaviAnime];
    [[self getNavigator] gotoPage:m];
}

// Only user stories can be deleted; demo stories are read-only.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return indexPath.section == kSectionUser;
}

- (void)tableView:(UITableView *)tableView
    commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
     forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete && indexPath.section == kSectionUser) {
        SSStory *story = [self storyAtIndexPath:indexPath];
        [[SSStoryStore shared] deleteStoryWithID:story.storyID];
    }
}

#pragma mark - FRC

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller {
    [self.tableView reloadData];
}

@end
