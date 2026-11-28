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

/// Cloudflare Worker / Coze endpoint that generates a story.
@property (nonatomic, copy) NSString *workerURLString;

/// Bearer token for the endpoint. WARNING: shipping this in the client is a
/// leak risk; proxy via a Worker in production.
@property (nonatomic, copy) NSString *authToken;

/// When YES, the API client returns canned data instead of hitting the network.
@property (nonatomic, assign) BOOL useMock;

@end

NS_ASSUME_NONNULL_END
