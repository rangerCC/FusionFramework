//
//  SSDemoStories.h
//  SocialStoryCore
//
//  Built-in sample stories that are available without generating. They are not
//  persisted to Core Data and cannot be deleted.
//

#import <Foundation/Foundation.h>

@class SSStory;

NS_ASSUME_NONNULL_BEGIN

@interface SSDemoStories : NSObject

/// The built-in demo stories (stable IDs like "demo-1").
+ (NSArray<SSStory *> *)allStories;

/// Lookup a demo story by id; nil if not a demo id.
+ (nullable SSStory *)storyWithID:(NSString *)storyID;

/// Whether the id refers to a built-in demo story.
+ (BOOL)isDemoStoryID:(NSString *)storyID;

@end

NS_ASSUME_NONNULL_END
