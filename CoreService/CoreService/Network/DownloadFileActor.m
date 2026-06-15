//
//  DownloadFileActor.m
//  Trip2013
//
//  Created by 淘中天 on 13-11-26.
//  Copyright (c) 2013年 alibaba. All rights reserved.
//

#import "DownloadFileActor.h"
#import "DownloadFileCluster.h"
#import "NetworkCommon.h"
#import "FusionNativeMessage+Error.h"
#import <AFNetworking/AFNetworking.h>
#import <Utility/Utility.h>
#import "SafeARC.h"

@implementation DownloadFileActor

- (id)initWithConfig:(NSDictionary *)config {
    self = [super initWithConfig:config];
    if (self) {
        _clusterDic = [NSMutableDictionary new];
        _taskDic = [NSMutableDictionary new];
        _manager = [[AFURLSessionManager alloc]
                    initWithSessionConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
    }
    return self;
}

- (void)processFusionNativeMessage:(FusionNativeMessage *)message {
    BOOL forceDownload = NO;
    if ([message.args valueForKey:NET_FORCE_DOWNLOAD]) {
        forceDownload = [[message.args valueForKey:NET_FORCE_DOWNLOAD] boolValue];
    }

    NSString *localPath = [message.args valueForKey:NET_LOCAL_PATH];
    if ([[FileKit getInstance] isFileExist:localPath] && forceDownload == NO) {
        [[FileKit getInstance] updateFileModifyTime:localPath];
        [message setState:FusionNativeMessageFinish];
        return;
    }

    NSString *url = [message.args valueForKey:NET_REMOTE_URL];
    if (url == nil || [NSURL URLWithString:url] == nil) {
        [message setErrorDomainCode:ERROR_DOMAIN_NETWORK
                          errorCode:ERROR_INVALID_URL
                           errorMsg:@"无效的URL"];
        [message setState:FusionNativeMessageFailed];
        return;
    }

    NSDictionary *httpHeaders = [message.args valueForKey:NET_HTTP_HEADER];

    NSString *tempPath = [message.args valueForKey:NET_TEMP_PATH];
    if (tempPath == nil || tempPath.length == 0) {
        tempPath = [FileHelper getTempPath:url];
    }

    // 同一 URL 已在下载:复用 cluster,仅追加 message(去重)。
    DownloadFileCluster *cluster = [_clusterDic valueForKey:url];
    if (cluster != nil) {
        [cluster pushNativeMessage:message];
        return;
    }

    cluster = [[DownloadFileCluster alloc] init];
    [cluster.downloadParams setValue:url forKey:NET_REMOTE_URL];
    [cluster.downloadParams setValue:localPath forKey:NET_LOCAL_PATH];
    [cluster.downloadParams setValue:tempPath forKey:NET_TEMP_PATH];
    if (httpHeaders != nil) {
        [cluster.downloadParams setValue:httpHeaders forKey:NET_HTTP_HEADER];
    }
    [cluster pushNativeMessage:message];
    [_clusterDic setValue:cluster forKey:url];

    [self startDownloadForCluster:cluster];
    SafeRelease(cluster);
}

- (void)startDownloadForCluster:(DownloadFileCluster *)cluster {
    NSString *url = [cluster.downloadParams valueForKey:NET_REMOTE_URL];
    NSString *localPath = [cluster.downloadParams valueForKey:NET_LOCAL_PATH];
    NSDictionary *headers = [cluster.downloadParams valueForKey:NET_HTTP_HEADER];

    NSMutableURLRequest *request =
        [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]];
    for (NSString *field in headers) {
        [request setValue:[headers objectForKey:field] forHTTPHeaderField:field];
    }

    __weak typeof(self) weakSelf = self;
    NSURLSessionDownloadTask *task = [_manager
        downloadTaskWithRequest:request
        progress:nil
        destination:^NSURL *(NSURL *targetPath, NSURLResponse *response) {
            // AFNetworking 把临时下载文件移动到此返回路径。
            return [NSURL fileURLWithPath:localPath];
        }
        completionHandler:^(NSURLResponse *response, NSURL *filePath, NSError *error) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            [strongSelf onNetThread:^{
                [strongSelf handleDownloadFinishForCluster:cluster response:response error:error];
            }];
        }];

    [_taskDic setObject:task forKey:[NSValue valueWithPointer:(__bridge const void *)(cluster)]];
    [task resume];
}

#pragma mark - 网络线程回调处理

- (void)handleDownloadFinishForCluster:(DownloadFileCluster *)cluster
                              response:(NSURLResponse *)response
                                 error:(NSError *)error {
    NSInteger statusCode = 0;
    NSDictionary *responseHeader = nil;
    if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        statusCode = httpResponse.statusCode;
        responseHeader = httpResponse.allHeaderFields;
    }

    NSUInteger state = (error == nil) ? FusionNativeMessageFinish : FusionNativeMessageFailed;
    for (FusionNativeMessage *message in [cluster getMessageList]) {
        [message setValue:[NSNumber numberWithInteger:statusCode] ToDataTableWith:HTTP_RESPONSE_CODE];
        if (responseHeader != nil) {
            [message setValue:responseHeader ToDataTableWith:HTTP_RESPONSE_HEADER];
        }
        if (error != nil) {
            [message setErrorDomainCode:ERROR_DOMAIN_NETWORK
                              errorCode:error.code
                               errorMsg:[error localizedDescription]];
        }
        [message setState:state];
    }

    [cluster removeAllMessages];
    [_taskDic removeObjectForKey:[NSValue valueWithPointer:(__bridge const void *)(cluster)]];
    [_clusterDic removeObjectForKey:[cluster.downloadParams valueForKey:NET_REMOTE_URL]];
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
    NSString *url = [message.args valueForKey:NET_REMOTE_URL];
    DownloadFileCluster *cluster = SafeRetain([_clusterDic valueForKey:url]);
    if (cluster == nil) {
        return;
    }

    [cluster removeNativeMessage:message];
    if ([cluster messagesCount] > 0) {
        SafeRelease(cluster);
        return;
    }

    NSValue *key = [NSValue valueWithPointer:(__bridge const void *)(cluster)];
    NSURLSessionDownloadTask *task = [_taskDic objectForKey:key];
    if (task != nil) {
        [task cancel];
        [_taskDic removeObjectForKey:key];
    }
    [_clusterDic removeObjectForKey:url];
    SafeRelease(cluster);
}

- (void)dealloc {
    SafeRelease(_manager);
    SafeRelease(_taskDic);
    SafeRelease(_clusterDic);
    SafeSuperDealloc(super);
}

@end
