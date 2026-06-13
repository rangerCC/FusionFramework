//
//  STModels.h
//  SystemThinker
//
//  会话与消息数据模型。
//

#import <Foundation/Foundation.h>

// 消息角色
typedef NS_ENUM(NSInteger, STMessageRole) {
    STMessageRoleUser = 0,
    STMessageRoleAssistant = 1
};

#pragma mark - 会话

@interface STSession : NSObject
@property (nonatomic, copy)   NSString *sessionId;       // UUID
@property (nonatomic, copy)   NSString *title;           // 用户可改，默认取问题摘要前 20 字
@property (nonatomic, copy)   NSString *problemSummary;  // 从 new_context 解析
@property (nonatomic, copy)   NSString *completedStages; // JSON 数组字符串
@property (nonatomic, copy)   NSString *lastContext;     // 原始 new_context 字符串（下一轮 session_context）
@property (nonatomic, assign) NSTimeInterval lastUpdateTime;
@end

#pragma mark - 消息

@interface STMessage : NSObject
@property (nonatomic, copy)   NSString *messageId;       // UUID
@property (nonatomic, copy)   NSString *sessionId;       // 外键
@property (nonatomic, assign) STMessageRole role;
@property (nonatomic, copy)   NSString *content;         // Markdown 原文
@property (nonatomic, assign) NSTimeInterval timestamp;
@property (nonatomic, copy)   NSString *contextSnapshot; // 仅 assistant 存储
@end
