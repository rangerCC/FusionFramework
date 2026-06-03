//
//  SSStoryAPIClient.h
//  SocialStoryCore
//
//  Calls the Cloudflare Worker (which proxies the Coze workflow) to generate
//  a social story. Returns a mock story when SSConfig.useMock is YES.
//

#import <Foundation/Foundation.h>

@class SSStory;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, SSLanguageLevel) {
    SSLanguageLevelSimple = 0,   // 简单
    SSLanguageLevelStandard = 1  // 标准
};

@interface SSStoryGenerationRequest : NSObject
@property (nonatomic, copy)   NSString *sceneText;    // 场景描述
@property (nonatomic, copy)   NSString *childName;    // 儿童名字
@property (nonatomic, assign) NSInteger childAge;     // 年龄
@property (nonatomic, assign) SSLanguageLevel level;  // 语言水平
@end

@interface SSStoryAPIClient : NSObject

+ (instancetype)shared;

/// Generate a story. completion is always called on the main thread.
/// On success, error is nil and story is non-nil.
- (void)generateStoryWithRequest:(SSStoryGenerationRequest *)request
                      completion:(void (^)(SSStory * _Nullable story, NSError * _Nullable error))completion;

@end

NS_ASSUME_NONNULL_END
