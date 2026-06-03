//
//  SSTemplatePageController.m
//  StoryTemplates
//

#import "SSTemplatePageController.h"
#import <FusionUI/FusionPageNavigator+Auto.h>
#import <FusionUI/FusionNaviAnimeHelper.h>
#import <FusionUI/FusionNaviAnime.h>

@interface SSTemplateItem : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *scene;
@end
@implementation SSTemplateItem
@end

@interface SSTemplatePageController () <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, copy) NSArray<SSTemplateItem *> *items;
@end

@implementation SSTemplatePageController

- (NSString *)pageTitle { return @"选择模板"; }
- (BOOL)showsBackButton { return YES; }

- (void)viewDidLoad {
    [super viewDidLoad];
    [self loadTemplates];
}

- (void)buildPageContent {
    CGFloat top = [self naviBarBottom];
    self.tableView = [[UITableView alloc] initWithFrame:
        CGRectMake(0, top, self.view.bounds.size.width, self.view.bounds.size.height - top)
                                                  style:UITableViewStylePlain];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.rowHeight = 64;
    self.tableView.backgroundColor = [SSTheme backgroundColor];
    [self.view addSubview:self.tableView];
    [self.tableView reloadData];
}

- (void)loadTemplates {
    NSBundle *classBundle = [NSBundle bundleForClass:[self class]];
    NSURL *bundleURL = [classBundle URLForResource:@"StoryTemplatesResources" withExtension:@"bundle"];
    NSBundle *resBundle = bundleURL ? [NSBundle bundleWithURL:bundleURL] : classBundle;
    NSString *path = [resBundle pathForResource:@"Templates" ofType:@"plist"];
    NSArray *raw = path ? [NSArray arrayWithContentsOfFile:path] : nil;

    NSMutableArray *items = [NSMutableArray array];
    for (NSDictionary *dict in raw) {
        SSTemplateItem *item = [SSTemplateItem new];
        item.title = dict[@"title"];
        item.scene = dict[@"scene"];
        [items addObject:item];
    }
    self.items = items;
}

#pragma mark - Table

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.items.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cid = @"TplCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cid];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cid];
        cell.backgroundColor = [SSTheme cardColor];
        cell.textLabel.textColor = [SSTheme primaryTextColor];
        cell.detailTextLabel.textColor = [SSTheme secondaryTextColor];
        cell.detailTextLabel.numberOfLines = 2;
    }
    SSTemplateItem *item = self.items[indexPath.row];
    cell.textLabel.text = item.title;
    cell.detailTextLabel.text = item.scene;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    SSTemplateItem *item = self.items[indexPath.row];

    NSURL *callback = [self getCallbackUrl];
    if (callback) {
        // Pop back to the generate page, delivering the chosen scene text.
        FusionPageMessage *message = [[FusionPageMessage alloc] initWithURL:callback
                                                                       args:@{SSArgSceneText: item.scene}];
        [message setNaviAnimeType:SlideL2R_NaviAnime];
        [message setNaviAnimeDirection:FusionNaviAnimeBackward];
        [[self getNavigator] poptoPage:message];
    } else {
        [self goBack];
    }
}

@end
