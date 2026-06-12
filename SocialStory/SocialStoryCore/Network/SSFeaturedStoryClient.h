//
//  SSFeaturedStoryClient.h
//  SocialStoryCore
//
//  Fetches server-managed featured (精选) stories with ETag-based change
//  detection, persisting them into SSStoryDB's featured table. Base URL comes
//  from LocalConfig.plist (same source as login). Public endpoint, no auth.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SSFeaturedStoryClient : NSObject

+ (instancetype)shared;

/// GET /v1/featured-stories with If-None-Match. On 200, replaces the local
/// featured table and stores the new ETag (changed=YES). On 304, leaves local
/// data untouched (changed=NO). completion runs on the main thread.
- (void)refreshWithCompletion:(nullable void (^)(BOOL changed, NSError * _Nullable error))completion;

@end

NS_ASSUME_NONNULL_END
