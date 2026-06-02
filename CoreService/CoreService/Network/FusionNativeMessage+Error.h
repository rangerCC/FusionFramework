//
//  FusionNativeMessage+Error.h
//  CoreService
//
//  Convenience for storing structured error information into a message's
//  dataTable, used by the network actors.
//

#import <FusionCore/FusionCore.h>

@interface FusionNativeMessage (Error)

- (void)setErrorDomainCode:(NSInteger)errorDomain
                 errorCode:(NSInteger)errorCode
                  errorMsg:(NSString *)errorMsg;

@end
