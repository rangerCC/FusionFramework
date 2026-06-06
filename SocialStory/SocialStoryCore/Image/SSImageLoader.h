//
//  SSImageLoader.h
//  SocialStoryCore
//
//  Lightweight async image loader with an in-memory cache. Shared across feature
//  pods (story cards, profile avatar) so each screen doesn't roll its own.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SSImageLoader : NSObject

+ (instancetype)shared;

/// Load the image at `urlString` into `imageView`. Cache hits are applied
/// synchronously; misses fetch on a background session and apply on the main
/// thread. Safe to call from cell reuse (last call wins via tagged URL).
- (void)loadImageURL:(nullable NSString *)urlString into:(UIImageView *)imageView;

@end

NS_ASSUME_NONNULL_END
