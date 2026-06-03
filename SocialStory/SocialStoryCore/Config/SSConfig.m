//
//  SSConfig.m
//  SocialStoryCore
//

#import "SSConfig.h"

@implementation SSConfig

+ (instancetype)shared {
    static SSConfig *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [SSConfig new];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        // TODO: fill in the deployed Cloudflare Worker URL here.
        _workerURLString = @"";
        // Mock by default so the full flow works without a live backend.
        _useMock = YES;
    }
    return self;
}

@end
