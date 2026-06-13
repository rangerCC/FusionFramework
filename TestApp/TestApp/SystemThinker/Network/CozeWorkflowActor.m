//
//  CozeWorkflowActor.m
//  SystemThinker
//
//  SSE 流式调用 Coze stream_run。使用 NSURLSession + dataDelegate 逐块接收，
//  按行解析 SSE（id: / event: / data:），处理 workflow_start/node_*/workflow_end/error/ping。
//  - node_start/node_end：发节点进度通知（驱动"思考中"升级为节点名）
//  - workflow_end：取 output.analysis_result / output.new_context，置 Finish
//  - error：置 Failed
//

#import "CozeWorkflowActor.h"
#import "STDefines.h"
#import <FusionBase/FusionBase.h>
#import "SafeARC.h"

// 单个流的上下文
@interface STStreamContext : NSObject
@property (nonatomic, strong) FusionNativeMessage *message;
@property (nonatomic, strong) NSMutableData *buffer;       // 未消费的原始字节
@property (nonatomic, copy)   NSString *analysisResult;
@property (nonatomic, copy)   NSString *resultContext;
@property (nonatomic, copy)   NSString *errorMsg;
@property (nonatomic, assign) BOOL finished;
@end

@implementation STStreamContext
- (instancetype)init {
    self = [super init];
    if (self) {
        _buffer = [NSMutableData new];
    }
    return self;
}
@end

@implementation CozeWorkflowActor

- (id)initWithConfig:(NSDictionary *)config {
    self = [super initWithConfig:config];
    if (self) {
        _streamContexts = [NSMutableDictionary new];
        NSURLSessionConfiguration *cfg = [NSURLSessionConfiguration defaultSessionConfiguration];
        cfg.timeoutIntervalForRequest = kCozeTimeout;
        cfg.timeoutIntervalForResource = kCozeTimeout * 3;
        // 回调放到串行队列，避免多流并发改 _streamContexts
        NSOperationQueue *q = [NSOperationQueue new];
        q.maxConcurrentOperationCount = 1;
        _session = [NSURLSession sessionWithConfiguration:cfg delegate:self delegateQueue:q];
    }
    return self;
}

- (void)processFusionNativeMessage:(FusionNativeMessage *)message {
    NSDictionary *args = [message args];

    // session_context：首次传空对象 {}（对齐服务端 Python/Node 示例），
    // 否则透传上次 new_context 的 JSON 对象。
    id sessionContext = nil;
    NSString *ctxStr = [args objectForKey:ST_ARG_SESSION_CONTEXT];
    if (ctxStr.length > 0 && ![ctxStr isEqualToString:ST_CONTEXT_NONE]) {
        id parsed = [ctxStr jsonObject];
        if ([parsed isKindOfClass:[NSDictionary class]]) {
            sessionContext = parsed;
        }
    }
    
    NSMutableDictionary *mutableBody = @{}.mutableCopy;
    [mutableBody setValue:[args objectForKey:ST_ARG_USER_INPUT] ?: @"" forKey:ST_ARG_USER_INPUT];
    [mutableBody setValue:[args objectForKey:ST_ARG_OUTPUT_LEVEL] ?: ST_OUTPUT_STANDARD forKey:ST_ARG_OUTPUT_LEVEL];
    [mutableBody setValue:[args objectForKey:ST_ARG_IS_URGENT]    ?: @(NO) forKey:ST_ARG_IS_URGENT];
    if (sessionContext) {
        [mutableBody setValue:sessionContext forKey:ST_ARG_SESSION_CONTEXT];
    }
    
    NSDictionary *body = mutableBody.copy;
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:kCozeStreamURL]];
    req.HTTPMethod = @"POST";
    [req setValue:[NSString stringWithFormat:@"Bearer %@", kCozeAuthToken] forHTTPHeaderField:@"Authorization"];
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [req setValue:@"text/event-stream" forHTTPHeaderField:@"Accept"];
    req.HTTPBody = [[body jsonString] dataUsingEncoding:NSUTF8StringEncoding];
    req.timeoutInterval = kCozeTimeout;

    NSURLSessionDataTask *task = [_session dataTaskWithRequest:req];
    STStreamContext *ctx = [STStreamContext new];
    ctx.message = message;
    @synchronized (_streamContexts) {
        [_streamContexts setObject:ctx forKey:@(task.taskIdentifier)];
    }
    [task resume];
}

