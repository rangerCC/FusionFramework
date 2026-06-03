//
//  SSStory.m
//  SocialStoryCore
//

#import "SSStory.h"

@implementation SSStory

+ (instancetype)storyWithTitle:(NSString *)title
                       content:(NSString *)content
                      imageURL:(NSString *)imageURL
                     wordCount:(NSInteger)wordCount {
    SSStory *story = [SSStory new];
    story.storyID = [[NSUUID UUID] UUIDString];
    story.title = title ?: @"";
    story.content = content ?: @"";
    story.imageURL = imageURL;
    story.wordCount = wordCount;
    story.createdAt = [NSDate date];
    return story;
}

@end
