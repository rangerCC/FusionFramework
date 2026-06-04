//
//  SSStoryStore.m
//  SocialStoryCore
//

#import "SSStoryStore.h"
#import "SSStory.h"
#import "SSDemoStories.h"

// Flip to YES and swap NSPersistentContainer -> NSPersistentCloudKitContainer
// below to enable iCloud sync (requires iCloud entitlement + container id).
static const BOOL kSSUseCloudKit = NO;

static NSString *const kEntityName = @"CDStory";

@interface SSStoryStore ()
@property (nonatomic, strong) NSPersistentContainer *container;
@end

@implementation SSStoryStore

+ (instancetype)shared {
    static SSStoryStore *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [SSStoryStore new]; });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self setupContainer];
    }
    return self;
}

- (void)setupContainer {
    NSManagedObjectModel *model = [self loadModel];
    if (kSSUseCloudKit) {
        // CloudKit switch point:
        // self.container = [[NSPersistentCloudKitContainer alloc] initWithName:@"SocialStory" managedObjectModel:model];
    }
    if (!self.container) {
        self.container = [[NSPersistentContainer alloc] initWithName:@"SocialStory"
                                                  managedObjectModel:model];
    }
    NSPersistentStoreDescription *desc = self.container.persistentStoreDescriptions.firstObject;
    [self.container loadPersistentStoresWithCompletionHandler:^(NSPersistentStoreDescription *d, NSError *error) {
        if (error) {
            NSLog(@"[SSStoryStore] failed to load store: %@ — resetting", error);
            // Model changed during development: drop the incompatible store and retry.
            NSURL *storeURL = desc.URL;
            if (storeURL) {
                [[NSFileManager defaultManager] removeItemAtURL:storeURL error:NULL];
                [[NSFileManager defaultManager] removeItemAtURL:[storeURL URLByAppendingPathExtension:@"shm"] error:NULL];
                [[NSFileManager defaultManager] removeItemAtURL:[storeURL URLByAppendingPathExtension:@"wal"] error:NULL];
            }
            [self.container loadPersistentStoresWithCompletionHandler:^(NSPersistentStoreDescription *d2, NSError *error2) {
                if (error2) { NSLog(@"[SSStoryStore] reset still failed: %@", error2); }
            }];
        }
    }];
    self.container.viewContext.automaticallyMergesChangesFromParent = YES;
}

- (NSManagedObjectModel *)loadModel {
    // The compiled model (.momd) lives in the pod's resource bundle.
    NSBundle *classBundle = [NSBundle bundleForClass:[self class]];
    NSURL *bundleURL = [classBundle URLForResource:@"SocialStoryCoreResources" withExtension:@"bundle"];
    NSBundle *resBundle = bundleURL ? [NSBundle bundleWithURL:bundleURL] : classBundle;

    NSURL *momURL = [resBundle URLForResource:@"SocialStory" withExtension:@"momd"];
    if (!momURL) {
        momURL = [resBundle URLForResource:@"SocialStory" withExtension:@"mom"];
    }
    NSManagedObjectModel *model = momURL ? [[NSManagedObjectModel alloc] initWithContentsOfURL:momURL] : nil;
    if (!model) {
        // Fallback: merge from the bundle so we still get a usable model.
        model = [NSManagedObjectModel mergedModelFromBundles:@[resBundle]];
    }
    return model;
}

- (NSManagedObjectContext *)viewContext { return self.container.viewContext; }

#pragma mark - CRUD

- (NSManagedObject *)managedObjectForID:(NSString *)storyID inContext:(NSManagedObjectContext *)ctx {
    NSFetchRequest *req = [NSFetchRequest fetchRequestWithEntityName:kEntityName];
    req.predicate = [NSPredicate predicateWithFormat:@"storyID == %@", storyID];
    req.fetchLimit = 1;
    return [[ctx executeFetchRequest:req error:NULL] firstObject];
}

