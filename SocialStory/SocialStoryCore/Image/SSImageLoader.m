//
//  SSImageLoader.m
//  SocialStoryCore
//

#import "SSImageLoader.h"
#import <objc/runtime.h>

// Associated key: remembers the URL a given image view is currently waiting on,
// so a reused cell discards results from a previous (now-stale) request.
static const void *kSSImageLoaderURLKey = &kSSImageLoaderURLKey;

@interface SSImageLoader ()
@property (nonatomic, strong) NSCache<NSString *, UIImage *> *cache;
@end

@implementation SSImageLoader

+ (instancetype)shared {
    static SSImageLoader *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [SSImageLoader new]; });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _cache = [NSCache new];
        _cache.countLimit = 120;
    }
    return self;
}

- (void)loadImageURL:(NSString *)urlString into:(UIImageView *)imageView {
    if (!imageView) { return; }

    // Record what this view wants now; results that don't match are dropped.
    objc_setAssociatedObject(imageView, kSSImageLoaderURLKey, urlString, OBJC_ASSOCIATION_COPY_NONATOMIC);

    if (urlString.length == 0) {
        imageView.image = nil;
        return;
    }

    UIImage *cached = [self.cache objectForKey:urlString];
    if (cached) {
        imageView.image = cached;
        return;
    }

    // Clear any stale image while the new one loads.
    imageView.image = nil;

    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) { return; }

    __weak typeof(self) weakSelf = self;
    __weak UIImageView *weakIV = imageView;
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL:url
        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        UIImage *image = data ? [UIImage imageWithData:data] : nil;
        if (!image) { return; }
        __strong typeof(weakSelf) self = weakSelf;
        if (self) { [self.cache setObject:image forKey:urlString]; }
        dispatch_async(dispatch_get_main_queue(), ^{
            UIImageView *iv = weakIV;
            if (!iv) { return; }
            // Only apply if this view is still waiting on the same URL.
            NSString *current = objc_getAssociatedObject(iv, kSSImageLoaderURLKey);
            if ([current isEqualToString:urlString]) {
                iv.image = image;
            }
        });
    }];
    [task resume];
}

@end
