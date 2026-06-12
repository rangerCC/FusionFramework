//
//  SSStoryDB.m
//  SocialStoryCore
//

#import "SSStoryDB.h"
#import "SSStory.h"
#import <FMDB/FMDB.h>

static NSString *const kFeaturedETagKey = @"ss_featured_etag";

@interface SSStoryDB ()
@property (nonatomic, strong) FMDatabaseQueue *queue;
@end

@implementation SSStoryDB

+ (instancetype)shared {
    static SSStoryDB *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [SSStoryDB new]; });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _queue = [FMDatabaseQueue databaseQueueWithPath:[self databasePath]];
        [self createTables];
    }
    return self;
}

- (NSString *)databasePath {
    NSURL *dir = [[NSFileManager defaultManager] URLForDirectory:NSApplicationSupportDirectory
                                                        inDomain:NSUserDomainMask
                                               appropriateForURL:nil create:YES error:NULL];
    return [[dir URLByAppendingPathComponent:@"social_story.sqlite"] path];
}

- (void)createTables {
    [self.queue inDatabase:^(FMDatabase *db) {
        [db executeUpdate:@"CREATE TABLE IF NOT EXISTS featured_story ("
            "story_id TEXT PRIMARY KEY, title TEXT, image_url TEXT, word_count INTEGER,"
            "raw_json TEXT, sort INTEGER DEFAULT 0, created_at REAL)"];
        [db executeUpdate:@"CREATE TABLE IF NOT EXISTS user_story ("
            "story_id TEXT PRIMARY KEY, title TEXT, image_url TEXT, word_count INTEGER,"
            "raw_json TEXT, created_at REAL, last_read_at REAL)"];
    }];
}

#pragma mark - Row <-> model

// Build a row-backed SSStory: prefer reconstructing from raw_json (lossless),
// fall back to the stored columns if raw is missing/corrupt.
- (SSStory *)storyFromResultSet:(FMResultSet *)rs {
    NSString *raw = [rs stringForColumn:@"raw_json"];
    SSStory *story = raw.length ? [SSStory storyFromRawJSON:raw] : nil;
    if (!story) {
        story = [SSStory new];
        story.storyID = [rs stringForColumn:@"story_id"];
        story.title = [rs stringForColumn:@"title"];
        story.imageURL = [rs stringForColumn:@"image_url"];
        story.wordCount = [rs intForColumn:@"word_count"];
        story.rawJSON = raw;
    }
    // The id/createdAt columns are authoritative (raw may lack story_id).
    story.storyID = [rs stringForColumn:@"story_id"];
    double created = [rs doubleForColumn:@"created_at"];
    if (created > 0) { story.createdAt = [NSDate dateWithTimeIntervalSince1970:created]; }
    if ([rs columnIsNull:@"last_read_at"] == NO) {
        double lr = [rs doubleForColumn:@"last_read_at"];
        if (lr > 0) { story.lastReadAt = [NSDate dateWithTimeIntervalSince1970:lr]; }
    }
    return story;
}

#pragma mark - Featured

- (NSArray<SSStory *> *)allFeaturedStories {
    NSMutableArray<SSStory *> *out = [NSMutableArray array];
    [self.queue inDatabase:^(FMDatabase *db) {
        FMResultSet *rs = [db executeQuery:@"SELECT * FROM featured_story ORDER BY sort ASC, created_at ASC"];
        while ([rs next]) { [out addObject:[self storyFromResultSet:rs]]; }
        [rs close];
    }];
    return out;
}

- (void)replaceFeaturedStories:(NSArray<SSStory *> *)stories {
    [self.queue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        [db executeUpdate:@"DELETE FROM featured_story"];
        NSInteger sort = 0;
        for (SSStory *s in stories) {
            [db executeUpdate:@"INSERT OR REPLACE INTO featured_story "
                "(story_id, title, image_url, word_count, raw_json, sort, created_at) "
                "VALUES (?,?,?,?,?,?,?)",
                s.storyID, s.title, (s.imageURL ?: [NSNull null]), @(s.wordCount),
                (s.rawJSON ?: [NSNull null]), @(sort),
                @([(s.createdAt ?: [NSDate date]) timeIntervalSince1970])];
            sort++;
        }
    }];
}

