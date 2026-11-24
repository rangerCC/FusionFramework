-- 相册访问 Service（方案 3.2）。Actor 类在 M1 实现，这里先注册名称以生成宏。
local service = FusionService.new("photoLibService", "FusionService")
service.thread_type = 0
FusionService.addActor(service, FusionActor.new("authActor",   "PCAuthActor"))
FusionService.addActor(service, FusionActor.new("syncActor",   "PCSyncActor"))
FusionService.addActor(service, FusionActor.new("deleteActor", "PCDeleteActor"))
FusionService.addActor(service, FusionActor.new("sizeActor",   "PCSizeActor"))
register_logic_service(service)
