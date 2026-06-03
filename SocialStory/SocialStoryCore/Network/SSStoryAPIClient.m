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

#pragma mark - Mock

- (void)generateMockForRequest:(SSStoryGenerationRequest *)request
                    completion:(void (^)(SSStory *, NSError *))completion {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        NSString *name = request.childName.length ? request.childName : @"小朋友";
        NSString *scene = request.sceneText.length ? request.sceneText : @"今天的活动";
        NSString *title = [NSString stringWithFormat:@"%@的社交故事", scene];
        NSMutableString *body = [NSMutableString string];
        [body appendFormat:@"今天，%@要去体验「%@」。\n\n", name, scene];
        [body appendString:@"一开始可能会有一点点紧张，这是很正常的感觉。\n\n"];
        [body appendString:@"我可以做几次深呼吸，让自己慢慢平静下来。\n\n"];
        [body appendFormat:@"%@会认真听大人的话，按照步骤一步一步来。\n\n", name];
        if (request.level == SSLanguageLevelStandard) {
            [body appendString:@"当我遇到不明白的地方时，我可以礼貌地举手提问，或者请身边的大人帮忙。这样做是勇敢又聪明的表现。\n\n"];
        }
        [body appendString:@"完成以后，我会为自己感到骄傲，因为我做到了！"];

        NSInteger count = (NSInteger)[body length];
        SSStory *story = [SSStory storyWithTitle:title
                                         content:body
                                        imageURL:nil
                                       wordCount:count];
        if (completion) completion(story, nil);
    });
}

#pragma mark - Remote (via CoreService NetNormalActor)

- (void)generateRemoteForRequest:(SSStoryGenerationRequest *)request
                      completion:(void (^)(SSStory *, NSError *))completion {
    NSDictionary *payload = @{
        @"scene": request.sceneText ?: @"",
        @"child_name": request.childName ?: @"",
        @"age": @(request.childAge),
        @"level": (request.level == SSLanguageLevelSimple ? @"simple" : @"standard")
    };
    NSData *bodyData = [NSJSONSerialization dataWithJSONObject:payload options:0 error:NULL];

    NSURL *url = [NSURL URLWithString:[SSConfig shared].workerURLString];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    req.HTTPMethod = @"POST";
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    req.HTTPBody = bodyData;
    req.timeoutInterval = 60;

    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:req
        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) { if (completion) completion(nil, error); return; }
            NSError *parseError = nil;
            SSStory *story = [self parseStoryFromData:data error:&parseError];
            if (completion) completion(story, story ? nil : parseError);
        });
    }];
    [task resume];
}

- (SSStory *)parseStoryFromData:(NSData *)data error:(NSError **)error {
    if (!data) return nil;
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:error];
    if (![json isKindOfClass:[NSDictionary class]]) return nil;
    NSString *title = json[@"title"] ?: @"未命名故事";
    NSString *content = json[@"content"] ?: @"";
    NSString *imageURL = [json[@"image_url"] isKindOfClass:[NSString class]] ? json[@"image_url"] : nil;
    NSInteger wordCount = [json[@"word_count"] respondsToSelector:@selector(integerValue)]
        ? [json[@"word_count"] integerValue] : (NSInteger)content.length;
    return [SSStory storyWithTitle:title content:content imageURL:imageURL wordCount:wordCount];
}

@end
