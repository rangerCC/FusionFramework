//
//  STStorageService.m
//  SystemThinker
//

#import "STStorageService.h"
#import <FMDB/FMDB.h>
#import <Utility/Utility.h>

@interface STStorageService () {
    FMDatabaseQueue *_queue;
}
@end

@implementation STStorageService

+ (instancetype)sharedInstance {
    static STStorageService *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [STStorageService new];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        // 框架的 FileHelper getDatabasePath 当前返回 nil，故自行基于
        // getAppDataDirectory 构造路径（该目录已由框架保证存在）。
        NSString *path = [NSString stringWithFormat:@"%@/systemthinker.db",
                          [FileHelper getAppDataDirectory]];
        _queue = [FMDatabaseQueue databaseQueueWithPath:path];
        [self createTablesIfNeeded];
    }
    return self;
}

- (void)createTablesIfNeeded {
    [_queue inDatabase:^(FMDatabase *db) {
        [db executeUpdate:
         @"CREATE TABLE IF NOT EXISTS session ("
         @"session_id TEXT PRIMARY KEY,"
         @"title TEXT,"
         @"problem_summary TEXT,"
         @"completed_stages TEXT,"
         @"last_context TEXT,"
         @"last_update_time INTEGER)"];

        [db executeUpdate:
         @"CREATE TABLE IF NOT EXISTS message ("
         @"message_id TEXT PRIMARY KEY,"
         @"session_id TEXT,"
         @"role INTEGER,"
         @"content TEXT,"
         @"timestamp INTEGER,"
         @"context_snapshot TEXT)"];

        [db executeUpdate:
         @"CREATE INDEX IF NOT EXISTS idx_message_session "
         @"ON message(session_id)"];
    }];
}

#pragma mark - 会话

- (BOOL)saveSession:(STSession *)session {
    if (session.sessionId.length == 0) return NO;
    __block BOOL ok = NO;
    [_queue inDatabase:^(FMDatabase *db) {
        ok = [db executeUpdate:
              @"INSERT OR REPLACE INTO session "
              @"(session_id, title, problem_summary, completed_stages, last_context, last_update_time) "
              @"VALUES (?, ?, ?, ?, ?, ?)",
              session.sessionId,
              session.title ?: @"",
              session.problemSummary ?: @"",
              session.completedStages ?: @"",
              session.lastContext ?: @"",
              @((long long)session.lastUpdateTime)];
    }];
    return ok;
}

- (NSArray<STSession *> *)allSessions {
    NSMutableArray *result = [NSMutableArray array];
    [_queue inDatabase:^(FMDatabase *db) {
        FMResultSet *rs = [db executeQuery:
                           @"SELECT * FROM session ORDER BY last_update_time DESC"];
        while ([rs next]) {
            [result addObject:[self sessionFromResultSet:rs]];
        }
        [rs close];
    }];
    return result;
}

- (STSession *)sessionById:(NSString *)sessionId {
    if (sessionId.length == 0) return nil;
    __block STSession *session = nil;
    [_queue inDatabase:^(FMDatabase *db) {
        FMResultSet *rs = [db executeQuery:
                           @"SELECT * FROM session WHERE session_id = ?", sessionId];
        if ([rs next]) {
            session = [self sessionFromResultSet:rs];
        }
        [rs close];
    }];
    return session;
}

- (BOOL)updateSessionTitle:(NSString *)title forId:(NSString *)sessionId {
    if (sessionId.length == 0) return NO;
    __block BOOL ok = NO;
    [_queue inDatabase:^(FMDatabase *db) {
        ok = [db executeUpdate:@"UPDATE session SET title = ? WHERE session_id = ?",
              title ?: @"", sessionId];
    }];
    return ok;
}

- (BOOL)deleteSession:(NSString *)sessionId {
    if (sessionId.length == 0) return NO;
    __block BOOL ok = NO;
    [_queue inDatabase:^(FMDatabase *db) {
        ok = [db executeUpdate:@"DELETE FROM session WHERE session_id = ?", sessionId];
        [db executeUpdate:@"DELETE FROM message WHERE session_id = ?", sessionId];
    }];
    return ok;
}

- (STSession *)sessionFromResultSet:(FMResultSet *)rs {
    STSession *s = [STSession new];
    s.sessionId       = [rs stringForColumn:@"session_id"];
    s.title           = [rs stringForColumn:@"title"];
    s.problemSummary  = [rs stringForColumn:@"problem_summary"];
    s.completedStages = [rs stringForColumn:@"completed_stages"];
    s.lastContext     = [rs stringForColumn:@"last_context"];
    s.lastUpdateTime  = (NSTimeInterval)[rs longLongIntForColumn:@"last_update_time"];
    return s;
}

#pragma mark - 消息

- (BOOL)saveMessage:(STMessage *)message {
    if (message.messageId.length == 0) return NO;
    __block BOOL ok = NO;
    [_queue inDatabase:^(FMDatabase *db) {
        ok = [db executeUpdate:
              @"INSERT OR REPLACE INTO message "
              @"(message_id, session_id, role, content, timestamp, context_snapshot) "
              @"VALUES (?, ?, ?, ?, ?, ?)",
              message.messageId,
              message.sessionId ?: @"",
              @(message.role),
              message.content ?: @"",
              @((long long)message.timestamp),
              message.contextSnapshot ?: @""];
    }];
    return ok;
}

- (NSArray<STMessage *> *)messagesForSession:(NSString *)sessionId {
    NSMutableArray *result = [NSMutableArray array];
    if (sessionId.length == 0) return result;
    [_queue inDatabase:^(FMDatabase *db) {
        FMResultSet *rs = [db executeQuery:
                           @"SELECT * FROM message WHERE session_id = ? ORDER BY timestamp ASC",
                           sessionId];
        while ([rs next]) {
            STMessage *m = [STMessage new];
            m.messageId       = [rs stringForColumn:@"message_id"];
            m.sessionId       = [rs stringForColumn:@"session_id"];
            m.role            = (STMessageRole)[rs intForColumn:@"role"];
            m.content         = [rs stringForColumn:@"content"];
            m.timestamp       = (NSTimeInterval)[rs longLongIntForColumn:@"timestamp"];
            m.contextSnapshot = [rs stringForColumn:@"context_snapshot"];
            [result addObject:m];
        }
        [rs close];
    }];
    return result;
}

#pragma mark - 维护

- (BOOL)clearAll {
    __block BOOL ok = NO;
    [_queue inDatabase:^(FMDatabase *db) {
        ok = [db executeUpdate:@"DELETE FROM session"];
        [db executeUpdate:@"DELETE FROM message"];
    }];
    return ok;
}

@end
