//
//  PCSignpost.m
//  PhotoClean
//

#import "PCSignpost.h"

os_log_t PCSignpostLog(void) {
    static os_log_t log;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        log = os_log_create("com.kevinapp.CleanPhoto", "Pipeline");
    });
    return log;
}

// os_signpost requires a string literal for the interval name, so each
// stage gets its own begin/end pair.
os_signpost_id_t PCSignpostBegin(PCStage stage) {
    os_log_t log = PCSignpostLog();
    os_signpost_id_t sid = os_signpost_id_generate(log);
    switch (stage) {
        case PCStageMetadataSync: os_signpost_interval_begin(log, sid, "MetadataSync"); break;
        case PCStageHash:         os_signpost_interval_begin(log, sid, "Hash"); break;
        case PCStageFeature:      os_signpost_interval_begin(log, sid, "Feature"); break;
        case PCStageCluster:      os_signpost_interval_begin(log, sid, "Cluster"); break;
        case PCStageDelete:       os_signpost_interval_begin(log, sid, "Delete"); break;
    }
    return sid;
}

void PCSignpostEnd(PCStage stage, os_signpost_id_t sid) {
    os_log_t log = PCSignpostLog();
    switch (stage) {
        case PCStageMetadataSync: os_signpost_interval_end(log, sid, "MetadataSync"); break;
        case PCStageHash:         os_signpost_interval_end(log, sid, "Hash"); break;
        case PCStageFeature:      os_signpost_interval_end(log, sid, "Feature"); break;
        case PCStageCluster:      os_signpost_interval_end(log, sid, "Cluster"); break;
        case PCStageDelete:       os_signpost_interval_end(log, sid, "Delete"); break;
    }
}
