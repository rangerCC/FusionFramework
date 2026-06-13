# 系统思维助手（SystemThinker）iOS App 需求文档

| 文档版本 | 修改日期 | 修改人 | 修改内容 |
|---------|----------|--------|----------|
| V1.0 | 2026-06-11 | AI产品经理 | 初稿 |
| V2.0 | 2026-06-11 | — | 重构技术架构，对齐 FusionFramework 原生能力（Actor/Service/Lua/Page），第三方依赖收敛至真实缺口（SQLite、Markdown） |

---

## 0. 架构基线说明

本 App 构建于本仓库已有的 **FusionFramework**——一套 Actor 消息驱动、Lua 代码生成的模块化 iOS 框架。需求实现**优先复用框架原生能力**，仅在框架确无对应能力的缺口处引入第三方库。

| 能力域 | 框架原生方案 | 说明 |
|--------|-------------|------|
| 网络请求 | **AFNetworking**（`AFHTTPSessionManager`） | Coze HTTPS 调用走 AFNetworking；框架自带 `NeoNetEngine` 不在本业务使用 |
| JSON 解析 | `NSString+JSON` / `NSDictionary+JSON`（FusionBase） | `-jsonObject` / `-jsonString`，**无需 MJExtension** |
| 页面导航 | `FusionPageController` + `FusionPageNavigator` + Lua 页面定义 | 框架既定页面框架 |
| 文件/目录 | `FileKit` / `FileHelper`（Utility） | 含 `getDatabasePath`、解压等 |
| **本地数据库** | ⚠️ 缺口 → 引入 **FMDB** | 框架无 SQLite 封装 |
| **Markdown 渲染** | ⚠️ 缺口 → 引入 **Down** | 框架无 Markdown 能力，需 Swift/OC 混编 |

> 现有 `Podfile` 已声明 `AFNetworking ~> 4.0`、`FMDB ~> 2.7`、`Down ~> 0.11`、`use_frameworks!`、`SWIFT_VERSION = 5.0`。网络层采用 AFNetworking（见 §3.2）；JSON 序列化/反序列化仍复用 FusionBase 原生 `-jsonString` / `-jsonObject`。

---

## 1. 产品概述

### 1.1 产品名称
**SystemThinker**（中文名：思维力助手）

### 1.2 产品定位
一款基于《思维力——高效的系统思维》方法论的智能对话工具，通过调用 Coze 工作流服务，帮助用户在职场、管理、个人成长等场景中自动应用系统思维的五大维度（发现问题、分析问题、解决问题、假设思考、自上而下表达），输出结构化分析结果，并支持多轮状态管理。

### 1.3 目标用户
- 职场人士（汇报、决策、项目复盘）
- 产品经理/项目经理（问题界定、根因分析）
- 创业者/管理者（战略决策、方案制定）
- 学生（论文答辩、报告整理）

### 1.4 核心价值
- **降低认知门槛**：用户无需学习复杂方法论，输入自然语言即可获得专业框架分析。
- **全链路陪伴**：支持跨轮状态记忆，同一问题可从模糊困惑一路推进到清晰表达。
- **即用即走**：轻量交互，支持紧急模式下的假设思考快速输出。

### 1.5 技术架构
- **前端**：iOS 原生（Objective-C，ARC），构建于 FusionFramework
- **后端**：Coze 工作流（经 AFNetworking HTTPS API 调用）
- **状态存储**：本地 SQLite（FMDB）+ 内存缓存
- **Deployment Target**：iOS 12.0（与现有 Podfile 一致）

---

## 2. 功能需求

### 2.1 功能模块结构

```
首页（ChatPage 对话主界面）
├── 输入区
│   ├── 文本输入框
│   ├── 语音转文字按钮（SFSpeechRecognizer）
│   ├── 快捷入口标签（4 个）
│   └── 模式开关（普通/紧急）
├── 对话展示区
│   ├── 用户气泡
│   ├── 助手气泡（Down → Markdown 渲染）
│   └── 上下文卡片（当前问题摘要 + 已完成阶段）
├── 历史记录页（HistoryPage）
│   ├── 会话列表
│   ├── 会话详情
│   └── 删除/重命名
└── 设置页（SettingsPage）
    ├── 输出详细程度（简洁/标准/完整）
    ├── 默认紧急模式开关
    └── 清除本地缓存
```

