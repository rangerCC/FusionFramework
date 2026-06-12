//
//  SSStoryDB.h
//  SocialStoryCore
//
//  FMDB-backed local storage for stories. Two tables:
//   - featured_story: server-synced 精选故事 (replaced wholesale on sync; seeded
//     with bundled demos on first launch).
//   - user_story: user-generated stories (created / deleted / listed locally).
//
//  Each row stores the full coze JSON (raw_json, lossless) plus extracted
//  columns (title / image_url / word_count) for listing.
//

#import <Foundation/Foundation.h>

@class SSStory;

NS_ASSUME_NONNULL_BEGIN

@interface SSStoryDB : NSObject

+ (instancetype)shared;

#pragma mark - Featured (精选, server-synced)

/// All featured stories, in stored order.
- (NSArray<SSStory *> *)allFeaturedStories;

/// Replace the entire featured table with the given stories (used after a
/// successful server sync). Runs in one transaction.
- (void)replaceFeaturedStories:(NSArray<SSStory *> *)stories;

/// Seed the featured table from bundled demos only if it's currently empty
/// (first install, offline-friendly). No-op once any featured row exists.
- (void)seedFeaturedIfEmpty:(NSArray<SSStory *> *)demoStories;

/// Cached list ETag from the last successful server sync (nil if never synced).
@property (nonatomic, copy, nullable) NSString *featuredETag;

#pragma mark - User stories (local)

/// All user-created stories, newest first.
- (NSArray<SSStory *> *)allUserStories;

/// Insert or update a user story.
- (void)upsertUserStory:(SSStory *)story;

/// Delete a user story by id.
- (void)deleteUserStoryWithID:(NSString *)storyID;

/// Remove all user stories.
- (void)deleteAllUserStories;

/// Update lastReadAt for a user story.
- (void)markUserStoryRead:(NSString *)storyID;

#pragma mark - Lookup (either table)

/// Look up a story by id, searching featured first, then user stories.
- (nullable SSStory *)storyWithID:(NSString *)storyID;

@end

NS_ASSUME_NONNULL_END
