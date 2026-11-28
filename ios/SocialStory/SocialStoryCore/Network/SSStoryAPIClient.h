//
//  SSStoryAPIClient.h
//  SocialStoryCore
//
//  Calls the Coze workflow to generate a multi-page social story.
//  Returns a mock story when SSConfig.useMock is YES.
//

#import <Foundation/Foundation.h>

@class SSStory;

NS_ASSUME_NONNULL_BEGIN

/// Language comprehension level (language_level).
typedef NS_ENUM(NSInteger, SSLanguageLevel) {
    SSLanguageLevelSimple = 0,    // simple   简单句
    SSLanguageLevelModerate = 1,  // moderate 复合句
    SSLanguageLevelAdvanced = 2   // advanced 复杂句
};

/// Diagnosis type (diagnosis_type).
typedef NS_ENUM(NSInteger, SSDiagnosisType) {
    SSDiagnosisASD = 0,            // asd
    SSDiagnosisADHD = 1,           // adhd
    SSDiagnosisSocialAnxiety = 2,  // social_anxiety
    SSDiagnosisOther = 3           // other
};

/// Tone style (tone_style).
typedef NS_ENUM(NSInteger, SSToneStyle) {
    SSToneGentle = 0,    // gentle
    SSToneCheerful = 1,  // cheerful
    SSToneCalm = 2       // calm
};

/// Child gender (gender).
typedef NS_ENUM(NSInteger, SSGender) {
    SSGenderBoy = 0,   // boy
    SSGenderGirl = 1   // girl
};

@interface SSStoryGenerationRequest : NSObject
@property (nonatomic, copy)   NSString *childName;          // child_name
@property (nonatomic, assign) NSInteger childAge;           // child_age (2-16)
@property (nonatomic, assign) SSDiagnosisType diagnosisType;// diagnosis_type
@property (nonatomic, copy)   NSString *socialScenario;     // social_scenario (50-500)
@property (nonatomic, copy)   NSString *difficultyDetail;   // difficulty_detail
@property (nonatomic, copy, nullable) NSString *preferredInterest; // preferred_interest
@property (nonatomic, assign) SSLanguageLevel level;        // language_level
@property (nonatomic, assign) SSToneStyle tone;             // tone_style
@property (nonatomic, assign) SSGender gender;              // gender
@end

@interface SSStoryAPIClient : NSObject

+ (instancetype)shared;

/// Generate a story. completion is always called on the main thread.
- (void)generateStoryWithRequest:(SSStoryGenerationRequest *)request
                      completion:(void (^)(SSStory * _Nullable story, NSError * _Nullable error))completion;

@end

NS_ASSUME_NONNULL_END
