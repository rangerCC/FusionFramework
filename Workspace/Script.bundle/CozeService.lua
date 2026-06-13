-- CozeService.lua
-- 系统思维助手 - Coze 工作流调用服务定义
-- 经 MacroMaker 生成 TRIPServiceMacro.h:
--   COZESERVICE_SERVICE = @"cozeService"
--   WORKFLOW_ACTOR       = @"workflow"

local service = FusionService.new("cozeService", "CozeService")
FusionService.addActor(service, FusionActor.new("workflow", "CozeWorkflowActor"))
register_core_service(service)
