//
//  PCPingActor.h
//  PhotoClean
//
//  Diagnostic actor used to verify the Fusion message pipeline end to end
//  (task M0-03). Echoes args[@"payload"] into the dataTable under
//  PCPingResultKey together with the name of the thread it ran on.
//

#import <Foundation/Foundation.h>
#import <FusionCore/FusionCore.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *const PCPingPayloadKey;
FOUNDATION_EXPORT NSString *const PCPingResultKey;
FOUNDATION_EXPORT NSString *const PCPingThreadKey;

@interface PCPingActor : FusionActor
@end

NS_ASSUME_NONNULL_END