### 2.2 详细功能描述

每条功能需求标注其在 FusionFramework 中的**实现载体**（Page / Service / Actor），以确保实现落到框架既定模式。

#### FR-1：文本对话输入
- **描述**：用户在主界面通过文本输入问题或需求。
- **实现载体**：`ChatPage`（`FusionPageController` 子类）组装 `FusionNativeMessage`，经 `[[FusionCore getInstance] asyncSendMessage:]` 投递至 `CozeService`。
- **前置条件**：App 已启动，网络正常。
- **操作流程**：
  1. 用户点击底部输入框，弹出键盘。
  2. 输入文本（支持多行）。
  3. 点击发送按钮，触发调用 Coze 工作流。
- **异常处理**：
  - 网络不可用时（`AFNetworkReachabilityManager` 检测），提示"网络连接失败，请检查网络"。
  - 输入为空时，发送按钮置灰并提示"请输入内容"。
- **验收标准**：用户可正常输入并发送任意文本。

#### FR-2：语音输入（按住说话）
- **描述**：仿微信「按住说话」交互——点击麦克风进入语音模式，长按按钮录音，松手将识别文字直接发送，上滑可取消。
- **实现载体**：`ChatPage` 内集成 `STSpeechRecognizer`（封装 `SFSpeechRecognizer` + `AVAudioEngine`，`zh-CN`）+ `STVoiceHUD` 录音浮层。
- **操作流程**：
  1. 点击输入框右侧麦克风图标（🎙️→🔴），文本输入框替换为「按住 说话」按钮。
  2. 长按按钮：首次请求语音/麦克风权限，授权后开始流式识别，弹出录音 HUD（实时显示识别文本）。
  3. 按住上滑到「取消区」（按钮顶部以上）：HUD 变红提示"松开手指，取消"。
  4. 松手：正常区→将识别文本作为消息直接发送（复用文本发送流程）；取消区→中断，丢弃本次。
  5. 再次点击 🔴 退出语音模式，切回文本输入。
- **异常处理**：权限被拒/设备不支持→提示去设置；识别结果为空→提示"没听清，请重试"，不发送。
- **验收标准**：标准普通话识别准确率不低于 90%；按住说话、上滑取消、松手发送交互符合预期。

#### FR-3：快捷入口标签
- **描述**：提供四个快捷标签，一键填充示例文本并自动发送。
- **实现载体**：`ChatPage` 输入区固定标签。
- **标签内容**：
  - `🔍 发现问题` → 填充"我遇到了一个困扰，但说不清楚问题出在哪里……"
  - `📊 分析原因` → 填充"请帮我分析这个现象背后的原因……"
  - `🚀 制定方案` → 填充"针对这个问题，帮我制定解决方案……"
  - `🎤 组织汇报` → 填充"帮我把以下内容组织成汇报稿……"
- **交互**：点击标签后，自动将对应文本填入输入框并触发发送（需用户确认弹窗）。
- **验收标准**：四个标签均可正确填充并发送。

#### FR-4：紧急模式开关
- **描述**：用户可手动开启"紧急模式"，告知后端使用假设思考优先策略。
- **实现载体**：`ChatPage` 输入框上方 Toggle 开关，标签"⏱️ 紧急模式"。
- **默认值**：关闭（可被设置页"默认紧急模式"覆盖）。
- **联动逻辑**：开启后，组装消息时 `args` 携带 `is_urgent=true`，由 `CozeWorkflowActor` 透传给 Coze API。
- **验收标准**：开关状态可切换，且 API 请求参数正确。

#### FR-5：对话展示与 Markdown 渲染
- **描述**：用户消息以气泡显示在右侧，助手回复以气泡显示在左侧，支持 Markdown 渲染（标题、列表、粗体、代码块、表格）。
- **实现载体**：`ChatPage` 内 `UITableView`/`UICollectionView` 消息列表；助手气泡使用 **Down** 将 Markdown 转 `NSAttributedString` 渲染（Swift 库，混编调用）。
- **滚动逻辑**：每次新消息插入后，自动滚动到底部。
- **验收标准**：
  - 助手回复中的 Markdown 语法正确渲染。
  - 长对话滚动流畅，无卡顿（≥55fps）。