- (void)seedFeaturedIfEmpty:(NSArray<SSStory *> *)demoStories {
    __block BOOL empty = YES;
    [self.queue inDatabase:^(FMDatabase *db) {
        FMResultSet *rs = [db executeQuery:@"SELECT COUNT(*) AS c FROM featured_story"];
        if ([rs next]) { empty = ([rs intForColumn:@"c"] == 0); }
        [rs close];
    }];
    if (empty && demoStories.count) {
        [self replaceFeaturedStories:demoStories];
    }
}

- (NSString *)featuredETag {
    return [[NSUserDefaults standardUserDefaults] stringForKey:kFeaturedETagKey];
}

- (void)setFeaturedETag:(NSString *)featuredETag {
    if (featuredETag.length) {
        [[NSUserDefaults standardUserDefaults] setObject:featuredETag forKey:kFeaturedETagKey];
    } else {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:kFeaturedETagKey];
    }
}

#pragma mark - User stories

- (NSArray<SSStory *> *)allUserStories {
    NSMutableArray<SSStory *> *out = [NSMutableArray array];
    [self.queue inDatabase:^(FMDatabase *db) {
        FMResultSet *rs = [db executeQuery:@"SELECT * FROM user_story ORDER BY created_at DESC"];
        while ([rs next]) { [out addObject:[self storyFromResultSet:rs]]; }
        [rs close];
    }];
    return out;
}

- (void)upsertUserStory:(SSStory *)story {
    if (story.storyID.length == 0) { return; }
    [self.queue inDatabase:^(FMDatabase *db) {
        // Preserve an existing created_at on update; default to now on insert.
        NSTimeInterval created = [(story.createdAt ?: [NSDate date]) timeIntervalSince1970];
        [db executeUpdate:@"INSERT OR REPLACE INTO user_story "
            "(story_id, title, image_url, word_count, raw_json, created_at, last_read_at) "
            "VALUES (?,?,?,?,?,?, (SELECT last_read_at FROM user_story WHERE story_id = ?))",
            story.storyID, story.title, (story.imageURL ?: [NSNull null]), @(story.wordCount),
            (story.rawJSON ?: [NSNull null]), @(created), story.storyID];
    }];
}

- (void)deleteUserStoryWithID:(NSString *)storyID {
    if (storyID.length == 0) { return; }
    [self.queue inDatabase:^(FMDatabase *db) {
        [db executeUpdate:@"DELETE FROM user_story WHERE story_id = ?", storyID];
    }];
}

- (void)deleteAllUserStories {
    [self.queue inDatabase:^(FMDatabase *db) {
        [db executeUpdate:@"DELETE FROM user_story"];
    }];
}

- (void)markUserStoryRead:(NSString *)storyID {
    if (storyID.length == 0) { return; }
    [self.queue inDatabase:^(FMDatabase *db) {
        [db executeUpdate:@"UPDATE user_story SET last_read_at = ? WHERE story_id = ?",
            @([[NSDate date] timeIntervalSince1970]), storyID];
    }];
}

#pragma mark - Lookup

- (SSStory *)storyWithID:(NSString *)storyID {
    if (storyID.length == 0) { return nil; }
    __block SSStory *story = nil;
    [self.queue inDatabase:^(FMDatabase *db) {
        FMResultSet *rs = [db executeQuery:@"SELECT * FROM featured_story WHERE story_id = ?", storyID];
        if ([rs next]) { story = [self storyFromResultSet:rs]; }
        [rs close];
        if (story) { return; }
        rs = [db executeQuery:@"SELECT * FROM user_story WHERE story_id = ?", storyID];
        if ([rs next]) { story = [self storyFromResultSet:rs]; }
        [rs close];
    }];
    return story;
}

@end
