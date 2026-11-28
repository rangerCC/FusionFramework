//
//  SSChild.h
//  SocialStoryCore
//
//  A child profile fetched from /v1/children. Reuses the generation enums
//  (SSGender / SSDiagnosisType / SSLanguageLevel) so a selected child maps
//  directly onto SSStoryGenerationRequest.
//

#import <Foundation/Foundation.h>
#import <SocialStoryCore/SSStoryAPIClient.h>

NS_ASSUME_NONNULL_BEGIN

@interface SSChild : NSObject

@property (nonatomic, copy)   NSString *childID;        // child_id
@property (nonatomic, copy)   NSString *name;
@property (nonatomic, assign) SSGender gender;
@property (nonatomic, copy)   NSString *birthday;       // yyyy-MM-dd
@property (nonatomic, assign) NSInteger age;            // server-computed, read-only
@property (nonatomic, assign) SSDiagnosisType diagnosisType;
@property (nonatomic, assign) SSLanguageLevel level;    // language_level
@property (nonatomic, copy)   NSArray<NSString *> *interests;
@property (nonatomic, copy, nullable) NSString *avatarURL;
@property (nonatomic, assign) BOOL isDefault;

/// Parse one child object from the API JSON.
+ (instancetype)childFromJSON:(NSDictionary *)json;

/// Build the create-request body (name/gender/birthday/diagnosis/level/interests).
- (NSDictionary *)creationJSON;

// Shared enum <-> wire-string mapping (kept in one place to avoid drift with
// SSStoryAPIClient).
+ (NSString *)stringForGender:(SSGender)g;
+ (NSString *)stringForDiagnosis:(SSDiagnosisType)d;
+ (NSString *)stringForLevel:(SSLanguageLevel)l;
+ (SSGender)genderFromString:(nullable NSString *)s;
+ (SSDiagnosisType)diagnosisFromString:(nullable NSString *)s;
+ (SSLanguageLevel)levelFromString:(nullable NSString *)s;

@end

NS_ASSUME_NONNULL_END
