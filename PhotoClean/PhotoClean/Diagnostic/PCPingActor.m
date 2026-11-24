//
//  PCPingActor.m
//  PhotoClean
//

#import "PCPingActor.h"
#import "SafeARC.h"

NSString *const PCPingPayloadKey = @"payload";
NSString *const PCPingResultKey  = @"pong";
NSString *const PCPingThreadKey  = @"thread";

@implementation PCPingActor

- (void)processFusionNativeMessage:(FusionNativeMessage *)message {
    id payload = [[message args] objectForKey:PCPingPayloadKey];
    if (payload == nil) {
        [message setState:FusionNativeMessageFailed];
        return;
    }
    NSThread *thread = [NSThread currentThread];
    NSString *threadName = thread.isMainThread ? @"main" : (thread.name.length ? thread.name : @"worker");
    [message setValue:payload ToDataTableWith:PCPingResultKey];
    [message setValue:threadName ToDataTableWith:PCPingThreadKey];
    [message setState:FusionNativeMessageFinish];
}

@end