- (void)saveStory:(SSStory *)story {
    if (story.storyID.length == 0) {
        NSLog(@"[SSStoryStore] refusing to save story with empty id");
        return;
    }
    if ([SSDemoStories isDemoStoryID:story.storyID]) {
        // Demo ids are served read-only from the bundle; storyWithID: would route
        // reads here away from Core Data. A generated story landing in this
        // namespace is a bug upstream (see SSStoryAPIClient -stampLocalStoryID:).
        NSLog(@"[SSStoryStore] refusing to persist a story in the demo id namespace: %@", story.storyID);
        return;
    }
    NSManagedObjectContext *ctx = self.viewContext;
    NSManagedObject *obj = [self managedObjectForID:story.storyID inContext:ctx];
    if (!obj) {
        obj = [NSEntityDescription insertNewObjectForEntityForName:kEntityName inManagedObjectContext:ctx];
        [obj setValue:story.storyID forKey:@"storyID"];
    }
    [obj setValue:story.title forKey:@"title"];
    [obj setValue:story.imageURL forKey:@"imageURL"];
    [obj setValue:story.createdAt forKey:@"createdAt"];
    [obj setValue:story.lastReadAt forKey:@"lastReadAt"];
    [obj setValue:@(story.wordCount) forKey:@"wordCount"];
    [obj setValue:@(story.totalDurationSeconds) forKey:@"totalDuration"];
    [obj setValue:story.guideBeforeReading forKey:@"guideBefore"];
    [obj setValue:story.guideDuringReading forKey:@"guideDuring"];
    [obj setValue:story.guideAfterReading forKey:@"guideAfter"];
    [obj setValue:story.guideReinforcement forKey:@"guideReinforcement"];
    [obj setValue:@(story.speakingRate) forKey:@"speakingRate"];
    [obj setValue:story.voiceName forKey:@"voiceName"];
    [obj setValue:[self questionsJSON:story.questions] forKey:@"questionsJSON"];

    // Replace pages.
    NSSet *existing = [obj valueForKey:@"pages"];
    for (NSManagedObject *old in [existing allObjects]) {
        [ctx deleteObject:old];
    }
    NSMutableSet *newPages = [NSMutableSet set];
    for (SSStoryPage *page in story.pages) {
        NSManagedObject *cdPage = [NSEntityDescription insertNewObjectForEntityForName:@"CDPage" inManagedObjectContext:ctx];
        [cdPage setValue:@(page.pageNumber) forKey:@"pageNumber"];
        [cdPage setValue:page.pageTitle forKey:@"pageTitle"];
        [cdPage setValue:page.content forKey:@"content"];
        [cdPage setValue:page.illustrationURL forKey:@"illustrationURL"];
        [cdPage setValue:page.audioURL forKey:@"audioURL"];
        [cdPage setValue:@(page.durationSeconds) forKey:@"duration"];
        [cdPage setValue:obj forKey:@"story"];
        [newPages addObject:cdPage];
    }
    [obj setValue:newPages forKey:@"pages"];
    [self save];
}

- (NSString *)questionsJSON:(NSArray<SSComprehensionQA *> *)questions {
    NSMutableArray *arr = [NSMutableArray array];
    for (SSComprehensionQA *qa in questions) {
        [arr addObject:@{@"q": qa.question ?: @"", @"a": qa.expectedAnswer ?: @""}];
    }
    NSData *data = [NSJSONSerialization dataWithJSONObject:arr options:0 error:NULL];
    return data ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : nil;
}

- (NSArray<SSComprehensionQA *> *)questionsFromJSON:(NSString *)json {
    if (json.length == 0) { return @[]; }
    NSData *data = [json dataUsingEncoding:NSUTF8StringEncoding];
    NSArray *arr = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
    if (![arr isKindOfClass:[NSArray class]]) { return @[]; }
    NSMutableArray<SSComprehensionQA *> *result = [NSMutableArray array];
    for (NSDictionary *d in arr) {
        if (![d isKindOfClass:[NSDictionary class]]) { continue; }
        SSComprehensionQA *qa = [SSComprehensionQA new];
        qa.question = d[@"q"];
        qa.expectedAnswer = d[@"a"];
        [result addObject:qa];
    }
    return result;
}

- (void)deleteStoryWithID:(NSString *)storyID {
    NSManagedObjectContext *ctx = self.viewContext;
    NSManagedObject *obj = [self managedObjectForID:storyID inContext:ctx];
    if (obj) {
        [ctx deleteObject:obj];
        [self save];
    }
}

