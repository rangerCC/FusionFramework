//
//  SSChild.m
//  SocialStoryCore
//

#import "SSChild.h"

static NSString *SSChildStr(id v) {
    return [v isKindOfClass:[NSString class]] ? v : nil;
}

@implementation SSChild

+ (instancetype)childFromJSON:(NSDictionary *)json {
    if (![json isKindOfClass:[NSDictionary class]]) { return nil; }
    SSChild *c = [SSChild new];
    c.childID = SSChildStr(json[@"child_id"]) ?: @"";
    c.name = SSChildStr(json[@"name"]) ?: @"";
    c.gender = [self genderFromString:SSChildStr(json[@"gender"])];
    c.birthday = SSChildStr(json[@"birthday"]) ?: @"";
    c.age = [json[@"age"] respondsToSelector:@selector(integerValue)] ? [json[@"age"] integerValue] : 0;
    c.diagnosisType = [self diagnosisFromString:SSChildStr(json[@"diagnosis_type"])];
    c.level = [self levelFromString:SSChildStr(json[@"language_level"])];
    NSArray *interests = [json[@"interests"] isKindOfClass:[NSArray class]] ? json[@"interests"] : @[];
    NSMutableArray *clean = [NSMutableArray array];
    for (id s in interests) { if ([s isKindOfClass:[NSString class]]) { [clean addObject:s]; } }
    c.interests = clean;
    c.avatarURL = SSChildStr(json[@"avatar_url"]);
    c.isDefault = [json[@"is_default"] boolValue];
    return c;
}

- (NSDictionary *)creationJSON {
    return @{
        @"name": self.name ?: @"",
        @"gender": [SSChild stringForGender:self.gender],
        @"birthday": self.birthday ?: @"",
        @"diagnosis_type": [SSChild stringForDiagnosis:self.diagnosisType],
        @"language_level": [SSChild stringForLevel:self.level],
        @"interests": self.interests ?: @[],
    };
}

#pragma mark - Enum mapping

+ (NSString *)stringForGender:(SSGender)g {
    return g == SSGenderGirl ? @"girl" : @"boy";
}
+ (NSString *)stringForDiagnosis:(SSDiagnosisType)d {
    switch (d) {
        case SSDiagnosisASD: return @"asd";
        case SSDiagnosisADHD: return @"adhd";
        case SSDiagnosisSocialAnxiety: return @"social_anxiety";
        default: return @"other";
    }
}
+ (NSString *)stringForLevel:(SSLanguageLevel)l {
    switch (l) {
        case SSLanguageLevelSimple: return @"simple";
        case SSLanguageLevelModerate: return @"moderate";
        default: return @"advanced";
    }
}
+ (SSGender)genderFromString:(NSString *)s {
    return [s isEqualToString:@"girl"] ? SSGenderGirl : SSGenderBoy;
}
+ (SSDiagnosisType)diagnosisFromString:(NSString *)s {
    if ([s isEqualToString:@"asd"]) return SSDiagnosisASD;
    if ([s isEqualToString:@"adhd"]) return SSDiagnosisADHD;
    if ([s isEqualToString:@"social_anxiety"]) return SSDiagnosisSocialAnxiety;
    return SSDiagnosisOther;
}
+ (SSLanguageLevel)levelFromString:(NSString *)s {
    if ([s isEqualToString:@"simple"]) return SSLanguageLevelSimple;
    if ([s isEqualToString:@"moderate"]) return SSLanguageLevelModerate;
    return SSLanguageLevelAdvanced;
}

@end
