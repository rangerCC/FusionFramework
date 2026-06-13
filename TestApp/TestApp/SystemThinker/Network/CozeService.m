//
//  CozeService.m
//  SystemThinker
//

#import "CozeService.h"

@implementation CozeService
- (id)initWithConfig:(NSDictionary *)config {
    self = [super initWithConfig:config];
    if (self) {
        _threadType = FusionService_NET;  // 路由到专用网络线程
    }
    return self;
}
@end
