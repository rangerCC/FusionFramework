//
//  PCPublishInfo.m
//  PhotoCleaner
//

#import "PCPublishInfo.h"

@implementation PCPublishInfo

+ (instancetype)shared {
    static PCPublishInfo *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[PCPublishInfo alloc] initWithBundle:[NSBundle mainBundle]];
    });
    return instance;
}

static NSString *PCNonEmpty(id value) {
    if (![value isKindOfClass:[NSString class]]) return nil;
    NSString *trimmed = [(NSString *)value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return trimmed.length ? trimmed : nil;
}

static NSURL *PCHTTPURL(NSString *string) {
    if (string == nil) return nil;
    NSURL *url = [NSURL URLWithString:string];
    NSString *scheme = url.scheme.lowercaseString;
    return ([scheme isEqualToString:@"https"] || [scheme isEqualToString:@"http"]) ? url : nil;
}

- (instancetype)initWithBundle:(NSBundle *)bundle {
    self = [super init];
    if (self) {
        NSString *path = [bundle pathForResource:@"PublishInfo" ofType:@"plist"];
        NSDictionary *info = path ? [NSDictionary dictionaryWithContentsOfFile:path] : nil;
        _companyName = PCNonEmpty(info[@"CompanyName"]);
        _icpNumber = PCNonEmpty(info[@"ICPNumber"]);
        _supportEmail = PCNonEmpty(info[@"SupportEmail"]);
        _privacyPolicyURL = PCHTTPURL(PCNonEmpty(info[@"PrivacyPolicyURL"]));
        _termsOfUseURL = PCHTTPURL(PCNonEmpty(info[@"TermsOfUseURL"]));
        _privacyPolicyVersion = PCNonEmpty(info[@"PrivacyPolicyVersion"]) ?: @"1";

        NSString *appID = PCNonEmpty(info[@"AppStoreID"]);
        NSCharacterSet *nonDigits = [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
        _appStoreID = (appID && [appID rangeOfCharacterFromSet:nonDigits].location == NSNotFound) ? appID : nil;
    }
    return self;
}

- (NSURL *)writeReviewURL {
    if (self.appStoreID == nil) return nil;
    NSString *s = [NSString stringWithFormat:@"itms-apps://itunes.apple.com/app/id%@?action=write-review", self.appStoreID];
    return [NSURL URLWithString:s];
}

@end
