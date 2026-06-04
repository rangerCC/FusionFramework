//
//  SSStory.m
//  SocialStoryCore
//

#import "SSStory.h"

@implementation SSStoryPage
@end

@implementation SSComprehensionQA
@end

static NSString *SSStr(id v) {
    return [v isKindOfClass:[NSString class]] ? v : nil;
}

@implementation SSStory

+ (instancetype)storyFromCozeResponse:(NSDictionary *)json {
    if (![json isKindOfClass:[NSDictionary class]]) { return nil; }

    SSStory *story = [SSStory new];
    story.storyID = SSStr(json[@"story_id"]) ?: [[NSUUID UUID] UUIDString];
    story.title = SSStr(json[@"story_title"]) ?: @"未命名故事";
    story.createdAt = [NSDate date];
    story.totalDurationSeconds = [json[@"total_duration_seconds"] integerValue];

    // Pages
    NSMutableArray<SSStoryPage *> *pages = [NSMutableArray array];
    NSInteger wordCount = 0;
    NSArray *rawPages = [json[@"pages"] isKindOfClass:[NSArray class]] ? json[@"pages"] : @[];
    for (NSDictionary *p in rawPages) {
        if (![p isKindOfClass:[NSDictionary class]]) { continue; }
        SSStoryPage *page = [SSStoryPage new];
        page.pageNumber = [p[@"page_number"] integerValue];
        page.pageTitle = SSStr(p[@"page_title"]);
        page.content = SSStr(p[@"content"]) ?: @"";
        page.illustrationURL = SSStr(p[@"illustration_url"]);
        page.audioURL = SSStr(p[@"audio_url"]);
        page.durationSeconds = [p[@"page_duration_seconds"] integerValue];
        wordCount += page.content.length;
        [pages addObject:page];
    }
    // Sort by pageNumber to be safe.
    [pages sortUsingComparator:^NSComparisonResult(SSStoryPage *a, SSStoryPage *b) {
        return a.pageNumber == b.pageNumber ? NSOrderedSame : (a.pageNumber < b.pageNumber ? NSOrderedAscending : NSOrderedDescending);
    }];
    story.pages = pages;
    story.wordCount = wordCount;
    story.imageURL = pages.firstObject.illustrationURL;

    // Parent guide
    NSDictionary *guide = [json[@"parent_guide"] isKindOfClass:[NSDictionary class]] ? json[@"parent_guide"] : nil;
    story.guideBeforeReading = SSStr(guide[@"before_reading"]);
    story.guideDuringReading = SSStr(guide[@"during_reading"]);
    story.guideAfterReading = SSStr(guide[@"after_reading"]);
    story.guideReinforcement = SSStr(guide[@"reinforcement_tips"]);

    // Comprehension questions
    NSMutableArray<SSComprehensionQA *> *qs = [NSMutableArray array];
    NSArray *rawQs = [json[@"comprehension_questions"] isKindOfClass:[NSArray class]] ? json[@"comprehension_questions"] : @[];
    for (NSDictionary *q in rawQs) {
        if (![q isKindOfClass:[NSDictionary class]]) { continue; }
        SSComprehensionQA *qa = [SSComprehensionQA new];
        qa.question = SSStr(q[@"question"]);
        qa.expectedAnswer = SSStr(q[@"expected_answer"]);
        [qs addObject:qa];
    }
    story.questions = qs;

    // voice params
    NSDictionary *voice = [json[@"voice_params"] isKindOfClass:[NSDictionary class]] ? json[@"voice_params"] : nil;
    story.voiceName = SSStr(voice[@"voice_name"]);
    CGFloat rate = [voice[@"speaking_rate"] respondsToSelector:@selector(doubleValue)] ? [voice[@"speaking_rate"] doubleValue] : 0.0;
    story.speakingRate = (rate > 0.0) ? rate : 0.75;

    return story;
}

@end