#### FR-6：状态上下文卡片
- **描述**：在助手回复上方显示当前问题摘要及已完成系统思维阶段（进度条或标签列表）。
- **实现载体**：`ChatPage` 顶部卡片视图；数据来自 `CozeWorkflowActor` 回调中解析的 `CONTEXT` JSON（`problem_summary`、`completed_stages`）。
- **UI 样式**：浅灰色圆角卡片，内部显示：
  - 问题摘要："当前问题：团队效率低"
  - 阶段进度："已完成：🔍发现问题 → 📊分析原因"
- **交互**：点击卡片可展开详情（显示完整 context JSON）。
- **验收标准**：每次助手回复后，卡片内容与返回的 context 同步更新。

#### FR-7：多轮会话管理
- **描述**：App 本地维护当前"活动会话"状态（会话 ID、问题摘要、已完成阶段、上轮输出摘要）；下次发送自动带上 `session_context`，实现跨轮衔接。
- **实现载体**：`Session` 模型 + `StorageService`（见 §5）持久化；`ChatPage` 在组装消息前读取活动会话的 `lastContextJson` 注入 `args`。
- **逻辑**：
  - **新会话**：首次发送生成新 `sessionId`，`session_context` 传 `"None"`。
  - **后续发送**：携带最新 `session_context`（取上轮响应的 `new_context` 字段）。
  - 用户可手动"新会话"清空状态。
- **验收标准**：多轮对话中，助手能记住前文的问题摘要和已完成阶段，递进式输出。

#### FR-8：历史记录
- **描述**：用户可查看所有历史会话，点击进入会话详情（完整对话记录）。
- **实现载体**：`HistoryPage`（`FusionPageController` 子类），数据经 `StorageService` 从 SQLite 读取。
- **列表页**：显示会话标题、最后更新时间、最后一条消息预览。
- **操作**：长按会话可删除或重命名标题。
- **数据存储**：FMDB（SQLite）存储会话元数据及消息记录。
- **验收标准**：历史记录正确保存、读取、删除。

#### FR-9：输出详细程度设置
- **描述**：用户可在设置页选择助手输出的详细程度。
- **实现载体**：`SettingsPage`；选项持久化（`NSUserDefaults`），组装消息时注入 `output_level`。
- **选项**：
  - 简洁（`brief`）：只输出核心结论和建议。
  - 标准（`standard`）：输出完整框架 + 代入分析（默认）。
  - 完整（`full`）：在标准基础上增加书中原理解释。
- **验收标准**：切换后，下次调用的输出内容符合对应层级。

#### FR-10：假设思考主动引导（可选）
- **描述**：普通模式下用户连续 2 次输入信息不足时，弹窗提示"检测到信息有限，是否开启紧急模式使用假设思考？"。
- **实现载体**：`ChatPage` 本地计数逻辑（统计当前会话"用户输入<15 字"且助手返回过"信息不足"引导 ≥2 次）。
- **验收标准**：弹窗出现并引导用户开启紧急模式。

#### FR-11：内容分享与导出
- **描述**：用户可长按助手回复，选择"分享"或"导出为 Markdown"。
- **实现载体**：`ChatPage` 长按菜单；分享走系统 `UIActivityViewController`，导出用 `FileKit`/`FileHelper` 写 `.md` 文件到文件 App。
- **验收标准**：分享和导出功能正常。

---

## 3. 系统架构设计

### 3.1 模块归属

新增 `SystemThinker` 业务层（可作为独立模块或在 `TestApp` 基础上演进），依赖关系：

```
SystemThinker (业务层: ChatPage / HistoryPage / SettingsPage / CozeService / StorageService)
  ├── FusionUI      (页面框架: FusionPageController / FusionPageNavigator)
  ├── FusionCore    (Actor 消息系统: FusionCore / FusionService / FusionActor)
  ├── Utility       (FileKit / FileHelper / Lua)
  └── FusionBase    (JSON 工具 / 基础消息)
  + AFNetworking (HTTP)  + FMDB (SQLite)  + Down (Markdown)
```