- (void)markStoryReadWithID:(NSString *)storyID {
    NSManagedObject *obj = [self managedObjectForID:storyID inContext:self.viewContext];
    if (obj) {
        [obj setValue:[NSDate date] forKey:@"lastReadAt"];
        [self save];
    }
}

- (void)deleteAllStories {
    NSManagedObjectContext *ctx = self.viewContext;
    NSFetchRequest *req = [NSFetchRequest fetchRequestWithEntityName:kEntityName];
    NSArray *all = [ctx executeFetchRequest:req error:NULL];
    for (NSManagedObject *obj in all) {
        [ctx deleteObject:obj];
    }
    [self save];
}

- (void)save {
    NSError *error = nil;
    if ([self.viewContext hasChanges] && ![self.viewContext save:&error]) {
        NSLog(@"[SSStoryStore] save error: %@", error);
    }
}

#pragma mark - Read

- (SSStory *)storyFromManagedObject:(NSManagedObject *)object {
    SSStory *story = [SSStory new];
    story.storyID = [object valueForKey:@"storyID"];
    story.title = [object valueForKey:@"title"];
    story.imageURL = [object valueForKey:@"imageURL"];
    story.createdAt = [object valueForKey:@"createdAt"];
    story.lastReadAt = [object valueForKey:@"lastReadAt"];
    story.wordCount = [[object valueForKey:@"wordCount"] integerValue];
    story.totalDurationSeconds = [[object valueForKey:@"totalDuration"] integerValue];
    story.guideBeforeReading = [object valueForKey:@"guideBefore"];
    story.guideDuringReading = [object valueForKey:@"guideDuring"];
    story.guideAfterReading = [object valueForKey:@"guideAfter"];
    story.guideReinforcement = [object valueForKey:@"guideReinforcement"];
    story.speakingRate = [[object valueForKey:@"speakingRate"] doubleValue];
    story.voiceName = [object valueForKey:@"voiceName"];
    story.questions = [self questionsFromJSON:[object valueForKey:@"questionsJSON"]];

    NSMutableArray<SSStoryPage *> *pages = [NSMutableArray array];
    for (NSManagedObject *cdPage in [object valueForKey:@"pages"]) {
        SSStoryPage *page = [SSStoryPage new];
        page.pageNumber = [[cdPage valueForKey:@"pageNumber"] integerValue];
        page.pageTitle = [cdPage valueForKey:@"pageTitle"];
        page.content = [cdPage valueForKey:@"content"];
        page.illustrationURL = [cdPage valueForKey:@"illustrationURL"];
        page.audioURL = [cdPage valueForKey:@"audioURL"];
        page.durationSeconds = [[cdPage valueForKey:@"duration"] integerValue];
        [pages addObject:page];
    }
    [pages sortUsingComparator:^NSComparisonResult(SSStoryPage *a, SSStoryPage *b) {
        return a.pageNumber == b.pageNumber ? NSOrderedSame : (a.pageNumber < b.pageNumber ? NSOrderedAscending : NSOrderedDescending);
    }];
    story.pages = pages;
    return story;
}

- (SSStory *)storyWithID:(NSString *)storyID {
    // Built-in demo stories live outside Core Data.
    if ([SSDemoStories isDemoStoryID:storyID]) {
        return [SSDemoStories storyWithID:storyID];
    }
    NSManagedObject *obj = [self managedObjectForID:storyID inContext:self.viewContext];
    return obj ? [self storyFromManagedObject:obj] : nil;
}

- (NSFetchedResultsController *)fetchedResultsControllerWithDelegate:(id<NSFetchedResultsControllerDelegate>)delegate {
    NSFetchRequest *req = [NSFetchRequest fetchRequestWithEntityName:kEntityName];
    req.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"createdAt" ascending:NO]];
    NSFetchedResultsController *frc =
        [[NSFetchedResultsController alloc] initWithFetchRequest:req
                                            managedObjectContext:self.viewContext
                                              sectionNameKeyPath:nil
                                                       cacheName:nil];
    frc.delegate = delegate;
    return frc;
}

@end
