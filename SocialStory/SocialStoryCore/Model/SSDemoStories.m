//
//  SSDemoStories.m
//  SocialStoryCore
//

#import "SSDemoStories.h"
#import "SSStory.h"

@implementation SSDemoStories

+ (NSArray<SSStory *> *)allStories {
    static NSArray<SSStory *> *cached = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSMutableArray *stories = [NSMutableArray array];
        for (NSString *name in @[@"demo1", @"demo2", @"demo3"]) {
            SSStory *story = [self loadStoryNamed:name];
            if (story) { [stories addObject:story]; }
        }
        cached = stories;
    });
    return cached;
}

+ (SSStory *)loadStoryNamed:(NSString *)name {
    NSBundle *classBundle = [NSBundle bundleForClass:[self class]];
    NSURL *bundleURL = [classBundle URLForResource:@"SocialStoryCoreResources" withExtension:@"bundle"];
    NSBundle *resBundle = bundleURL ? [NSBundle bundleWithURL:bundleURL] : classBundle;
    NSURL *jsonURL = [resBundle URLForResource:name withExtension:@"json"];
    if (!jsonURL) { jsonURL = [classBundle URLForResource:name withExtension:@"json"]; }
    if (!jsonURL) { return nil; }

    NSData *data = [NSData dataWithContentsOfURL:jsonURL];
    if (!data) { return nil; }
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
    if (![json isKindOfClass:[NSDictionary class]]) { return nil; }
    return [SSStory storyFromCozeResponse:json];
}

+ (SSStory *)storyWithID:(NSString *)storyID {
    for (SSStory *story in [self allStories]) {
        if ([story.storyID isEqualToString:storyID]) { return story; }
    }
    return nil;
}

+ (BOOL)isDemoStoryID:(NSString *)storyID {
    return [storyID hasPrefix:@"demo-"];
}

@end
