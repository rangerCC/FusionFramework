//
//  SSStoryStore.m
//  SocialStoryCore
//

#import "SSStoryStore.h"
#import "SSStory.h"
#import "SSStoryDB.h"

NSString *const SSUserStoriesDidChangeNotification = @"SSUserStoriesDidChangeNotification";

@implementation SSStoryStore

+ (instancetype)shared {
    static SSStoryStore *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [SSStoryStore new]; });
    return instance;
}

- (void)postChange {
    [[NSNotificationCenter defaultCenter] postNotificationName:SSUserStoriesDidChangeNotification object:self];
}

#pragma mark - User stories

- (void)saveStory:(SSStory *)story {
    if (story.storyID.length == 0) { return; }
    [[SSStoryDB shared] upsertUserStory:story];
    [self postChange];
}

- (void)deleteStoryWithID:(NSString *)storyID {
    [[SSStoryDB shared] deleteUserStoryWithID:storyID];
    [self postChange];
}

- (void)markStoryReadWithID:(NSString *)storyID {
    [[SSStoryDB shared] markUserStoryRead:storyID];
}

- (void)deleteAllStories {
    [[SSStoryDB shared] deleteAllUserStories];
    [self postChange];
}

- (NSArray<SSStory *> *)allUserStories {
    return [[SSStoryDB shared] allUserStories];
}

#pragma mark - Featured

- (NSArray<SSStory *> *)allFeaturedStories {
    return [[SSStoryDB shared] allFeaturedStories];
}

#pragma mark - Lookup

- (SSStory *)storyWithID:(NSString *)storyID {
    return [[SSStoryDB shared] storyWithID:storyID];
}

@end
