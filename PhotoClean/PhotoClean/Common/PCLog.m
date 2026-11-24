//
//  PCLog.m
//  PhotoClean
//

#import "PCLog.h"

DDLogLevel PCLogLevel(void) {
#if DEBUG
    return DDLogLevelDebug;
#else
    return DDLogLevelInfo;
#endif
}

void PCLogSetup(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [DDLog addLogger:[DDOSLogger sharedInstance]];
    });
}