#pragma mark - NSURLSessionDataDelegate

- (STStreamContext *)contextForTask:(NSURLSessionTask *)task {
    @synchronized (_streamContexts) {
        return [_streamContexts objectForKey:@(task.taskIdentifier)];
    }
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveData:(NSData *)data {
    STStreamContext *ctx = [self contextForTask:dataTask];
    if (ctx == nil) return;
    [ctx.buffer appendData:data];
    [self drainBuffer:ctx];
}

// 按 SSE 事件块（以空行 \n\n 分隔）解析；保留最后不完整的块。
// 对齐服务端 Node.js 示例：块内取所有 data: 行，用 \n join 后整体解析为一个 JSON。
- (void)drainBuffer:(STStreamContext *)ctx {
    NSString *text = [[NSString alloc] initWithData:ctx.buffer encoding:NSUTF8StringEncoding];
    if (text == nil) return;  // 可能切到多字节中途，等下一块再解

    // 统一换行，按空行分块
    NSString *normalized = [text stringByReplacingOccurrencesOfString:@"\r\n" withString:@"\n"];
    NSArray<NSString *> *blocks = [normalized componentsSeparatedByString:@"\n\n"];
    if (blocks.count <= 1) return;  // 还没出现完整事件块，继续等

    // 最后一块可能不完整，留回缓冲
    NSString *tail = [blocks lastObject];
    NSArray<NSString *> *complete = [blocks subarrayWithRange:NSMakeRange(0, blocks.count - 1)];
    ctx.buffer = [[tail dataUsingEncoding:NSUTF8StringEncoding] mutableCopy] ?: [NSMutableData data];

    for (NSString *block in complete) {
        [self handleEventBlock:block forContext:ctx];
    }
}

// 处理一个完整事件块：收集 data: 行 -> \n join -> 解析 JSON
- (void)handleEventBlock:(NSString *)block forContext:(STStreamContext *)ctx {
    NSArray<NSString *> *lines = [block componentsSeparatedByString:@"\n"];
    NSMutableArray<NSString *> *dataLines = [NSMutableArray array];
    for (NSString *raw in lines) {
        NSString *line = [raw stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\r"]];
        if ([line hasPrefix:@"data:"]) {
            [dataLines addObject:[[line substringFromIndex:5] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]];
        }
        // id: / event: / 注释行忽略
    }
    if (dataLines.count == 0) return;
    NSString *dataText = [dataLines componentsJoinedByString:@"\n"];
    [self dispatchEventData:dataText context:ctx];
}

// 解析 data JSON，按 data.type 处理
- (void)dispatchEventData:(NSString *)dataStr context:(STStreamContext *)ctx {
    NSLog(@"dataStr = %@", dataStr);
    id obj = [dataStr jsonObject];
    if (![obj isKindOfClass:[NSDictionary class]]) return;
    NSDictionary *d = (NSDictionary *)obj;

    // 兼容两种结构：① data: 行就是事件体本身（含 type/output）
    //              ② data: 行是整包 {id,event,data:{type,output}}，需下钻 data
    id inner = d[@"data"];
    if ([inner isKindOfClass:[NSDictionary class]] && inner[@"type"]) {
        d = (NSDictionary *)inner;
    } else if ([inner isKindOfClass:[NSString class]]) {
        id parsedInner = [(NSString *)inner jsonObject];
        if ([parsedInner isKindOfClass:[NSDictionary class]] && parsedInner[@"type"]) {
            d = (NSDictionary *)parsedInner;
        }
    }

    NSString *type = d[@"type"];

    if ([type isEqualToString:@"node_start"] || [type isEqualToString:@"node_end"]) {
        NSString *node = d[@"node_name"];
        if (node.length > 0) {
            [self postProgress:[NSString stringWithFormat:@"正在执行：%@", node] context:ctx];
        }
    } else if ([type isEqualToString:@"workflow_end"]) {
        // output 可能是对象，也可能是 JSON 字符串
        id output = d[@"output"];
        if ([output isKindOfClass:[NSString class]]) {
            output = [(NSString *)output jsonObject];
        }
        if ([output isKindOfClass:[NSDictionary class]]) {
            // new_context：下一轮 session_context（字符串或对象都存成字符串）
            id nc = output[ST_RESULT_NEW_CONTEXT];
            NSString *ncStr = nil;
            if ([nc isKindOfClass:[NSString class]]) {
                ncStr = nc;
            } else if ([nc isKindOfClass:[NSDictionary class]]) {
                ncStr = [(NSDictionary *)nc jsonString];
            }
            ctx.resultContext = ncStr;

            // 正文：优先 analysis_result；该工作流可能不下发，则回退到
            // new_context 内的 last_stage_output。
            NSString *analysis = [self stringValue:output[ST_RESULT_ANALYSIS]];
            if (analysis.length == 0 && ncStr.length > 0) {
                id ncObj = [ncStr jsonObject];
                if ([ncObj isKindOfClass:[NSDictionary class]]) {
                    analysis = [self stringValue:((NSDictionary *)ncObj)[@"last_stage_output"]];
                }
            }
            ctx.analysisResult = analysis;
        }
    } else if ([type isEqualToString:@"error"]) {
        NSString *m = d[@"message"];
        ctx.errorMsg = m.length > 0 ? m : @"服务返回错误";
    }
    // workflow_start / ping：忽略
}

- (NSString *)stringValue:(id)v {
    if ([v isKindOfClass:[NSString class]]) return v;
    if (v == nil || v == [NSNull null]) return nil;
    return [NSString stringWithFormat:@"%@", v];
}

- (void)postProgress:(NSString *)text context:(STStreamContext *)ctx {
    FusionNativeMessage *message = ctx.message;
    if (message == nil || text.length == 0) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:ST_STREAM_PROGRESS_NOTIFICATION
                                                            object:message
                                                          userInfo:@{ST_PROGRESS_TEXT: text}];
    });
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
    didCompleteWithError:(NSError *)error {
    STStreamContext *ctx = [self contextForTask:task];
    if (ctx == nil) return;
    @synchronized (_streamContexts) {
        [_streamContexts removeObjectForKey:@(task.taskIdentifier)];
    }
    // 消费缓冲里残留的最后一个事件块（结束时可能没有尾随空行）
    NSString *tail = [[NSString alloc] initWithData:ctx.buffer encoding:NSUTF8StringEncoding];
    if (tail.length > 0) {
        [self handleEventBlock:tail forContext:ctx];
    }

    FusionNativeMessage *message = ctx.message;
    if (message == nil) return;

    if (error) {
        [message setValue:@"网络连接失败，请检查网络" ToDataTableWith:ST_RESULT_ERROR_MSG];
        [message setState:FusionNativeMessageFailed];
        return;
    }
    if (ctx.errorMsg.length > 0) {
        [message setValue:ctx.errorMsg ToDataTableWith:ST_RESULT_ERROR_MSG];
        [message setState:FusionNativeMessageFailed];
        return;
    }
    if (ctx.analysisResult.length == 0) {
        [message setValue:@"返回内容异常，请重试" ToDataTableWith:ST_RESULT_ERROR_MSG];
        [message setState:FusionNativeMessageFailed];
        return;
    }
    [message setValue:ctx.analysisResult ToDataTableWith:ST_RESULT_ANALYSIS];
    if (ctx.resultContext) {
        [message setValue:ctx.resultContext ToDataTableWith:ST_RESULT_NEW_CONTEXT];
    }
    [message setState:FusionNativeMessageFinish];
}

- (void)cancelFusionNativeMessage:(FusionNativeMessage *)message {
    @synchronized (_streamContexts) {
        NSNumber *foundKey = nil;
        for (NSNumber *key in _streamContexts) {
            STStreamContext *ctx = _streamContexts[key];
            if (ctx.message == message) { foundKey = key; break; }
        }
        if (foundKey) {
            [_streamContexts removeObjectForKey:foundKey];
            [_session getTasksWithCompletionHandler:^(NSArray *dataTasks, NSArray *u, NSArray *d) {
                for (NSURLSessionTask *t in dataTasks) {
                    if (t.taskIdentifier == foundKey.unsignedIntegerValue) { [t cancel]; }
                }
            }];
        }
    }
}

- (void)dealloc {
    [_session invalidateAndCancel];
    SafeRelease(_session);
    SafeRelease(_streamContexts);
    SafeSuperDealloc(super);
}

@end

