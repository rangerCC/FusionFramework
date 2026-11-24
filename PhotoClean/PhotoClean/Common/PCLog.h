//
//  PCLog.h
//  PhotoClean
//
//  Logging for the PhotoClean module, built on CocoaLumberjack.
//  Privacy rule: never log image content, file paths of user media, or
//  anything that identifies a photo beyond what is needed for debugging.
//  PCLogDebug is compiled out of Release builds.
//

#import <Foundation/Foundation.h>
#import <CocoaLumberjack/CocoaLumberjack.h>

NS_ASSUME_NONNULL_BEGIN

/// Shared log level for the module. Debug builds: Debug; Release builds: Info.
FOUNDATION_EXPORT DDLogLevel PCLogLevel(void);

/// Installs the os_log logger once. Safe to call repeatedly.
FOUNDATION_EXPORT void PCLogSetup(void);

NS_ASSUME_NONNULL_END

#define PC_LOG_MACRO(lvl, flg, frmt, ...) \
    LOG_MAYBE(NO, PCLogLevel(), flg, 0, nil, __PRETTY_FUNCTION__, frmt, ##__VA_ARGS__)

#define PCLogError(frmt, ...) PC_LOG_MACRO(PCLogLevel(), DDLogFlagError,   frmt, ##__VA_ARGS__)
#define PCLogWarn(frmt, ...)  PC_LOG_MACRO(PCLogLevel(), DDLogFlagWarning, frmt, ##__VA_ARGS__)
#define PCLogInfo(frmt, ...)  PC_LOG_MACRO(PCLogLevel(), DDLogFlagInfo,    frmt, ##__VA_ARGS__)

#if DEBUG
#define PCLogDebug(frmt, ...) PC_LOG_MACRO(PCLogLevel(), DDLogFlagDebug,   frmt, ##__VA_ARGS__)
#else
#define PCLogDebug(frmt, ...) do {} while (0)
#endif
