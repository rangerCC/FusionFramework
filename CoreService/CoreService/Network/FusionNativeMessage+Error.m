//
//  FusionNativeMessage+Error.m
//  CoreService
//

#import "FusionNativeMessage+Error.h"
#import "NetworkCommon.h"

@implementation FusionNativeMessage (Error)

- (void)setErrorDomainCode:(NSInteger)errorDomain
                 errorCode:(NSInteger)errorCode
                  errorMsg:(NSString *)errorMsg {
    [self setValue:@(errorDomain) ToDataTableWith:MESSAGE_ERROR_DOMAIN];
    [self setValue:@(errorCode) ToDataTableWith:MESSAGE_ERROR_CODE];
    if (errorMsg != nil) {
        [self setValue:errorMsg ToDataTableWith:MESSAGE_ERROR_MSG];
    }
}

@end
