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
        // Coze workflow endpoint. NOTE: calling Coze directly from the app means
        // the bearer token below ships inside the client and can be extracted.
        // For production, proxy this through a Cloudflare Worker that injects the
        // token server-side and point workerURLString at the Worker instead.
        _workerURLString = @"https://fbfm6vvyrv.coze.site/run";
        _authToken = @"eyJhbGciOiJSUzI1NiIsImtpZCI6ImRlN2UzOTQ1LTMxMmItNDIyMS1iMjdlLTVhMzI1NzNiOTk1ZiJ9.eyJpc3MiOiJodHRwczovL2FwaS5jb3plLmNuIiwiYXVkIjpbIkloOEJhQ0VWd25KMFJYVzdYQ3RBdTVObG9hN29QTXhKIl0sImV4cCI6ODIxMDI2Njg3Njc5OSwiaWF0IjoxNzgwNDc4MTQyLCJzdWIiOiJzcGlmZmU6Ly9hcGkuY296ZS5jbi93b3JrbG9hZF9pZGVudGl0eS9pZDo3NjM5MjkyMTQ1NTAwNjg0MzIzIiwic3JjIjoiaW5ib3VuZF9hdXRoX2FjY2Vzc190b2tlbl9pZDo3NjQ3MDk1MzkzMDg3Mzg5NzIzIn0.EyFTXwgSHMQ5zyoAhMoFUn7QAXtJFPKWGm4fpb-15J2Pl9VT4xgwsCwlOxc1xVpWdZjD7TmwoTG2t8A1rEHBav8frTk19G5E2uOIr3uIDcZnAMkKUCtpDNqdfj5h9k4ejd8xthasQRZHQN6q7U2flymSTBMI9Tuo1I8qyWhW6u-r4J9G8GvRvGzJFkJ_ziIfmrMopeca3V_6uLnVOMojA8mRXpCuxtj4M8YyFb6edeVkb2WXBiH2p0FyM4HuLB2b7kR-2OLNC1GRgHLfdOspOkR3nB9VZ0dCAJKrgIp4j7q6Swvh1Myg4GfzYqVeLswiT0miJO0Ui8mUytplLDpTjw";
        // Hit the real backend by default; flip to YES for offline UI work.
        _useMock = NO;
    }
    return self;
}

@end
