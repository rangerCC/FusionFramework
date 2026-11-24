//
//  PCFusionConfig.m
//  PhotoCleaner
//

#import "PCFusionConfig.h"
#import <Utility/Utility.h>
#import <CommonCrypto/CommonDigest.h>
#import <PhotoClean/PCLog.h>

static NSString *const kServiceLoaderScript = @"ServiceLoader";

@implementation PCFusionConfig

+ (instancetype)sharedConfig {
    static PCFusionConfig *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [PCFusionConfig new];
    });
    return instance;
}

#pragma mark - config.zip installation

static NSData *PCSHA256OfFile(NSString *path) {
    NSData *data = [NSData dataWithContentsOfFile:path options:NSDataReadingMappedIfSafe error:nil];
    if (data == nil) return nil;
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(data.bytes, (CC_LONG)data.length, digest);
    return [NSData dataWithBytes:digest length:sizeof(digest)];
}

+ (void)installBundledConfigIfNeeded {
    NSString *bundled = [[NSBundle mainBundle] pathForResource:@"config" ofType:@"zip"];
    if (bundled == nil) {
        PCLogError(@"config.zip is missing from the app bundle; run `lua MacroMaker.lua` in Workspace/");
        return;
    }
    // getConfigFilePath copies the bundled file when no installed copy exists.
    NSString *installed = [FileHelper getConfigFilePath];
    NSData *bundledHash = PCSHA256OfFile(bundled);
    NSData *installedHash = PCSHA256OfFile(installed);
    if (installedHash != nil && [installedHash isEqualToData:bundledHash]) return;

    PCLogInfo(@"Installed config.zip is stale, replacing it with the bundled copy");
    [[NSFileManager defaultManager] removeItemAtPath:installed error:nil];
    [FileHelper getConfigFilePath];
}

#pragma mark - IFusionConfig

- (NSString *)appScheme {
    return @"photocleaner";
}

- (NSArray *)getCoreService {
    id result = [self callServiceLoader:@"getCoreServices" args:nil];
    if ([result isKindOfClass:[NSArray class]]) return result;
    if ([result isKindOfClass:[NSDictionary class]]) return [(NSDictionary *)result allValues];
    return @[];
}

- (NSDictionary *)getLogicServiceByName:(NSString *)serviceName {
    if (serviceName.length == 0) return nil;
    id result = [self callServiceLoader:@"queryLogicServiceByName" args:@[serviceName]];
    if ([result isKindOfClass:[NSDictionary class]]) return result;
    PCLogWarn(@"No logic service config for %@", serviceName);
    return nil;
}

- (id)callServiceLoader:(NSString *)method args:(NSArray *)args {
    id result = nil;
    BOOL ok = [[LuaRT standardLuaRT] callLuaScript:kServiceLoaderScript
                                            method:method
                                              args:args
                                        returnType:LuaRT_Table
                                         returnObj:&result];
    if (!ok) {
        // On failure LuaRT puts the Lua error string (if any) into result.
        if ([result isKindOfClass:[NSString class]]) {
            PCLogError(@"ServiceLoader.%@ failed: %@", method, result);
        }
        return nil;
    }
    return result;
}

@end
