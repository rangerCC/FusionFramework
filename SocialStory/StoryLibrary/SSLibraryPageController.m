//
//  SSLibraryPageController.m
//  StoryLibrary
//

#import "SSLibraryPageController.h"
#import <CoreData/CoreData.h>
#import <FusionUI/FusionPageNavigator+Auto.h>
#import <FusionUI/FusionNaviAnimeHelper.h>

@interface SSLibraryPageController () <UITableViewDataSource, UITableViewDelegate, NSFetchedResultsControllerDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSFetchedResultsController *frc;
@property (nonatomic, strong) UILabel *emptyLabel;
@property (nonatomic, strong) NSDateFormatter *dateFormatter;
@end

@implementation SSLibraryPageController

- (NSString *)pageTitle { return @"我的故事"; }

- (void)viewDidLoad {
    [super viewDidLoad];

    self.dateFormatter = [NSDateFormatter new];
    self.dateFormatter.dateFormat = @"yyyy-MM-dd HH:mm";

    self.frc = [[SSStoryStore shared] fetchedResultsControllerWithDelegate:self];
    [self.frc performFetch:NULL];
}

- (void)buildPageContent {
    CGFloat top = [self naviBarBottom];
    CGFloat bottom = [self contentBottomInset];
    self.tableView = [[UITableView alloc] initWithFrame:
        CGRectMake(0, top, self.view.bounds.size.width, self.view.bounds.size.height - top - bottom)
                                                   style:UITableViewStylePlain];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.rowHeight = 72;
    self.tableView.backgroundColor = [SSTheme backgroundColor];
    [self.view addSubview:self.tableView];

    UIRefreshControl *refresh = [UIRefreshControl new];
    [refresh addTarget:self action:@selector(onRefresh:) forControlEvents:UIControlEventValueChanged];
    self.tableView.refreshControl = refresh;

    self.emptyLabel = [[UILabel alloc] initWithFrame:self.tableView.bounds];
    self.emptyLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.emptyLabel.text = @"还没有故事\n点击「生成」创建第一个吧";
    self.emptyLabel.numberOfLines = 0;
    self.emptyLabel.textAlignment = NSTextAlignmentCenter;
    self.emptyLabel.textColor = [SSTheme secondaryTextColor];
    self.emptyLabel.font = [UIFont systemFontOfSize:16];

    [self.tableView reloadData];
    [self updateEmptyState];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.frc performFetch:NULL];
    [self.tableView reloadData];
    [self updateEmptyState];
}
- (void)onRefresh:(UIRefreshControl *)refresh {
    [self.frc performFetch:NULL];
    [self.tableView reloadData];
    [self updateEmptyState];
    [refresh endRefreshing];
}

- (void)updateEmptyState {
    NSInteger count = self.frc.fetchedObjects.count;
    self.tableView.backgroundView = (count == 0) ? self.emptyLabel : nil;
}

#pragma mark - Table

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.frc.fetchedObjects.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cid = @"StoryCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cid];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cid];
        cell.backgroundColor = [SSTheme cardColor];
        cell.textLabel.textColor = [SSTheme primaryTextColor];
        cell.detailTextLabel.textColor = [SSTheme secondaryTextColor];
    }
    NSManagedObject *obj = [self.frc objectAtIndexPath:indexPath];
    SSStory *story = [[SSStoryStore shared] storyFromManagedObject:obj];
    cell.textLabel.text = story.title;
    NSString *dateStr = story.createdAt ? [self.dateFormatter stringFromDate:story.createdAt] : @"";
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ · %ld 字", dateStr, (long)story.wordCount];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSManagedObject *obj = [self.frc objectAtIndexPath:indexPath];
    SSStory *story = [[SSStoryStore shared] storyFromManagedObject:obj];
    FusionPageMessage *m = [[FusionPageMessage alloc] initWithPageName:SSPageReader
                                                              pageNick:nil
                                                               command:nil
                                                                  args:@{SSArgStoryID: story.storyID}
                                                              callback:nil];
    [m setNaviAnimeType:SlideR2L_NaviAnime];
    [[self getNavigator] gotoPage:m];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath { return YES; }

- (void)tableView:(UITableView *)tableView
    commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
     forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        NSManagedObject *obj = [self.frc objectAtIndexPath:indexPath];
        SSStory *story = [[SSStoryStore shared] storyFromManagedObject:obj];
        [[SSStoryStore shared] deleteStoryWithID:story.storyID];
    }
}

#pragma mark - FRC

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller {
    [self.tableView reloadData];
    [self updateEmptyState];
}

@end