### 3.2 Coze 调用：CozeService / CozeWorkflowActor

遵循框架 Actor 模式封装 Coze 调用，**线程类型 `FusionService_NET`**。HTTP 底层采用 **AFNetworking**（`AFHTTPSessionManager`），而非框架自带的 NeoNetEngine。

**Service 定义**（Objective-C）：

```objc
// CozeService.m
@implementation CozeService
- (id)initWithConfig:(NSDictionary *)config {
    self = [super initWithConfig:config];
    if (self) {
        _threadType = FusionService_NET;  // 路由到专用网络线程
    }
    return self;
}
@end
```

**Actor 处理流程**（Objective-C）：

```objc
// CozeWorkflowActor.m — 使用 AFNetworking
- (id)initWithConfig:(NSDictionary *)config {
    self = [super initWithConfig:config];
    if (self) {
        _sessionManager = [AFHTTPSessionManager manager];
        _sessionManager.requestSerializer = [AFJSONRequestSerializer serializer];
        _sessionManager.requestSerializer.timeoutInterval = 60;  // 超时 60s
        // responseSerializer 用 AFHTTPResponseSerializer 取回 NSData，
        // 再用 FusionBase 原生 -jsonObject 解析（服务端 Content-Type 不一定规范）
        [_sessionManager.requestSerializer setValue:[NSString stringWithFormat:@"Bearer %@", kCozeAuthToken]
                                 forHTTPHeaderField:@"Authorization"];
        [_sessionManager.requestSerializer setValue:@"application/json"
                                 forHTTPHeaderField:@"Content-Type"];
    }
    return self;
}

- (void)processFusionNativeMessage:(FusionNativeMessage *)message {
    NSDictionary *args = [message args];
    // 1. 组装 Coze 请求体（扁平结构，无 workflow_id/parameters 包裹）
    NSDictionary *body = @{
        @"user_input":      args[@"user_input"]      ?: @"",
        @"session_context": args[@"session_context"] ?: @"None",  // 首次传 "None"
        @"output_level":    args[@"output_level"]    ?: @"standard",
        @"is_urgent":       args[@"is_urgent"]        ?: @(NO)
    };
    // 2. AFNetworking 发起 HTTPS POST
    [_sessionManager POST:@"https://57pqs4yq6k.coze.site/run"
               parameters:body headers:nil progress:nil
                  success:^(NSURLSessionDataTask *t, id responseObject) {
        // 解析 responseObject(NSData) -> [respText jsonObject]
        // analysis_result -> 展示气泡（Markdown 原文）
        // new_context     -> 下一轮 session_context（独立字段）
        // [message setValue:analysis   ToDataTableWith:@"analysis_result"];
        // [message setValue:newContext ToDataTableWith:@"new_context"];
        // [message setState:FusionNativeMessageFinish];
    }
                  failure:^(NSURLSessionDataTask *t, NSError *error) {
        // 据 HTTP 状态码(401/429/5xx) 给友好提示
        // [message setState:FusionNativeMessageFailed];
    }];
}
```

**Lua 服务定义**（`SystemThinker/Script/Service/CozeService.lua`）：

```lua
local service = FusionService.new("cozeService", "CozeService")
service:addActor(FusionActor.new("workflow", "CozeWorkflowActor"))
register_core_service(service)
```

执行 `cd Workspace && lua MacroMaker.lua` 后，生成 `TRIPServiceMacro.h` 中的 `COZESERVICE_SERVICE` / `WORKFLOW_ACTOR` 常量，调用方式：

```objc
#import "TRIPServiceMacro.h"
FusionNativeMessage *msg = [[FusionNativeMessage alloc]
    initWithSerivice:COZESERVICE_SERVICE
               actor:WORKFLOW_ACTOR
                args:@{@"user_input": text,
                       @"session_context": ctxOrNull,
                       @"output_level": level,
                       @"is_urgent": @(isUrgent)}];
[[FusionCore getInstance] asyncSendMessage:msg];  // 回调在发起线程触发
```

### 3.3 页面定义与导航

三个页面均为 `FusionPageController` 子类，经 Lua 注册、MacroMaker 生成 `TRIPPageMacro.h`，由业务 Adapter（参考 `TestApp/TestApp/TestAdapter.m`）实例化。

