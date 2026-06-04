//
//  SSStoryAPIClient.m
//  SocialStoryCore
//

#import "SSStoryAPIClient.h"
#import "SSStory.h"
#import "SSConfig.h"

@implementation SSStoryGenerationRequest
@end

@implementation SSStoryAPIClient

// A generated story is owned locally and persisted to Core Data. The backend's
// story_id shares the demo data format/namespace ("demo-N"), and SSStoryStore
// routes any "demo-" id to the read-only JSON bundle instead of Core Data — so
// trusting it would misroute the reader's lookup and (if repeated) overwrite
// prior stories on save. Stamp a guaranteed-unique, non-demo id instead.
- (void)stampLocalStoryID:(SSStory *)story {
    story.storyID = [@"user-" stringByAppendingString:[[NSUUID UUID] UUIDString]];
}

+ (instancetype)shared {
    static SSStoryAPIClient *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [SSStoryAPIClient new]; });
    return instance;
}

- (void)generateStoryWithRequest:(SSStoryGenerationRequest *)request
                      completion:(void (^)(SSStory *, NSError *))completion {
    if ([SSConfig shared].useMock || [SSConfig shared].workerURLString.length == 0) {
        [self generateMockForRequest:request completion:completion];
    } else {
        [self generateRemoteForRequest:request completion:completion];
    }
}

#pragma mark - Field mapping

- (NSString *)diagnosisString:(SSDiagnosisType)t {
    switch (t) {
        case SSDiagnosisASD: return @"asd";
        case SSDiagnosisADHD: return @"adhd";
        case SSDiagnosisSocialAnxiety: return @"social_anxiety";
        default: return @"other";
    }
}

- (NSString *)levelString:(SSLanguageLevel)l {
    switch (l) {
        case SSLanguageLevelSimple: return @"simple";
        case SSLanguageLevelModerate: return @"moderate";
        default: return @"advanced";
    }
}

- (NSString *)toneString:(SSToneStyle)t {
    switch (t) {
        case SSToneGentle: return @"gentle";
        case SSToneCheerful: return @"cheerful";
        default: return @"calm";
    }
}

- (NSString *)genderString:(SSGender)g {
    return g == SSGenderBoy ? @"boy" : @"girl";
}

- (NSDictionary *)payloadForRequest:(SSStoryGenerationRequest *)r {
    NSString *interest = r.preferredInterest.length ? r.preferredInterest : @"";
    // The backend validates preferred_interest / tone_style as plain strings
    // (despite the API doc labeling them "object").
    return @{
        @"child_name": r.childName ?: @"",
        @"child_age": @(r.childAge),
        @"diagnosis_type": [self diagnosisString:r.diagnosisType],
        @"social_scenario": r.socialScenario ?: @"",
        @"difficulty_detail": r.difficultyDetail ?: @"",
        @"preferred_interest": interest,
        @"language_level": [self levelString:r.level],
        @"tone_style": [self toneString:r.tone],
        @"gender": [self genderString:r.gender]
    };
}

#pragma mark - Remote

- (void)generateRemoteForRequest:(SSStoryGenerationRequest *)request
                      completion:(void (^)(SSStory *, NSError *))completion {
    NSDictionary *payload = [self payloadForRequest:request];
    NSData *bodyData = [NSJSONSerialization dataWithJSONObject:payload options:0 error:NULL];

    NSURL *url = [NSURL URLWithString:[SSConfig shared].workerURLString];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    req.HTTPMethod = @"POST";
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    NSString *token = [SSConfig shared].authToken;
    if (token.length) {
        [req setValue:[NSString stringWithFormat:@"Bearer %@", token] forHTTPHeaderField:@"Authorization"];
    }
    req.HTTPBody = bodyData;
    req.timeoutInterval = 240;  // generation can take a while

    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:req
        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) { if (completion) completion(nil, error); return; }
            NSError *parseError = nil;
            SSStory *story = [self parseStoryFromData:data error:&parseError];
            if (story) {
                [self stampLocalStoryID:story];
                if (completion) completion(story, nil);
            } else {
                NSError *e = parseError ?: [NSError errorWithDomain:@"SSStoryAPIClient" code:-1
                                                           userInfo:@{NSLocalizedDescriptionKey: @"无法解析故事内容"}];
                if (completion) completion(nil, e);
            }
        });
    }];
    [task resume];
}

- (SSStory *)parseStoryFromData:(NSData *)data error:(NSError **)error {
    if (!data) { return nil; }
    id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:error];
    if (![json isKindOfClass:[NSDictionary class]]) { return nil; }
    // The story payload may be nested (e.g. under "data" / "output"); unwrap if needed.
    NSDictionary *dict = json;
    if (!dict[@"pages"]) {
        for (NSString *key in @[@"data", @"output", @"result"]) {
            id inner = dict[key];
            if ([inner isKindOfClass:[NSDictionary class]] && ((NSDictionary *)inner)[@"pages"]) {
                dict = inner; break;
            }
            if ([inner isKindOfClass:[NSString class]]) {
                id parsed = [NSJSONSerialization JSONObjectWithData:[inner dataUsingEncoding:NSUTF8StringEncoding] options:0 error:NULL];
                if ([parsed isKindOfClass:[NSDictionary class]] && parsed[@"pages"]) { dict = parsed; break; }
            }
        }
    }
    return [SSStory storyFromCozeResponse:dict];
}

#pragma mark - Mock (multi-page)

- (void)generateMockForRequest:(SSStoryGenerationRequest *)request
                    completion:(void (^)(SSStory *, NSError *))completion {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        NSString *name = request.childName.length ? request.childName : @"小朋友";
        NSString *scene = request.socialScenario.length ? request.socialScenario : @"今天的活动";
        NSArray *contents = @[
            [NSString stringWithFormat:@"%@要去体验「%@」，有点点紧张。", name, scene],
            @"我可以做几次深呼吸，让自己慢慢平静下来。",
            @"我会认真听大人的话，一步一步来。",
            @"完成以后，我会为自己感到骄傲，因为我做到了！"
        ];
        NSMutableArray *pages = [NSMutableArray array];
        for (NSUInteger i = 0; i < contents.count; i++) {
            [pages addObject:@{
                @"page_number": @(i + 1),
                @"page_title": [NSString stringWithFormat:@"第 %lu 页", (unsigned long)(i + 1)],
                @"content": contents[i],
                @"illustration_url": @"",
                @"audio_url": @"",
                @"page_duration_seconds": @6
            }];
        }
        NSDictionary *mock = @{
            @"story_title": [NSString stringWithFormat:@"%@的社交故事", scene],
            @"total_duration_seconds": @24,
            @"pages": pages,
            @"parent_guide": @{
                @"before_reading": @"阅读前先让孩子放松情绪。",
                @"during_reading": @"读的时候语气轻柔，允许孩子提问。",
                @"after_reading": @"读完一起模拟故事里的场景。",
                @"reinforcement_tips": @"孩子有尝试就及时肯定。"
            },
            @"comprehension_questions": @[
                @{@"question": @"故事里我遇到了什么？", @"expected_answer": scene},
                @{@"question": @"我可以怎么让自己平静？", @"expected_answer": @"做深呼吸"}
            ],
            @"voice_params": @{@"voice_name": @"温柔女声", @"speaking_rate": @0.75}
        };
        SSStory *story = [SSStory storyFromCozeResponse:mock];
        [self stampLocalStoryID:story];
        if (completion) completion(story, nil);
    });
}

@end
