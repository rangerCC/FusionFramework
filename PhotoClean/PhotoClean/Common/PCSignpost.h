//
//  PCSignpost.h
//  PhotoClean
//
//  os_signpost intervals for the five pipeline stages (tech plan §11.2).
//  View them in Instruments with the "os_signpost" / "Points of Interest"
//  instrument, subsystem com.kevinapp.CleanPhoto, category Pipeline.
//
//  Usage:
//      os_signpost_id_t sid = PCSignpostBegin(PCStageHash);
//      ... work ...
//      PCSignpostEnd(PCStageHash, sid);
//

#import <Foundation/Foundation.h>
#import <os/signpost.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, PCStage) {
    PCStageMetadataSync = 0,   // 元数据同步
    PCStageHash,               // Stage 1：dHash
    PCStageFeature,            // Stage 2：FeaturePrint
    PCStageCluster,            // 聚类
    PCStageDelete,             // 删除
};

FOUNDATION_EXPORT os_log_t PCSignpostLog(void);

/// Starts an interval and returns its id; pass the id to PCSignpostEnd.
FOUNDATION_EXPORT os_signpost_id_t PCSignpostBegin(PCStage stage);
FOUNDATION_EXPORT void PCSignpostEnd(PCStage stage, os_signpost_id_t signpostID);

NS_ASSUME_NONNULL_END
