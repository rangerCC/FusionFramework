//
//  CozeWorkflowActor.h
//  SystemThinker
//
//  以 SSE 流式调用 Coze stream_run：边收事件边发节点进度，
//  workflow_end 事件取整包 output（analysis_result / new_context）。
//

#import <FusionCore/FusionCore.h>

@interface CozeWorkflowActor : FusionActor <NSURLSessionDataDelegate> {
@private
    NSURLSession        *_session;
    // taskIdentifier(NSNumber) -> 该流的上下文（message + 行缓冲 + 结果）
    NSMutableDictionary *_streamContexts;
}
@end
