//
//  PCPublishInfo.h
//  PhotoCleaner
//
//  Read-only access to Resources/PublishInfo.plist (task M0-06). Every
//  publish/ICP related value must be read through this class instead of
//  being hard-coded. Empty values in the plist are returned as nil.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface PCPublishInfo : NSObject

+ (instancetype)shared;

@property (nonatomic, copy, readonly, nullable) NSString *companyName;       // 上架主体名称
@property (nonatomic, copy, readonly, nullable) NSString *icpNumber;         // ICP 备案号
@property (nonatomic, copy, readonly, nullable) NSString *supportEmail;      // 客服邮箱
@property (nonatomic, strong, readonly, nullable) NSURL *privacyPolicyURL;   // 隐私政策
@property (nonatomic, strong, readonly, nullable) NSURL *termsOfUseURL;      // 使用条款
@property (nonatomic, copy, readonly, nullable) NSString *appStoreID;        // App Store 数字 ID
@property (nonatomic, copy, readonly) NSString *privacyPolicyVersion;        // 隐私政策版本，升级后重新征求同意

/// itms-apps 写评价链接；appStoreID 未填写时为 nil
@property (nonatomic, strong, readonly, nullable) NSURL *writeReviewURL;

@end

NS_ASSUME_NONNULL_END
