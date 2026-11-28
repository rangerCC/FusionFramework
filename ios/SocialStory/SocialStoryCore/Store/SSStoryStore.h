//
//  SSStoryStore.h
//  SocialStoryCore
//
//  Facade over local story storage (FMDB, see SSStoryDB). User-created stories
//  live in the user table; server-synced featured stories live in the featured
//  table. Demo stories are seeded into the featured table on first launch.
//

#import <Foundation/Foundation.h>

@class SSStory;

NS_ASSUME_NONNULL_BEGIN

/// Posted when user stories change (save / delete / clear). UI re-queries.
extern NSString *const SSUserStoriesDidChangeNotification;

@interface SSStoryStore : NSObject

+ (instancetype)shared;

#pragma mark - User stories

/// Insert or update a user-created story, then notify observers.
- (void)saveStory:(SSStory *)story;

/// Delete a user story by id, then notify observers.
- (void)deleteStoryWithID:(NSString *)storyID;

/// Update lastReadAt for a user story.
- (void)markStoryReadWithID:(NSString *)storyID;

/// Remove every user story, then notify observers.
- (void)deleteAllStories;

/// All user-created stories, newest first.
- (NSArray<SSStory *> *)allUserStories;

#pragma mark - Featured stories

/// All featured (精选) stories from the local table.
- (NSArray<SSStory *> *)allFeaturedStories;

#pragma mark - Lookup

/// Fetch a single story by id (featured or user), nil if missing.
- (nullable SSStory *)storyWithID:(NSString *)storyID;

@end

NS_ASSUME_NONNULL_END
