# FusionFramework 架构设计文档

> **版本**：1.1
> **日期**：2026/11/23
> **作者**：Claude Code

---

## 目录

1. [框架概述](#1-框架概述)
2. [架构设计原则](#2-架构设计原则)
3. [核心架构：Actor 模型](#3-核心架构actor-模型)
4. [模块详解](#4-模块详解)
5. [关键技术点](#5-关键技术点)
6. [使用指南](#6-使用指南)
7. [最佳实践](#7-最佳实践)
8. [性能优化](#8-性能优化)

---

## 1. 框架概述

### 1.1 设计理念

FusionFramework 是一个基于 **Actor 模型**的模块化 iOS 应用框架。它采用**消息驱动**架构，并支持通过 **Lua 配置**生成代码。框架将应用逻辑抽象为服务（Service）与 Actor 两级结构，各组件之间只通过消息通信，从而实现高内聚、低耦合的组件化开发。

### 1.2 核心特性

| 特性 | 说明 |
|------|------|
| **Actor 模型** | 基于消息传递的并发模型，组件之间不直接调用 |
| **多线程调度** | 框架统一管理 CoreThread、NetworkThread、WorkerThread 与 MainThread |
| **消息状态机** | 每条消息自带状态（Origin → Finish / Failed / 自定义状态） |
| **父子消息** | 父消息可派生多个并行子消息，并在子消息完成时收到回调 |
| **Lua 代码生成** | 根据 Lua 配置生成 Objective-C 名称宏及服务注册配置 |
| **ARC 兼容** | `SafeARC.h` 提供同时兼容 ARC 与非 ARC 的内存管理宏 |
| **网络层** | 基于 AFNetworking 的网络 Actor，经由消息系统调用 |
| **页面导航** | 支持自定义转场动画的页面导航系统 |

### 1.3 技术栈

```
├── Objective-C（主要开发语言）
├── CocoaPods（模块与第三方依赖管理）
├── Lua 5.1（配置与代码生成）
├── AFNetworking 4.x（HTTP 请求与文件下载，基于 NSURLSession）
├── OpenSSL（Utility 模块内置 libcrypto.a / libssl.a，用于加密）
└── SQLite / zlib（系统库，由 Utility 模块链接）
```

---

## 2. 架构设计原则

### 2.1 分层架构

```
┌─────────────────────────────────────────────────────────┐
│                       UI 层                             │
│          (FusionUI - 页面、导航、转场动画、交互)          │
├─────────────────────────────────────────────────────────┤
│                     服务层                              │
│            (CoreService - 网络请求、文件下载)             │
├─────────────────────────────────────────────────────────┤
│                     核心层                              │
│       (FusionCore - Actor 调度、消息路由、线程管理)       │
├─────────────────────────────────────────────────────────┤
│                     工具层                              │
│           (Utility - 加密、文件、Zip、Lua)               │
├─────────────────────────────────────────────────────────┤
│                     环境层                              │
│            (Enviroment - 环境配置、用户偏好)              │
├─────────────────────────────────────────────────────────┤
│                     基础层                              │
│        (FusionBase - 消息基类、工具类、分类扩展)          │
└─────────────────────────────────────────────────────────┘
```

### 2.2 依赖关系

每个模块都是仓库根目录下的一个本地 Pod（`*.podspec`）。箭头表示"被依赖"：

```
FusionBase
  ├──→ Enviroment
  │       └──→ Utility ──→ FusionCore ──→ CoreService ←── AFNetworking
  └──→ FusionUI
                         （TestApp 依赖以上全部模块）
```

| 模块 | 直接依赖 |
|------|---------|
| FusionBase | 无 |
| Enviroment | FusionBase |
| Utility | FusionBase、Enviroment |
| FusionCore | FusionBase、Utility |
| FusionUI | FusionBase |
| CoreService | FusionCore、FusionBase、Utility、AFNetworking |

---

## 3. 核心架构：Actor 模型

### 3.1 Actor 模型概述

FusionFramework 实现了经典 Actor 模型的主要概念：

- **Actor**：处理消息的基本单元
- **Message**：携带目标、参数与结果的消息对象
- **Mailbox**：由框架内部的消息池（`FusionMessagePool`）隐式维护，开发者无需直接操作
- **隔离性**：组件之间不直接调用，只通过消息交换数据

与严格的 Actor 模型不同，每个 Actor 在其 Service 内**只有一个实例**，首次收到消息时创建，之后的消息都复用它（参见 [7.2](#72-actor-设计原则)）。

### 3.2 核心类层次

```
FusionMessage（基类，位于 FusionBase）
    └── FusionNativeMessage（Service / Actor 消息）

FusionFilter（过滤器基类）
    ├── FusionAndFilter（与组合）
    ├── FusionOrFilter（或组合）
    └── FusionNotFilter（取反）

FusionService（服务容器）
    └── [自定义 Service]

FusionActor（消息处理器）
    └── [自定义 Actor]

FusionCore（单例调度器）
FusionMessagePool（工作线程的待调度队列）
FusionTimerService / FusionTimerTask（定时任务）
```

### 3.3 消息生命周期状态机

```
                    ┌─────────────┐
                    │   Origin    │  ← 初始状态
                    │    (0)      │
                    └──────┬──────┘
                           │
              ┌────────────┼────────────┐
              ▼            ▼            ▼
        ┌─────────┐  ┌─────────┐  ┌─────────┐
        │  Finish │  │ Failed  │  │ Custom  │
        │   (1)   │  │   (2)   │  │  (3+)   │
        └─────────┘  └─────────┘  └─────────┘
           成功          失败        自定义状态
```

**状态常量定义**（[FusionNativeMessage.h:16-19](FusionCore/FusionCore/FusionNativeMessage.h#L16-L19)）：

```objc
#define FusionNativeMessageOrigin 0       // 初始状态
#define FusionNativeMessageFinish 1       // 完成状态
#define FusionNativeMessageFailed 2       // 失败状态
#define FusionNativeMessageMaxNum 99999   // 状态值上限
```

当状态被设置为 Finish 或 Failed 时，`setState:` 会自动执行以下操作：

1. 取消该消息尚未完成的全部子消息
2. 若该消息没有父消息，则在发起线程上发送 `FusionNativeMessageNotification` 通知（`object` 为消息本身）
3. 若该消息有父消息，则将完成事件派发给父消息所在的 Actor（参见 [4.4.3](#443-父子消息机制)）

### 3.4 线程模型

FusionCore 维护以下线程：

| 线程 | 用途 | 执行的 Service |
|------|------|---------------|
| **CoreThread** | 消息路由、Service 懒加载、延迟消息触发、工作线程调度 | 不执行业务 Service |
| **NetworkThread** | 网络请求处理 | `FusionService_NET` 类型 |
| **WorkerThreads** | 通用业务逻辑 | `FusionService_Default` 类型 |
| **MainThread** | UI 更新 | `FusionService_UI` 类型 |

**工作线程数量**（[FusionCoreEx.m:18](FusionCore/FusionCore/FusionCoreEx.m#L18)）：
```objc
WorkerThreads = sysconf(_SC_NPROCESSORS_CONF) × 2
```

**Service 线程类型**（[FusionService.h:14-19](FusionCore/FusionCore/FusionService.h#L14-L19)）：

```objc
typedef enum {
    FusionService_Default   = 0,  // 工作线程池
    FusionService_NET       = 1,  // NetworkThread
    FusionService_UI        = 2,  // MainThread
} FusionServiceThreadType;
```

线程类型由 Service 配置字典中的 `thread_type` 键决定，`FusionService initWithConfig:` 会读取该键，缺省为 `FusionService_Default`。子类无需、也不应直接为 `_threadType` 赋值。

**工作线程调度规则**：

- 空闲的工作线程从消息池中取任务，优先级依次为：取消 > 子消息回调 > 普通消息
- 普通消息按 `service::actor` 分组排队，各组轮流出队，避免单个 Actor 占满线程池
- 消息首次被调度时会记录 `workerNick`；其后续的回调与取消操作会派发到同一条工作线程
- 若 `canConcurrentExecute:` 返回 `NO`，该消息在本轮调度中被跳过，等待下一轮

### 3.5 消息寻址格式

`FusionNativeMessage` 以 URL 形式描述目标：scheme 为 `native`，host 为 Service 名称，path 为 Actor 名称：

```
native://{service_name}/{actor_name}?param1=value1
```

**示例**：
```
native://netService/netNormal?remote_url=https%3A%2F%2Fapi.example.com
```

日常开发中一般通过 `initWithSerivice:actor:args:` 构造消息，无需手动拼接 URL。

---

## 4. 模块详解

### 4.1 FusionCore：核心引擎

#### 4.1.1 职责

- 作为单例的消息调度中心
- 创建并管理 Service（核心 Service 在启动时创建，逻辑 Service 在首次收到消息时懒加载）
- 管理工作线程池
- 处理延迟消息、取消消息与子消息回调

#### 4.1.2 核心 API

```objc
// 获取单例
+ (FusionCore *)getInstance;

// 启动时必须调用，传入实现 IFusionConfig 协议的配置提供者
- (void)prepareWithConfig:(id<IFusionConfig>)config;

// 异步发送（单条 / 批量）
- (void)asyncSendMessage:(FusionNativeMessage *)message;
- (void)asyncSendMessageArray:(NSArray *)messageArray;

// 异步取消（单条 / 批量）
- (void)asyncCancelMessage:(FusionNativeMessage *)message;
- (void)asyncCancelMessageArray:(NSArray *)messageArray;

// 获取网络线程（供网络 Actor 将回调切回该线程）
- (NSThread *)getNetworkThread;
```

框架不提供同步发送接口。需要延迟发送时，先设置消息的 `delay` 属性（单位为秒），再调用 `asyncSendMessage:`。

**配置协议**（[FusionCoreEx.h:11-18](FusionCore/FusionCore/FusionCoreEx.h#L11-L18)）：

```objc
@protocol IFusionConfig<NSObject>
@required
- (NSString *)appScheme;
- (NSArray *)getCoreService;                                  // 启动时创建的核心 Service 配置
- (NSDictionary *)getLogicServiceByName:(NSString *)serviceName; // 按需加载的逻辑 Service 配置
@optional
- (NSArray *)getTimeTaskArray;                                // 定时任务配置
@end
```

#### 4.1.3 消息处理流程

```
[发送方] → asyncSendMessage()（记录 originThread）
   ↓
[CoreThread] → 查找 / 懒加载 Service 与 Actor（找不到则丢弃）
   ↓
 delay ≠ 0 ? → 放入延迟队列，到期后重新进入路由
   ↓
 按 threadType 路由：
   NET → NetworkThread      UI → MainThread      Default → 消息池 → 空闲工作线程
   ↓
[Service] processFusionNativeMessage:
   ↓
[Actor Filter] → 未通过则直接置为 Failed
   ↓ 通过
[Actor] processFusionNativeMessage: → setState: Finish / Failed
   ↓
 无父消息 → 在 originThread 上发送 FusionNativeMessageNotification
 有父消息 → 父消息所在 Actor 的 processCallbackMessage:ParentMessage:
```

### 4.2 FusionService：服务容器

#### 4.2.1 职责

- 持有并懒加载 Actor（依据配置中的 `actors` 字典）
- 将消息转发给对应 Actor，并在转发前执行 Actor 过滤器
- 通过配置确定线程类型
- 通过 `canConcurrentExecute:` 控制并发执行

#### 4.2.2 生命周期方法

```objc
// 初始化（读取 thread_type、actors、filter 等配置）
- (id)initWithConfig:(NSDictionary *)config;

// 消息过滤
- (BOOL)filterFusionNativeMessage:(FusionNativeMessage *)message;

// 消息处理（默认转发给 Actor）
- (void)processFusionNativeMessage:(FusionNativeMessage *)message;

// 子消息回调处理
- (void)processCallbackFusionNativeMessage:(FusionNativeMessage *)message;

// 取消处理
- (void)processCancelFusionNativeMessage:(FusionNativeMessage *)message;

// 并发控制（默认返回 YES）
- (BOOL)canConcurrentExecute:(FusionNativeMessage*)message;
```

**Service 配置字典**（框架运行时读取的格式）：

```objc
@{
    @"name":        @"myService",
    @"class":       @"FusionService",        // 或其子类
    @"thread_type": @(0),                    // 0=Default 1=NET 2=UI
    @"actors": @{
        @"myActor": @{ @"class": @"MyActor" }
    }
}
```

仅当需要定制容器行为（例如重写 `canConcurrentExecute:` 以串行化某类消息）时，才需要子类化 `FusionService`。

### 4.3 FusionActor：消息处理器

#### 4.3.1 职责

- 实现具体业务逻辑
- 对消息做细粒度过滤
- 派发并管理子消息

#### 4.3.2 核心方法

```objc
// 消息过滤（默认读取配置中的 filter；未配置时返回 YES）
- (BOOL)filterFusionNativeMessage:(FusionNativeMessage *)message;

// 消息处理（子类必须重写）
- (void)processFusionNativeMessage:(FusionNativeMessage *)message;

// 子消息完成回调（默认实现：子消息全部完成后将父消息置为 Finish）
- (void)processCallbackMessage:(FusionNativeMessage *)message
                 ParentMessage:(FusionNativeMessage *)parent;

// 取消处理（默认实现：取消并清空子消息）
- (void)cancelFusionNativeMessage:(FusionNativeMessage *)message;
```

### 4.4 FusionNativeMessage：消息对象

#### 4.4.1 核心属性

```objc
@property(readonly, atomic) NSString *service;              // 目标 Service 名称
@property(readonly, atomic) NSString *actor;                // 目标 Actor 名称
@property(assign, nonatomic) NSUInteger state;              // 当前状态
@property(readwrite, atomic) NSTimeInterval delay;          // 延迟发送时长（秒）
@property(retain, atomic) NSThread *originThread;           // 发送线程（异步发送时有效）
@property(retain, atomic) NSString *workerNick;             // 分配到的工作线程标识
@property(readonly, atomic) FusionNativeMessage *parent;    // 父消息
```

#### 4.4.2 数据传递

```objc
// 输入参数（创建时传入）
- (NSDictionary *)args;

// 结果数据表（线程安全）
- (id)getDataTable;
- (id)getValueFromDataTableWith:(NSString*)key;
- (void)setValue:(id)value ToDataTableWith:(NSString*)key;
- (void)removeValueFromDataTableWith:(NSString*)key;
- (void)importToDataTable:(NSDictionary*)params;
- (void)clearDataTable;

// 子消息管理
- (void)insertSubMessage:(FusionNativeMessage *)message;
- (void)removeSubMessage:(FusionNativeMessage *)message;
- (void)clearSubMessage;
- (NSArray *)getChildren;
- (NSInteger)getChildrenCount;
```

#### 4.4.3 父子消息机制

在消息 A 上调用 `[A insertSubMessage:B]` 后：

1. B 的 `parent` 指向 A，A 的子消息列表中包含 B
2. B 进入 Finish 或 Failed 状态时，框架先将 B 从 A 的子消息列表中移除，再调用 A 所在 Actor 的 `processCallbackMessage:B ParentMessage:A`
3. 该回调的默认实现会在 A 已无剩余子消息时将 A 置为 Finish。若子类重写了此方法，需调用 `[super ...]` 或自行设置 A 的状态，否则 A 不会完成
4. 若 A 提前进入 Finish 或 Failed 状态，其尚未完成的子消息会被自动取消
5. 子消息完成时不会发送 `FusionNativeMessageNotification`，该通知只针对顶层消息

### 4.5 FusionUI：页面导航

#### 4.5.1 FusionPageNavigator

中央导航控制器，负责管理页面栈。

**核心协议**（[FusionPageNavigator.h:17-76](FusionUI/FusionUI/Navigation/FusionPageNavigator.h#L17-L76)，以下为节选）：

```objc
// 页面协议
@protocol IFusionPageProtocol<NSObject>
@required
- (id)initWithConfig:(NSDictionary *)pageConfig;
- (NSDictionary *)getPageConfig;
- (void)processPageCommand:(NSString *)command args:(NSDictionary *)args;
- (void)setNavigator:(FusionPageNavigator *)navigator;
- (FusionPageNavigator *)getNavigator;
- (void)setTabBar:(FusionTabBar *)tabBar;
// ... 另有 pageName / pageNick / callbackUrl / naviAnimeType 的存取方法
@optional
// 转场动画回调、快照视图、遮罩视图、updateSubviewsLayout、页面上下文保存与恢复
@end

// 适配器协议
@protocol IFusionPageAdapterProtocol<NSObject>
@required
- (UIViewController<IFusionPageProtocol> *)generateFusionPageController:(NSDictionary *)pageConfig;
- (NSDictionary *)getPageConfig:(NSString *)pageName;
- (FusionTabBar *)generateFusionTabbar:(NSString *)tabbarName;
@end
```

`FusionPageController` 是实现了 `IFusionPageProtocol` 的页面基类，自定义页面通常继承它即可。

#### 4.5.2 页面配置格式

```objc
@{
    @"pageName": @"ProfilePage",
    @"class": @"ProfileViewController",
    @"title": @"个人资料",
    @"tabbar_name": @"MainTabBar",
    @"singleton": @YES,        // 是否复用同一实例
    @"navi_anime": @"slide",   // 导航动画类型
    @"track_name": @"profile"  // 埋点名称
}
```

#### 4.5.3 导航动画

框架内置多种转场动画（[FusionUI/FusionUI/Navigation/Anime/](FusionUI/FusionUI/Navigation/Anime/)）：

| 类名 | 动画效果 |
|-----|---------|
| FusionSlideL2RAnime | 从左侧滑入 |
| FusionSlideR2LAnime | 从右侧滑入 |
| FusionSlideT2BAnime | 从顶部滑入 |
| FusionSlideB2TAnime | 从底部滑入 |
| FusionScrollL2RAnime | 自左向右滚动 |
| FusionScrollR2LAnime | 自右向左滚动 |
| FusionNavi2DAnime | 2D 转场效果 |

### 4.6 CoreService：网络层

#### 4.6.1 架构

CoreService 不再包含自研网络引擎，原有的 NeoNetEngine（libcurl + c-ares）已被移除。网络能力由两个基于 AFNetworking 的 FusionActor 提供，调用方通过消息系统发送请求，不直接调用 Actor：

```
[调用方] → FusionNativeMessage(netService / netNormal 或 download)
   ↓ asyncSendMessage
[FusionCore] → threadType = FusionService_NET → NetworkThread
   ↓
[NetNormalActor / DownloadFileActor] → 发起 AFNetworking 任务
   ↓ 完成回调（AFNetworking 默认在主队列触发）
 切回 NetworkThread → 写入 dataTable → setState: Finish / Failed
   ↓
[调用方] 在发起线程上收到 FusionNativeMessageNotification
```

由于 AFNetworking 的完成回调运行在主队列上，两个 Actor 都会先将回调切回 Fusion 网络线程（`[[FusionCore getInstance] getNetworkThread]`），再修改 Actor 内部状态并调用 `setState:`，以保证 Actor 状态只在单一线程上被访问。

#### 4.6.2 网络 Actor

源码位于 [CoreService/CoreService/Network/](CoreService/CoreService/Network/)：

| Actor | 说明 |
|-------|------|
| `NetNormalActor` | 通过共享的 `AFHTTPSessionManager` 发起 GET / POST 请求。接受任意状态码与内容类型，响应为原始 `NSData`。通过重定向 block 支持 `HTTP_DISABLE_FOLLOW`（否则 NSURLSession 会自动跟随 301/302）。支持取消。 |
| `DownloadFileActor` | 通过 `AFURLSessionManager` 下载任务下载文件。借助 `DownloadFileCluster` 对同一 URL 的并发请求去重；目标文件已存在且未设置 `NET_FORCE_DOWNLOAD` 时直接返回成功。 |

#### 4.6.3 参数与结果键

定义于 [NetworkCommon.h](CoreService/CoreService/Network/NetworkCommon.h)：

| 类别 | 键 | 说明 |
|------|----|------|
| 输入 | `NET_REMOTE_URL` | 请求地址（必填） |
| 输入 | `NET_HTTP_METHOD` | `HTTP_GET_METHOD`（默认）或 `HTTP_POST_METHOD` |
| 输入 | `NET_HTTP_HEADER` | 请求头字典 |
| 输入 | `NET_HTTP_PARAMS` | 请求参数字典 |
| 输入 | `HTTP_DISABLE_FOLLOW` | 是否禁止跟随重定向（BOOL） |
| 输入（下载） | `NET_LOCAL_PATH` | 文件保存路径 |
| 输入（下载） | `NET_TEMP_PATH` | 临时文件路径（可选） |
| 输入（下载） | `NET_FORCE_DOWNLOAD` | 文件已存在时是否仍重新下载（BOOL） |
| 结果 | `HTTP_RESPONSE_CODE` | HTTP 状态码 |
| 结果 | `HTTP_RESPONSE_HEADER` | 响应头字典 |
| 结果 | `HTTP_RESPONSE_DATA` | 响应体（`NSData`） |
| 结果 | `HTTP_EFFECTIVE_URL` | 发生重定向后的最终地址 |
| 错误 | `MESSAGE_ERROR_DOMAIN` / `MESSAGE_ERROR_CODE` / `MESSAGE_ERROR_MSG` | 由 `FusionNativeMessage (Error)` 分类的 `setErrorDomainCode:errorCode:errorMsg:` 写入 |

---

## 5. 关键技术点

### 5.1 SafeARC：兼容性宏

[FusionBase/FusionBase/CommonHeader/SafeARC.h](FusionBase/FusionBase/CommonHeader/SafeARC.h) 提供同时兼容 ARC 与非 ARC 环境的内存管理宏（各 podspec 通过 `HEADER_SEARCH_PATHS` 引入该目录）：

```objc
#if __has_feature(objc_arc)
    #define SafeRelease(obj) if(obj){obj=nil;}
    #define SafeRetain(obj) obj
    #define SafeAutoRelease(obj) obj
    #define SafeSuperDealloc(obj)
    #define SafeAutoReleasePoolStart @autoreleasepool {
    #define SafeAutoReleasePoolEnd }
#else
    #define SafeRelease(obj) if(obj){[obj release]; obj=nil;}
    #define SafeRetain(obj) [obj retain]
    #define SafeAutoRelease(obj) [obj autorelease]
    #define SafeSuperDealloc(obj) [super dealloc]
    #define SafeAutoReleasePoolStart NSAutoreleasePool *pool = [NSAutoreleasePool new];
    #define SafeAutoReleasePoolEnd [pool release];
#endif
```

### 5.2 Lua 代码生成系统

#### 5.2.1 处理流程

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│   *.lua      │────▶│ MacroMaker   │────▶│   *.h 宏     │
│   配置       │     │   脚本       │     │   定义       │
└──────────────┘     └──────────────┘     └──────────────┘
                            │
                            ▼
                     ┌──────────────┐
                     │ Script.bundle│
                     │  处理后脚本  │
                     └──────────────┘
                            │
                            ▼
                     ┌──────────────┐
                     │  config.zip  │
                     │ (运行时配置) │
                     └──────────────┘
```

`MacroMaker.lua` 扫描所有 `*/Script/Service/*.lua` 与 `*/Script/Page/*.lua`，生成名称宏头文件，并将配置打包进 `config.zip`，供 `IFusionConfig` 的实现者在运行时读取。

#### 5.2.2 Service 配置示例

```lua
-- Script/Service/NetService.lua
local service = FusionService.new("netService", "FusionService")
service.thread_type = 1   -- 0=Default（工作线程池） 1=NET 2=UI（主线程）

service:addActor(FusionActor.new("netNormal", "NetNormalActor"))
service:addActor(FusionActor.new("download", "DownloadFileActor"))

register_core_service(service)   -- 启动时创建；按需加载的 Service 使用 register_logic_service()
```

#### 5.2.3 Page 配置示例

```lua
-- Script/Page/MainPages.lua
local page = Page.new("HomePage", "HomeViewController", "home_track")
page:addCommand("refresh")
page:addCommand("loadMore")
register_page(page)

-- H5 页面（按环境区分地址）
local h5page = Page.newH5Host("WebPage", {
    test = "https://test.example.com",
    prepare = "https://pre.example.com",
    release = "https://www.example.com"
}, "web_track")
register_page(h5page)
```

#### 5.2.4 生成的宏

在 `Workspace` 目录下执行 `lua MacroMaker.lua` 后生成：

```objc
// TRIPServiceMacro.h
#define NETSERVICE_SERVICE @"netService"
#define NETNORMAL_ACTOR @"netNormal"
#define DOWNLOAD_ACTOR @"download"

// TRIPPageMacro.h
#define HOMEPAGE_PAGE @"HomePage"
#define WEBPAGE_PAGE @"WebPage"
```

### 5.3 Filter 组合模式

Filter 通过配置字典声明，并在 Service / Actor 初始化时根据 `class` 键实例化（[FusionCore/FusionCore/Filter/](FusionCore/FusionCore/Filter/)）。组合型 Filter 从配置中读取子 Filter：

| Filter | 子 Filter 配置键 | 判定规则 |
|--------|-----------------|---------|
| `FusionAndFilter` | `filters`（数组） | 全部通过才算通过 |
| `FusionOrFilter` | `filters`（数组） | 任一通过即通过 |
| `FusionNotFilter` | `filter`（字典） | 对子 Filter 结果取反 |

```objc
// 为 Actor 配置组合过滤器：要求已登录，且不处于离线模式
@{
    @"class": @"MyActor",
    @"filter": @{
        @"class": @"FusionAndFilter",
        @"filters": @[
            @{ @"class": @"LoginFilter" },
            @{ @"class": @"FusionNotFilter",
               @"filter": @{ @"class": @"OfflineFilter" } }
        ]
    }
}
```

自定义 Filter 只需继承 `FusionFilter` 并重写 `filterFusionNativeMessage:`，返回 `YES` 表示放行。Actor 过滤器未通过时，消息会被直接置为 Failed。

### 5.4 消息池（调度队列）

`FusionMessagePool` 是工作线程池的待调度队列，**不负责复用消息对象**。它在 CoreThread 上维护三类队列：

- **普通消息**：按 `service::actor` 分组，各组轮流出队
- **回调消息**：按父消息的 `workerNick` 分组，确保回调回到处理父消息的工作线程
- **取消消息**：按消息的 `workerNick` 分组；若消息尚未被调度，则直接从普通队列中移除

只有 `FusionService_Default` 类型的消息会进入消息池；NET 与 UI 类型的消息直接派发到对应线程。

---

## 6. 使用指南

### 6.1 快速开始

#### 步骤 1：安装依赖并打开工作空间

```bash
pod install
open Workspace/FusionWorkspace.xcworkspace
```

#### 步骤 2：创建自定义 Actor

线程类型、Actor 列表等属性均由配置提供，通常无需自定义 Service 子类，直接使用 `FusionService` 即可。

**MyActor.h**
```objc
#import <FusionCore/FusionActor.h>

@interface MyActor : FusionActor
@end
```

**MyActor.m**
```objc
#import "MyActor.h"
#import <FusionCore/FusionCore.h>

@implementation MyActor

- (void)processFusionNativeMessage:(FusionNativeMessage *)message {
    // 读取参数
    NSString *command = [[message args] valueForKey:@"command"];

    if ([command isEqualToString:@"doSomething"]) {
        // 执行业务逻辑
        id result = [self doSomething];

        // 将结果写入数据表
        [message setValue:result ToDataTableWith:@"result"];

        // 标记完成
        [message setState:FusionNativeMessageFinish];
    } else {
        // 标记失败
        [message setState:FusionNativeMessageFailed];
    }
}

- (void)processCallbackMessage:(FusionNativeMessage *)message
                 ParentMessage:(FusionNativeMessage *)parent {
    // 汇总子消息结果
    id subResult = [message getValueFromDataTableWith:@"result"];
    [parent setValue:subResult ToDataTableWith:@"subResult"];

    // 默认实现会在子消息全部完成后将父消息置为 Finish
    [super processCallbackMessage:message ParentMessage:parent];
}

- (void)cancelFusionNativeMessage:(FusionNativeMessage *)message {
    // 释放与该消息相关的资源
    [super cancelFusionNativeMessage:message];
}

@end
```

#### 步骤 3：编写 Lua 配置

**YourModule/Script/Service/MyService.lua**
```lua
local service = FusionService.new("MyService", "FusionService")
service.thread_type = 0   -- 工作线程池
service:addActor(FusionActor.new("MyActor", "MyActor"))
register_logic_service(service)
```

#### 步骤 4：生成宏与配置

```bash
cd Workspace
lua MacroMaker.lua
```

#### 步骤 5：发送消息并接收结果

```objc
#import <FusionCore/FusionCore.h>
#import "TRIPServiceMacro.h"

// 监听完成通知（在发起线程上触发）
[[NSNotificationCenter defaultCenter] addObserver:self
                                         selector:@selector(onMessageFinished:)
                                             name:FusionNativeMessageNotification
                                           object:nil];

// 创建并发送消息
FusionNativeMessage *msg = [[FusionNativeMessage alloc]
    initWithSerivice:MYSERVICE_SERVICE
               actor:MYACTOR_ACTOR
                args:@{
                    @"command": @"doSomething",
                    @"param1": @"value1"
                }];
[[FusionCore getInstance] asyncSendMessage:msg];

// 处理结果
- (void)onMessageFinished:(NSNotification *)notification {
    FusionNativeMessage *message = notification.object;
    if (message.state == FusionNativeMessageFinish) {
        id result = [message getValueFromDataTableWith:@"result"];
    }
}
```

由于该通知面向所有顶层消息广播，请在回调中根据消息对象（或其 service / actor）判断是否为自己发出的消息。

### 6.2 页面导航

#### 创建页面

```objc
// MyPageController.h
#import <FusionUI/FusionPageController.h>

@interface MyPageController : FusionPageController
@end

// MyPageController.m
@implementation MyPageController

- (id)initWithConfig:(NSDictionary *)pageConfig {
    self = [super initWithConfig:pageConfig];
    if (self) {
        // 初始化
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // 搭建 UI
}

- (void)processPageCommand:(NSString *)command args:(NSDictionary *)args {
    if ([command isEqualToString:@"init"]) {
        // 页面初始化
    } else if ([command isEqualToString:@"refresh"]) {
        // 刷新数据
    }
}

// 转场动画回调
- (void)enterAnimeStart { /* 进入动画开始 */ }
- (void)enterAnimeFinish { /* 进入动画完成 */ }
- (void)exitAnimeStart { /* 退出动画开始 */ }
- (void)exitAnimeFinish { /* 退出动画完成 */ }

@end
```

#### 页面跳转

```objc
#import <FusionUI/FusionUI.h>
#import "TRIPPageMacro.h"

FusionPageMessage *pageMsg = [[FusionPageMessage alloc]
    initWithPageName:MYPAGE_PAGE
            pageNick:nil
             command:@"init"
                args:@{@"userId": @"123"}
            callback:nil];
[[self getNavigator] gotoPage:pageMsg];
```

`callback:` 参数的类型是 `NSURL`，而非 block。如需将结果回传给当前页面，可调用 `[FusionPageNavigator generateCallbackUrl:self]` 生成回调 URL，并在其后追加参数与 `#command` 片段；被打开的页面结束时，框架会把该命令投递到发起页面的 `processPageCommand:args:`。

### 6.3 网络请求

网络请求同样通过消息系统发送：

```objc
#import <FusionCore/FusionCore.h>
#import <CoreService/NetworkCommon.h>

FusionNativeMessage *msg = [[FusionNativeMessage alloc]
    initWithSerivice:@"netService"
               actor:@"netNormal"
                args:@{
                    NET_REMOTE_URL:  @"https://api.example.com/data",
                    NET_HTTP_METHOD: HTTP_GET_METHOD,
                    NET_HTTP_HEADER: @{@"Authorization": @"Bearer token"}
                }];
[[FusionCore getInstance] asyncSendMessage:msg];

// 在 FusionNativeMessageNotification 回调中读取结果
- (void)onMessageFinished:(NSNotification *)notification {
    FusionNativeMessage *message = notification.object;
    if (message != msg) return;

    if (message.state == FusionNativeMessageFinish) {
        NSInteger code = [[message getValueFromDataTableWith:HTTP_RESPONSE_CODE] integerValue];
        NSData *body = [message getValueFromDataTableWith:HTTP_RESPONSE_DATA];
        // 处理响应
    } else {
        NSString *errorMsg = [message getValueFromDataTableWith:MESSAGE_ERROR_MSG];
        // 处理错误
    }
}
```

文件下载使用 `DownloadFileActor`，需额外传入 `NET_LOCAL_PATH`。如需取消请求，调用 `[[FusionCore getInstance] asyncCancelMessage:msg]`。

### 6.4 父子消息协同

以下代码在父消息所在 Actor 的 `processFusionNativeMessage:` 中执行：

```objc
- (void)processFusionNativeMessage:(FusionNativeMessage *)parentMsg {
    // 子消息 1
    FusionNativeMessage *child1 = [[FusionNativeMessage alloc]
        initWithSerivice:DATASERVICE_SERVICE
                   actor:FETCHUSER_ACTOR
                    args:@{@"userId": @"123"}];
    [parentMsg insertSubMessage:child1];   // 由父消息挂载子消息

    // 子消息 2
    FusionNativeMessage *child2 = [[FusionNativeMessage alloc]
        initWithSerivice:DATASERVICE_SERVICE
                   actor:FETCHORDER_ACTOR
                    args:@{@"userId": @"123"}];
    [parentMsg insertSubMessage:child2];

    // 批量发送子消息
    [[FusionCore getInstance] asyncSendMessageArray:@[child1, child2]];

    // 此处不设置 parentMsg 的状态。
    // 每个子消息完成时都会回调本 Actor 的 processCallbackMessage:ParentMessage:，
    // 默认实现会在 child1、child2 都完成后将 parentMsg 置为 Finish。
}
```

---

## 7. 最佳实践

### 7.1 Service 设计原则

1. **单一职责**：每个 Service 只负责一个功能领域
2. **配置驱动**：线程类型、Actor 列表和过滤器都写在配置中，避免为此子类化 Service
3. **按需加载**：非启动必需的 Service 使用 `register_logic_service()` 注册，首次收到消息时才创建
4. **并发控制**：需要串行处理的 Service 应重写 `canConcurrentExecute:`，而不是在 Actor 内部加锁阻塞工作线程

### 7.2 Actor 设计原则

1. **避免保存单条请求的状态**：同一 Actor 实例会处理该 Actor 名下的所有消息，`Default` 类型下还可能在多个工作线程上并发执行。单条请求的数据应放在消息的 args 与 dataTable 中；确需保存的实例状态（如网络任务表）必须保证线程安全，或像网络 Actor 那样限定在单一线程上访问
2. **幂等性**：同一消息重复处理时，结果应保持一致
3. **快速返回**：`processFusionNativeMessage:` 应尽快返回，耗时操作改为异步执行，完成后再设置状态
4. **必须收尾**：每条消息最终都要被置为 Finish 或 Failed，否则调用方永远收不到通知

### 7.3 消息设计原则

1. **参数只读**：消息创建后不应修改 args，处理结果统一写入 dataTable
2. **控制数据量**：dataTable 只传递必要数据，大块数据应写入文件或缓存，消息中只传路径或 key
3. **及时完成**：处理完成后立即设置状态
4. **支持取消**：长耗时 Actor 应实现 `cancelFusionNativeMessage:` 以释放资源，并调用 `super` 以取消子消息

### 7.4 目录结构规范

```
YourModule/
├── Script/
│   ├── Service/            # Service 配置
│   │   └── YourService.lua
│   ├── Page/               # 页面配置
│   │   └── YourPages.lua
│   └── Logic/              # 业务逻辑 Lua
├── Source/
│   ├── Service/            # 自定义 Service（如有）
│   ├── Actor/              # Actor 实现
│   └── Model/              # 数据模型
└── Resource.bundle/        # 资源文件

YourModule.podspec          # 位于仓库根目录，由 Podfile 通过 :path => '.' 引用
```

---

## 8. 性能优化

### 8.1 调度开销

所有消息都先经过 CoreThread 路由，再派发到目标线程。对于高频、轻量的操作，应合并为一条消息处理，避免拆分成大量细粒度消息。

### 8.2 选择合适的线程类型

```objc
// 一般业务逻辑、CPU 密集型计算 → FusionService_Default（工作线程池，可并行）
// 网络请求                     → FusionService_NET（单一网络线程）
// UI 更新                      → FusionService_UI（主线程）
```

NetworkThread 与 MainThread 都只有一条线程。在这两类 Service 中执行阻塞操作，会拖慢该线程上的所有其他消息。

### 8.3 批量发送

```objc
// 一次性提交多条消息，减少向 CoreThread 派发的次数
NSArray *messages = @[msg1, msg2, msg3, msg4];
[[FusionCore getInstance] asyncSendMessageArray:messages];
```

### 8.4 延迟消息精度

CoreThread 以 0.5 秒为周期检查延迟队列，因此延迟消息的实际触发时间最多可能比 `delay` 晚约 0.5 秒。对时间精度要求较高的场景，请改用 `FusionTimerService` 或系统定时器。

### 8.5 内存管理

1. 统一使用 SafeARC 宏，保证代码在 ARC 与非 ARC 环境下行为一致
2. 在 `dealloc` 中释放持有的资源
3. 在 block 中引用 `self` 时使用 `__weak` / `__strong` 配对，避免循环引用

---

## 附录

### A. 术语表

| 术语 | 说明 |
|-----|------|
| Actor | 消息处理器，实现具体业务逻辑 |
| Service | Actor 的容器，决定执行线程并管理 Actor 的生命周期 |
| Message | 携带目标、参数与结果的消息对象 |
| Filter | 消息过滤器，决定消息是否进入 Actor 处理 |
| Navigator | 页面导航管理器 |
| Adapter | 根据页面配置创建页面实例的适配器 |

### B. 参考资料

- [Actor Model](https://en.wikipedia.org/wiki/Actor_model)
- [AFNetworking](https://github.com/AFNetworking/AFNetworking)
- [Lua 5.1 Reference Manual](https://www.lua.org/manual/5.1/)

---

*文档结束*
