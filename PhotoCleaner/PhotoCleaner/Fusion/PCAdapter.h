//
//  PCAdapter.h
//  PhotoCleaner
//
//  Page adapter: page and tab bar configs come from Script/Page/*.lua via
//  Workspace/Script/PageLoader.lua.
//

#import <Foundation/Foundation.h>
#import <FusionUI/FusionUI.h>

NS_ASSUME_NONNULL_BEGIN

@interface PCAdapter : NSObject <IFusionPageAdapterProtocol>
+ (instancetype)sharedAdapter;
@end

NS_ASSUME_NONNULL_END
