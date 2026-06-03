//
//  SSConfig.h
//  SocialStoryCore
//
//  Global runtime configuration (Worker URL, mock switch).
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SSConfig : NSObject

+ (instancetype)shared;

/// Cloudflare Worker endpoint that proxies the Coze workflow. Empty by default.
@property (nonatomic, copy) NSString *workerURLString;

/// When YES, the API client returns canned data instead of hitting the network.
@property (nonatomic, assign) BOOL useMock;

@end

NS_ASSUME_NONNULL_END
