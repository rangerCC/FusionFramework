-- 诊断用 Service：验证 Fusion 消息链路（任务 M0-03）
local service = FusionService.new("diagnosticService", "FusionService")
service.thread_type = 0
FusionService.addActor(service, FusionActor.new("pingActor", "PCPingActor"))
register_logic_service(service)
