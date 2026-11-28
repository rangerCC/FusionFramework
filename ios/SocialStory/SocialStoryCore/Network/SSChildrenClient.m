//
//  SSChildrenClient.m
//  SocialStoryCore
//

#import "SSChildrenClient.h"
#import "SSChild.h"
#import <AccountKit/AccountKit-Swift.h>

static NSString *const kDefaultBaseURL = @"http://localhost:8080";

@interface SSChildrenClient ()
@property (nonatomic, strong) NSURLSession *session;
@end

@implementation SSChildrenClient

+ (instancetype)shared {
    static SSChildrenClient *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [SSChildrenClient new]; });
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

#pragma mark - Public

- (void)fetchChildren:(void (^)(NSArray<SSChild *> *, NSError *))completion {
    [self requestMethod:@"GET" path:@"/v1/children" body:nil retryOn401:YES
             completion:^(NSDictionary *data, NSError *error) {
        if (error) { completion(nil, error); return; }
        NSArray *arr = [data[@"children"] isKindOfClass:[NSArray class]] ? data[@"children"] : @[];
        NSMutableArray<SSChild *> *children = [NSMutableArray array];
        for (NSDictionary *d in arr) {
            SSChild *c = [SSChild childFromJSON:d];
            if (c) { [children addObject:c]; }
        }
        completion(children, nil);
    }];
}

- (void)createChild:(SSChild *)child
         completion:(void (^)(SSChild *, NSError *))completion {
    [self requestMethod:@"POST" path:@"/v1/children" body:[child creationJSON] retryOn401:YES
             completion:^(NSDictionary *data, NSError *error) {
        if (error) { completion(nil, error); return; }
        SSChild *created = [SSChild childFromJSON:data[@"child"]];
        completion(created, nil);
    }];
}

- (void)setDefaultChildID:(NSString *)childID
               completion:(void (^)(BOOL, NSError *))completion {
    NSString *path = [NSString stringWithFormat:@"/v1/children/%@/default", childID];
    [self requestMethod:@"POST" path:path body:@{} retryOn401:YES
             completion:^(NSDictionary *data, NSError *error) {
        completion(error == nil, error);
    }];
}

- (void)updateChildID:(NSString *)childID
                child:(SSChild *)child
           completion:(void (^)(SSChild *, NSError *))completion {
    NSString *path = [NSString stringWithFormat:@"/v1/children/%@", childID];
    [self requestMethod:@"PUT" path:path body:[child creationJSON] retryOn401:YES
             completion:^(NSDictionary *data, NSError *error) {
        if (error) { completion(nil, error); return; }
        SSChild *updated = [SSChild childFromJSON:data[@"child"]];
        completion(updated, nil);
    }];
}

- (void)deleteChildID:(NSString *)childID
           completion:(void (^)(BOOL, NSError *))completion {
    NSString *path = [NSString stringWithFormat:@"/v1/children/%@", childID];
    [self requestMethod:@"DELETE" path:path body:nil retryOn401:YES
             completion:^(NSDictionary *data, NSError *error) {
        completion(error == nil, error);
    }];
}

#pragma mark - HTTP (envelope { code, message, data })

- (void)requestMethod:(NSString *)method
                 path:(NSString *)path
                 body:(NSDictionary *)body
           retryOn401:(BOOL)retryOn401
           completion:(void (^)(NSDictionary * _Nullable data, NSError * _Nullable error))completion {
    NSString *urlStr = [[self baseURLString] stringByAppendingString:path];
    NSURL *url = [NSURL URLWithString:urlStr];
    if (!url) {
        [self finish:completion data:nil error:[self errorWithMessage:@"无效的服务地址" code:-1]];
        return;
    }
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    req.HTTPMethod = method;
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [req setValue:@"ios" forHTTPHeaderField:@"X-Platform"];
    NSString *token = [AccountManager shared].accessToken;
    if (token.length) {
        [req setValue:[NSString stringWithFormat:@"Bearer %@", token] forHTTPHeaderField:@"Authorization"];
    }
    if (body) {
        req.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:NULL];
    }

    __weak typeof(self) weakSelf = self;
    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:req
        completionHandler:^(NSData *respData, NSURLResponse *response, NSError *netErr) {
        __strong typeof(weakSelf) self = weakSelf;
        if (!self) { return; }
        if (netErr) {
            [self finish:completion data:nil
                   error:[self errorWithMessage:netErr.localizedDescription code:-1]];
            return;
        }
        NSDictionary *obj = [respData isKindOfClass:[NSData class]]
            ? [NSJSONSerialization JSONObjectWithData:respData options:0 error:NULL] : nil;
        if (![obj isKindOfClass:[NSDictionary class]]) {
            [self finish:completion data:nil error:[self errorWithMessage:@"服务器响应异常" code:-1]];
            return;
        }
        NSInteger code = [obj[@"code"] integerValue];
        if (code == 0) {
            id data = obj[@"data"];
            [self finish:completion data:([data isKindOfClass:[NSDictionary class]] ? data : @{}) error:nil];
            return;
        }
        // 2001 = unauthorized: try one token refresh then retry.
        if (code == 2001 && retryOn401) {
            [[AccountManager shared] refreshTokensWithCompletion:^(BOOL ok) {
                if (ok) {
                    [self requestMethod:method path:path body:body retryOn401:NO completion:completion];
                } else {
                    [self finish:completion data:nil
                           error:[self errorWithMessage:(obj[@"message"] ?: @"登录已失效") code:code]];
                }
            }];
            return;
        }
        [self finish:completion data:nil
               error:[self errorWithMessage:(obj[@"message"] ?: @"请求失败") code:code]];
    }];
    [task resume];
}

- (void)finish:(void (^)(NSDictionary *, NSError *))completion data:(NSDictionary *)data error:(NSError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(data, error); });
}

- (NSError *)errorWithMessage:(NSString *)message code:(NSInteger)code {
    return [NSError errorWithDomain:@"SSChildrenClient" code:code
                          userInfo:@{NSLocalizedDescriptionKey: message ?: @"请求失败"}];
}

@end
