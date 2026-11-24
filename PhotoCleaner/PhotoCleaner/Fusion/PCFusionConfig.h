//
//  PCFusionConfig.h
//  PhotoCleaner
//
//  IFusionConfig provider (task M0-03). Service configuration comes from the
//  Lua scripts packed into config.zip by Workspace/MacroMaker.lua and is read
//  through the standard LuaRT (Workspace/Script/ServiceLoader.lua).
//

#import <Foundation/Foundation.h>
#import <FusionCore/FusionCore.h>

NS_ASSUME_NONNULL_BEGIN

@interface PCFusionConfig : NSObject <IFusionConfig>

+ (instancetype)sharedConfig;

/// Makes sure the config.zip copied into the app data directory matches the
/// one shipped in the bundle. FileHelper only copies the bundled file when no
/// copy exists, so without this check an app update (or a new debug build)
/// would keep running stale Lua config. Call once before prepareWithConfig:.
+ (void)installBundledConfigIfNeeded;

@end

NS_ASSUME_NONNULL_END
