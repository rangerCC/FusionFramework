-- 扫描 Service（方案 3.2、17.6）。PCScanService 与各 Actor 类在 M1 实现，
-- 在此之前 class 先用 FusionService，避免懒加载时找不到类。
local service = FusionService.new("scanService", "FusionService")
service.thread_type = 0
FusionService.addActor(service, FusionActor.new("scanActor",    "PCScanActor"))
FusionService.addActor(service, FusionActor.new("hashActor",    "PCHashActor"))
FusionService.addActor(service, FusionActor.new("featureActor", "PCFeatureActor"))
FusionService.addActor(service, FusionActor.new("clusterActor", "PCClusterActor"))
FusionService.addActor(service, FusionActor.new("qualityActor", "PCQualityActor"))
register_logic_service(service)
