//
//  SSStoryStore.h
//  SocialStoryCore
//
//  Core Data persistence for stories. Currently backed by a local
//  NSPersistentContainer; see `useCloudKit` for the CloudKit switch point.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class SSStory;

NS_ASSUME_NONNULL_BEGIN

@interface SSStoryStore : NSObject

+ (instancetype)shared;

@property (nonatomic, readonly) NSManagedObjectContext *viewContext;

/// Insert or update a story, then save.
- (void)saveStory:(SSStory *)story;

/// Delete by storyID, then save (and, when enabled, sync the delete to iCloud).
- (void)deleteStoryWithID:(NSString *)storyID;

/// Update lastReadAt for a story.
- (void)markStoryReadWithID:(NSString *)storyID;

/// Remove every stored story.
- (void)deleteAllStories;

/// Convert a managed object into a plain model.
- (SSStory *)storyFromManagedObject:(NSManagedObject *)object;

/// Fetch a single story model by id (nil if missing).
- (nullable SSStory *)storyWithID:(NSString *)storyID;

/// FetchedResultsController over CDStory sorted by createdAt desc.
- (NSFetchedResultsController *)fetchedResultsControllerWithDelegate:(id<NSFetchedResultsControllerDelegate>)delegate;

@end

NS_ASSUME_NONNULL_END