**Lua 页面定义**（`SystemThinker/Script/Page/*.lua`）：

```lua
register_page(Page.new("ChatPage",     "STChatPageController",     "chat"))
register_page(Page.new("HistoryPage",  "STHistoryPageController",  "history"))
register_page(Page.new("SettingsPage", "STSettingsPageController", "settings"))
```

**导航**（参考 `FusionPageMessage` + `FusionPageNavigator`）：

```objc
FusionPageMessage *msg = [[FusionPageMessage alloc]
    initWithPageName:@"HistoryPage" pageNick:nil
             command:@"init" args:@{} callback:nil];
[[self getNavigator] gotoPage:msg];
```

### 3.4 消息流时序（一次发送）

```
用户在 ChatPage 输入并点击发送
  → ChatPage 读取活动会话 lastContextJson，组装 FusionNativeMessage(args)
  → [[FusionCore getInstance] asyncSendMessage:msg]
  → FusionCore 按 FusionService_NET 路由到网络线程
  → CozeWorkflowActor.processFusionNativeMessage:
      → AFHTTPSessionManager POST 发起 HTTPS 请求（JSON body，超时 60s）
      → success / failure block 回调
      → 解析 analysis_result（展示文本）+ new_context（下一轮上下文）
      → setValue:ToDataTableWith: 写回 analysis_result / new_context
      → setState:FusionNativeMessageFinish
  → 回调在 ChatPage 发起线程触发
      → StorageService 持久化本轮 user / assistant 消息与 context
      → Down 渲染 assistant Markdown 气泡，刷新上下文卡片，滚动到底部
```

---

## 4. 数据持久化设计（SQLite + FMDB）

### 4.1 封装位置

`StorageService`（封装 FMDB 的 DAO 层）。数据库文件路径复用框架能力 `[FileHelper getDatabasePath]`（`Utility/Utility/File/FileHelper.m`）。可选：将增删改查也封装为 `FusionService_Default` 线程的 Actor，与框架消息模式统一；轻量场景下直接由页面调用 DAO 单例亦可。

### 4.2 数据模型

```objc
@interface Session : NSObject
@property (nonatomic, strong) NSString *sessionId;      // UUID
@property (nonatomic, strong) NSString *title;          // 用户可改，默认取问题摘要前 20 字
@property (nonatomic, strong) NSString *problemSummary; // 从 context 更新
@property (nonatomic, strong) NSArray  *completedStages; // 已完成阶段
@property (nonatomic, strong) NSString *lastContextJson; // 原始 context 字符串
@property (nonatomic, strong) NSDate   *lastUpdateTime;
@end
```

### 4.3 数据库表

**表 1：session**

| 字段 | 类型 | 说明 |
|------|------|------|
| session_id | TEXT PRIMARY KEY | UUID |
| title | TEXT | 用户自定义标题，默认问题摘要前 20 字 |
| problem_summary | TEXT | 从 context 解析 |
| completed_stages | TEXT | JSON 数组字符串 |
| last_context | TEXT | 原始 context JSON |
| last_update_time | INTEGER | 时间戳 |
| is_active | INTEGER | 1 为当前活动会话 |

**表 2：message**

| 字段 | 类型 | 说明 |
|------|------|------|
| message_id | TEXT PRIMARY KEY | UUID |
| session_id | TEXT | 外键 |
| role | TEXT | 'user' 或 'assistant' |
| content | TEXT | 消息内容（Markdown 原文） |
| timestamp | INTEGER | 时间戳 |
| context_snapshot | TEXT | 助手消息对应的 context（仅 role=assistant 时存储） |

> JSON 数组/字符串与对象互转统一用 FusionBase 的 `-jsonString` / `-jsonObject`，不引入 MJExtension。

---

## 5. Coze 接口规范

### 5.1 请求

`POST https://57pqs4yq6k.coze.site/run`（已联调通过；**超时 60s**）

**Headers**

```
Authorization: Bearer {your_api_token}
Content-Type: application/json
```

