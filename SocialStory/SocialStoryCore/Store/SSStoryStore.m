//
//  SSStoryStore.m
//  SocialStoryCore
//

#import "SSStoryStore.h"
#import "SSStory.h"

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
    [self.container loadPersistentStoresWithCompletionHandler:^(NSPersistentStoreDescription *desc, NSError *error) {
        if (error) {
            NSLog(@"[SSStoryStore] failed to load store: %@", error);
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
    NSManagedObjectContext *ctx = self.viewContext;
    NSManagedObject *obj = [self managedObjectForID:story.storyID inContext:ctx];
    if (!obj) {
        obj = [NSEntityDescription insertNewObjectForEntityForName:kEntityName inManagedObjectContext:ctx];
        [obj setValue:story.storyID forKey:@"storyID"];
    }
    [obj setValue:story.title forKey:@"title"];
    [obj setValue:story.content forKey:@"content"];
    [obj setValue:story.imageURL forKey:@"imageURL"];
    [obj setValue:story.createdAt forKey:@"createdAt"];
    [obj setValue:story.lastReadAt forKey:@"lastReadAt"];
    [obj setValue:@(story.wordCount) forKey:@"wordCount"];
    [self save];
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
    story.content = [object valueForKey:@"content"];
    story.imageURL = [object valueForKey:@"imageURL"];
    story.createdAt = [object valueForKey:@"createdAt"];
    story.lastReadAt = [object valueForKey:@"lastReadAt"];
    story.wordCount = [[object valueForKey:@"wordCount"] integerValue];
    return story;
}

- (SSStory *)storyWithID:(NSString *)storyID {
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
