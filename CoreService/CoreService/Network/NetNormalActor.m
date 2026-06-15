//
//  NetNormalActor.m
//  Trip2013
//
//  Created by 淘中天 on 13-11-25.
//  Copyright (c) 2013年 alibaba. All rights reserved.
//

#import "NetNormalActor.h"
#import "NetworkCommon.h"
#import "FusionNativeMessage+Error.h"
#import <AFNetworking/AFNetworking.h>
#import <objc/runtime.h>
#import "SafeARC.h"

// 把 FusionNativeMessage 关联到其 NSURLSessionTask 上,供共享的重定向 block 反查。
static const void *kNetTaskMessageKey = &kNetTaskMessageKey;

@implementation NetNormalActor

- (id)initWithConfig:(NSDictionary *)config {
    self = [super initWithConfig:config];
    if (self) {
        _taskDic = [NSMutableDictionary new];

        _manager = [[AFHTTPSessionManager alloc] init];
        _manager.requestSerializer = [AFHTTPRequestSerializer serializer];
        AFHTTPResponseSerializer *responseSerializer = [AFHTTPResponseSerializer serializer];
        // 接受任意状态码与内容类型:状态码原样上报,由调用方判断,与旧实现一致。
        responseSerializer.acceptableStatusCodes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(100, 500)];
        responseSerializer.acceptableContentTypes = nil;
        _manager.responseSerializer = responseSerializer;

        __weak typeof(self) weakSelf = self;
        [_manager setTaskWillPerformHTTPRedirectionBlock:^NSURLRequest *(NSURLSession *session,
                                                                        NSURLSessionTask *task,
                                                                        NSURLResponse *response,
                                                                        NSURLRequest *request) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (strongSelf == nil) {
                return request;
            }
            FusionNativeMessage *message = objc_getAssociatedObject(task, kNetTaskMessageKey);
            if (message != nil &&
                [message.args valueForKey:HTTP_DISABLE_FOLLOW] &&
                [[message.args valueForKey:HTTP_DISABLE_FOLLOW] boolValue]) {
                // 不跟随重定向,把当前 3xx 响应当作最终结果。
                return nil;
            }
            if (message != nil && request.URL != nil) {
                [message setValue:[request.URL absoluteString] ToDataTableWith:HTTP_EFFECTIVE_URL];
            }
            return request;
        }];
    }
    return self;
}

- (void)processFusionNativeMessage:(FusionNativeMessage *)message {
    NSString *url = [message.args objectForKey:NET_REMOTE_URL];
    if (url == nil || [NSURL URLWithString:url] == nil) {
        [message setErrorDomainCode:ERROR_DOMAIN_NETWORK
                          errorCode:ERROR_INVALID_URL
                           errorMsg:@"无效的URL"];
        [message setState:FusionNativeMessageFailed];
        return;
    }

    NSDictionary *headers = [message.args valueForKey:NET_HTTP_HEADER];
    NSDictionary *params = [message.args valueForKey:NET_HTTP_PARAMS];

    NSString *method = [message.args valueForKey:NET_HTTP_METHOD];
    BOOL isPost = (method != nil && [method isEqualToString:HTTP_POST_METHOD]);

    __weak typeof(self) weakSelf = self;
    void (^successBlock)(NSURLSessionDataTask *, id) = ^(NSURLSessionDataTask *task, id responseObject) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        [strongSelf onNetThread:^{
            [strongSelf handleFinishMessage:message task:task data:responseObject];
        }];
    };
    void (^failureBlock)(NSURLSessionDataTask *, NSError *) = ^(NSURLSessionDataTask *task, NSError *error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        [strongSelf onNetThread:^{
            [strongSelf handleFailMessage:message task:task error:error];
        }];
    };

    NSURLSessionDataTask *dataTask = nil;
    if (isPost) {
        dataTask = [_manager POST:url parameters:params headers:headers progress:nil
                          success:successBlock failure:failureBlock];
    } else {
        dataTask = [_manager GET:url parameters:params headers:headers progress:nil
                         success:successBlock failure:failureBlock];
    }

    if (dataTask != nil) {
        objc_setAssociatedObject(dataTask, kNetTaskMessageKey, message, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [_taskDic setObject:dataTask forKey:[NSValue valueWithPointer:(__bridge const void *)(message)]];
    }
}

#pragma mark - 网络线程回调处理

- (void)handleFinishMessage:(FusionNativeMessage *)message
                       task:(NSURLSessionDataTask *)task
                       data:(NSData *)data {
    [self fillResponseInfoForMessage:message task:task];
    if (data != nil) {
        [message setValue:data ToDataTableWith:HTTP_RESPONSE_DATA];
    }
    [_taskDic removeObjectForKey:[NSValue valueWithPointer:(__bridge const void *)(message)]];
    [message setState:FusionNativeMessageFinish];
}

- (void)handleFailMessage:(FusionNativeMessage *)message
                     task:(NSURLSessionDataTask *)task
                    error:(NSError *)error {
    [self fillResponseInfoForMessage:message task:task];
    [message setErrorDomainCode:ERROR_DOMAIN_NETWORK
                      errorCode:error.code
                       errorMsg:[error localizedDescription]];
    [_taskDic removeObjectForKey:[NSValue valueWithPointer:(__bridge const void *)(message)]];
    [message setState:FusionNativeMessageFailed];
}

- (void)fillResponseInfoForMessage:(FusionNativeMessage *)message task:(NSURLSessionTask *)task {
    NSURLResponse *response = task.response;
    if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        [message setValue:[NSNumber numberWithInteger:httpResponse.statusCode]
          ToDataTableWith:HTTP_RESPONSE_CODE];
        if (httpResponse.allHeaderFields != nil) {
            [message setValue:httpResponse.allHeaderFields ToDataTableWith:HTTP_RESPONSE_HEADER];
        }
    }
}

- (void)onNetThread:(dispatch_block_t)block {
    if (block == nil) {
        return;
    }
    NSThread *netThread = [[FusionCore getInstance] getNetworkThread];
    if (netThread == nil || [NSThread currentThread] == netThread) {
        block();
        return;
    }
    [self performSelector:@selector(runBlock:) onThread:netThread withObject:[block copy] waitUntilDone:NO];
}

- (void)runBlock:(dispatch_block_t)block {
    if (block) {
        block();
    }
}

- (void)cancelFusionNativeMessage:(FusionNativeMessage *)message {
    NSValue *key = [NSValue valueWithPointer:(__bridge const void *)(message)];
    NSURLSessionDataTask *task = [_taskDic objectForKey:key];
    if (task != nil) {
        [task cancel];
        [_taskDic removeObjectForKey:key];
    }
}

- (void)dealloc {
    SafeRelease(_manager);
    SafeRelease(_taskDic);
    SafeSuperDealloc(super);
}

@end