**Body（JSON，扁平结构）**

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `user_input` | string | 是 | 用户当前输入的文本 |
| `session_context` | string | 否 | 上次返回的 `new_context` 字符串；**首次调用传 `"None"`** |
| `output_level` | string | 否 | 输出详细程度：`brief` / `standard` / `full` |
| `is_urgent` | boolean | 否 | 是否紧急模式 |

```json
{
  "user_input": "我的团队项目经常延期，想分析一下原因",
  "session_context": "None",
  "output_level": "standard",
  "is_urgent": false
}
```

### 5.2 响应

返回为**扁平 JSON**（无 `code/msg/data` 包裹），含两个字段：

| 字段 | 类型 | 说明 |
|------|------|------|
| `analysis_result` | string | 助手回复正文（Markdown 原文），直接交 Down 渲染 |
| `new_context` | string | 机读上下文 JSON 字符串，原样存入会话，作为**下一轮** `session_context` |

```json
{
  "analysis_result": "## 📌 维度判定\n当前处理：【分析问题】 ...\n## 💡 结论与建议\n...",
  "new_context": "{\"completed_stages\": [\"分析问题\"], \"problem_summary\": \"团队项目经常延期，需分析原因\", \"last_stage_output\": \"...\", \"last_dimension\": \"分析问题\"}"
}
```

> **上下文衔接**：`new_context` 是独立字段（**不再从 Markdown 中抽取 `CONTEXT:` 行**）。客户端将其原样持久化到会话的 `last_context`，下次发送时作为 `session_context` 透传；其内部 JSON 含 `completed_stages` / `problem_summary` / `last_stage_output` / `last_dimension`，用于驱动上下文卡片（FR-6）。

### 5.3 错误处理

| 场景 | 判定方式 | App 处理 |
|------|----------|----------|
| 网络超时 / 断网 | AFNetworking `failure` block | 提示"网络连接失败，请检查网络"，Actor 置 `FusionNativeMessageFailed` |
| HTTP 非 2xx | `failure` block 中读 `NSHTTPURLResponse.statusCode` | 401→提示联系管理员；429→提示稍后再试；5xx→提示服务暂时不可用 |
| 响应体缺 `analysis_result` | 解析阶段判空 | 提示"返回内容异常，请重试"，置 `FusionNativeMessageFailed` |

---

## 6. 第三方依赖与 Podfile

### 6.1 依赖清单

| 库 | 用途 | 状态 |
|----|------|------|
| FusionBase / Utility / FusionCore / FusionUI / CoreService / Enviroment | 框架本体（path-based 本地 pod） | 已有 |
| FMDB ~> 2.7 | SQLite 封装（框架缺口） | 已在 Podfile |
| Down ~> 0.11 | Markdown 渲染（框架缺口，Swift 库） | 已在 Podfile |
| AFNetworking ~> 4.0 | Coze HTTPS 调用（`AFHTTPSessionManager`） | 已在 Podfile |
| LookinServer | 调试期 UI 调试（仅 Debug） | 已在 Podfile |

### 6.2 现有 Podfile 关键配置

```ruby
platform :ios, '12.0'
use_frameworks!            # Down 为 Swift 库，混编必需
# post_install: SWIFT_VERSION = '5.0', IPHONEOS_DEPLOYMENT_TARGET = '12.0'
```

### 6.3 注意事项

- **Swift/OC 混编**：Down 为 Swift 库，`use_frameworks!` 与 `SWIFT_VERSION 5.0` 已配置；OC 侧通过生成的 `-Swift.h` 桥接头调用，或封装一层 OC 渲染工具类隔离 Swift 依赖。
- **网络层**：Coze 调用统一走 **AFNetworking**（`AFHTTPSessionManager`）。框架自带的 `NeoNetEngine` 不用于本业务；JSON 序列化仍复用 FusionBase 原生 `-jsonString` / `-jsonObject`。
- **新增 Pod 后**：执行 `pod install`，并在改动 Lua 服务/页面后执行 `cd Workspace && lua MacroMaker.lua` 重新生成宏。

---

## 7. UI/UX 设计要点

### 7.1 主界面布局

