//
//  SSFeaturedStoryClient.m
//  SocialStoryCore
//

#import "SSFeaturedStoryClient.h"
#import "SSStory.h"
#import "SSStoryDB.h"
#import <AccountKit/AccountKit-Swift.h>

static NSString *const kDefaultBaseURL = @"http://localhost:8080";

@interface SSFeaturedStoryClient ()
@property (nonatomic, strong) NSURLSession *session;
@end

@implementation SSFeaturedStoryClient

+ (instancetype)shared {
    static SSFeaturedStoryClient *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [SSFeaturedStoryClient new]; });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        NSURLSessionConfiguration *cfg = [NSURLSessionConfiguration defaultSessionConfiguration];
        cfg.timeoutIntervalForRequest = 20;
        _session = [NSURLSession sessionWithConfiguration:cfg];
    }
    return self;
}

- (NSString *)baseURLString {
    NSString *fromConfig = [SSRemoteAccountService localConfigStringForKey:@"AccountBaseURL"];
    return fromConfig.length ? fromConfig : kDefaultBaseURL;
}

- (void)refreshWithCompletion:(void (^)(BOOL, NSError *))completion {
    void (^done)(BOOL, NSError *) = ^(BOOL changed, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(changed, error); });
    };

    NSString *urlStr = [[self baseURLString] stringByAppendingString:@"/v1/featured-stories"];
    NSURL *url = [NSURL URLWithString:urlStr];
    if (!url) { done(NO, [self errorWithMessage:@"无效的服务地址"]); return; }

    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    req.HTTPMethod = @"GET";
    NSString *etag = [SSStoryDB shared].featuredETag;
    if (etag.length) {
        [req setValue:etag forHTTPHeaderField:@"If-None-Match"];
    }

    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:req
        completionHandler:^(NSData *data, NSURLResponse *response, NSError *netErr) {
        if (netErr) { done(NO, netErr); return; }
        NSHTTPURLResponse *http = [response isKindOfClass:[NSHTTPURLResponse class]]
            ? (NSHTTPURLResponse *)response : nil;
        NSInteger status = http.statusCode;

        // 304: nothing changed, keep local cache.
        if (status == 304) { done(NO, nil); return; }

        if (status != 200 || !data) {
            done(NO, [self errorWithMessage:@"获取精选故事失败"]);
            return;
        }
        NSDictionary *obj = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
        if (![obj isKindOfClass:[NSDictionary class]] || [obj[@"code"] integerValue] != 0) {
            done(NO, [self errorWithMessage:(obj[@"message"] ?: @"精选故事响应异常")]);
            return;
        }
        NSDictionary *payload = [obj[@"data"] isKindOfClass:[NSDictionary class]] ? obj[@"data"] : nil;
        NSArray *items = [payload[@"stories"] isKindOfClass:[NSArray class]] ? payload[@"stories"] : @[];

        NSMutableArray<SSStory *> *stories = [NSMutableArray array];
        for (NSDictionary *item in items) {
            if (![item isKindOfClass:[NSDictionary class]]) { continue; }
            // Prefer the embedded full coze JSON (raw); it's lossless.
            SSStory *story = nil;
            id raw = item[@"raw"];
            if ([raw isKindOfClass:[NSDictionary class]]) {
                story = [SSStory storyFromCozeResponse:raw];
            }
            if (!story) { continue; }
            // Server's story_id is authoritative for featured stories.
            NSString *sid = [item[@"story_id"] isKindOfClass:[NSString class]] ? item[@"story_id"] : nil;
            if (sid.length) { story.storyID = sid; }
            [stories addObject:story];
        }

        [[SSStoryDB shared] replaceFeaturedStories:stories];
        // Prefer the server's ETag header; fall back to the body's etag field.
        NSString *newETag = http.allHeaderFields[@"Etag"] ?: http.allHeaderFields[@"ETag"];
        if (newETag.length == 0) { newETag = payload[@"etag"]; }
        [SSStoryDB shared].featuredETag = newETag;

        done(YES, nil);
    }];
    [task resume];
}

- (NSError *)errorWithMessage:(NSString *)message {
    return [NSError errorWithDomain:@"SSFeaturedStoryClient" code:-1
                          userInfo:@{NSLocalizedDescriptionKey: message ?: @"请求失败"}];
}

@end
