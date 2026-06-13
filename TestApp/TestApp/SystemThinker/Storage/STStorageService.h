//
//  STStorageService.h
//  SystemThinker
//
//  会话 / 消息本地持久化（SQLite via FMDB）。
//  使用 FMDatabaseQueue 保证多线程安全（Actor 回调线程 + 主线程）。
//

#import <Foundation/Foundation.h>
#import "STModels.h"

@interface STStorageService : NSObject

+ (instancetype)sharedInstance;

#pragma mark - 会话

// 新建或更新会话（按 sessionId upsert）
- (BOOL)saveSession:(STSession *)session;

// 全部会话，按 lastUpdateTime 降序
- (NSArray<STSession *> *)allSessions;

- (STSession *)sessionById:(NSString *)sessionId;

// 重命名
- (BOOL)updateSessionTitle:(NSString *)title forId:(NSString *)sessionId;

// 删除会话（级联删除其消息）
- (BOOL)deleteSession:(NSString *)sessionId;

#pragma mark - 消息

- (BOOL)saveMessage:(STMessage *)message;

// 某会话的消息，按 timestamp 升序
- (NSArray<STMessage *> *)messagesForSession:(NSString *)sessionId;

#pragma mark - 维护

// 清除全部本地数据
- (BOOL)clearAll;

@end