```
┌─────────────────────────────┐
│  ←  SystemThinker      设置  │  <- 导航栏
├─────────────────────────────┤
│  当前问题：团队效率低         │  <- 上下文卡片
│  已完成：🔍 → 📊            │
├─────────────────────────────┤
│  用户: 最近项目总是延期...    │
│  助手: ## 维度判定...        │
│       (Down Markdown 渲染)   │
├─────────────────────────────┤
│  [🔍] [📊] [🚀] [🎤]        │  <- 快捷标签
│  [⏱️ 紧急模式]  OFF          │
│  [            ] [🎙️] [发送]  │
└─────────────────────────────┘
```

### 7.2 交互细节

- **键盘管理**：点击空白收起键盘；发送后自动收起。
- **加载状态**：发送后显示加载指示器，屏蔽重复发送。
- **长按操作**：长按助手消息弹出菜单（复制、分享、导出）。
- **新会话**：导航栏右侧"+"按钮，清空上下文卡片，开始全新会话。
- **黑暗模式**：支持 iOS 黑暗模式（使用 Color Asset）。

### 7.3 图标与文案

- **应用图标**：简洁"大脑 + 框架"抽象图标。
- **启动页**：白色背景 + 产品名 + "系统思维，框架思考"标语。
- **空状态**：无历史会话时显示"暂无对话，点击 + 开始新思考"。

---

## 8. 非功能需求

### 8.1 性能

- 冷启动时间 ≤ 2 秒
- 网络请求超时：60 秒（`AFJSONRequestSerializer.timeoutInterval`，Coze 工作流响应较慢）
- Markdown 渲染滚动帧率 ≥ 55fps
- 会话列表数据库查询 ≤ 50ms
- 连续对话 50 轮内存无泄漏，滚动流畅

### 8.2 安全与隐私

- 用户输入文本仅用于调用 Coze 服务，不做额外上传。
- 本地数据库不存储任何用户身份信息。
- 语音输入明确请求麦克风权限，并提供"不允许"选项。
- Coze API Token 不硬编码在仓库明文，经 `Enviroment` 配置或安全存储注入。

---

## 9. 测试要点

| 测试类别 | 测试项 | 预期结果 |
|----------|--------|----------|
| 功能 | 文本输入发送 | 正常发送，收到回复 |
| 功能 | 语音转文字 | 识别准确，可发送 |
| 功能 | 快捷标签 | 填充并发送预设文本 |
| 功能 | 紧急模式开关 | API 参数 is_urgent 正确 |
| 功能 | 多轮对话 | 助手记住上下文，递进输出 |
| 功能 | 历史记录保存与恢复 | 正确存储和加载 |
| 功能 | 输出详细程度切换 | 输出内容层级变化 |
| 框架 | Actor 消息状态机 | Finish/Failed 状态正确流转，回调在发起线程 |
| 框架 | CONTEXT 跨轮透传 | 下一轮 session_context 与上轮 CONTEXT 行一致 |
| 异常 | 无网络发送 | AFNetworkReachabilityManager 提示网络错误，不崩溃 |
| 异常 | 服务器返回 500 | 显示友好错误提示 |
| 异常 | 长文本输入（>2000 字） | 正常发送，不截断 |
| UI | 黑暗模式切换 | 界面颜色自动适配 |
| 性能 | 连续对话 50 轮 | 内存无泄漏，滚动流畅 |

---

## 10. 交付物清单

- 源代码（Objective-C 工程，含 SystemThinker 业务层 + Lua 脚本）
- Podfile 及依赖版本说明
- 导出的 .ipa 文件（用于测试）
- API 接口文档（本需求文档已包含）
- 用户操作手册（一页 PDF）

---

## 11. 附录：Coze 工作流配置要求（已联调通过）

App 依赖的 Coze 工作流接口契约（实测）：

**输入参数（扁平 JSON）**

- `user_input`（string，必填）
- `session_context`（string，首次为 `"None"`，后续为上轮 `new_context`）
- `output_level`（string，brief/standard/full）
- `is_urgent`（boolean）

**输出字段（扁平 JSON）**

- `analysis_result`（string）：助手回复正文，Markdown 原文。
- `new_context`（string）：上下文 JSON 字符串，含 `completed_stages`、`problem_summary`、`last_stage_output`、`last_dimension`。

> 接口已联调通过，本附录为前后端对齐记录，详见 §5。
