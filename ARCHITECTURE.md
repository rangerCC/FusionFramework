# FusionFramework 架构设计文档

> **版本**: 1.0  
> **日期**: 2026/05/31  
> **作者**: Claude Code  

---

## 目录

1. [框架概述](#1-框架概述)
2. [架构设计原则](#2-架构设计原则)
3. [核心架构 - Actor模型](#3-核心架构---actor模型)
4. [模块详解](#4-模块详解)
5. [关键技术点](#5-关键技术点)
6. [使用指南](#6-使用指南)
7. [最佳实践](#7-最佳实践)
8. [性能优化](#8-性能优化)

---

## 1. 框架概述

### 1.1 设计理念

FusionFramework 是一个基于 **Actor模型** 的模块化iOS应用框架，采用**消息驱动**的架构设计，支持**Lua配置化**的代码生成。它将复杂的应用逻辑抽象为服务（Service）和演员（Actor）的层次结构，实现高内聚、低耦合的组件化开发。

### 1.2 核心特性

| 特性 | 说明 |
|------|------|
| **Actor模型** | 基于消息传递的并发模型，避免共享状态 |
| **多线程架构** | 自动管理WorkerThread、NetworkThread、CoreThread、MainThread |
| **状态机消息** | 消息自带状态机（Origin → Finish/Failed） |
| **Lua代码生成** | 通过Lua配置自动生成Objective-C宏和服务注册代码 |
| **ARC兼容** | SafeARC.h 提供ARC和非ARC环境的兼容宏 |
| **网络引擎** | 基于libcurl的多socket事件驱动网络层 |
| **页面导航** | 支持自定义动画的页面导航系统 |

### 1.3 技术栈

```
├── Objective-C (主要开发语言)
├── Lua 5.1 (配置和代码生成)
├── libcurl (网络请求)
├── c-ares (异步DNS解析)
├── OpenSSL (可选，HTTPS支持)
└── SQLite (可选，本地缓存)
```

---

## 2. 架构设计原则

### 2.1 分层架构

```
┌─────────────────────────────────────────────────────────┐
│                      UI Layer                           │
│         (FusionUI - 页面、导航、动画、交互)                │
├─────────────────────────────────────────────────────────┤
│                   Service Layer                         │
│      (CoreService - 网络、存储、定位、分享等)              │
├─────────────────────────────────────────────────────────┤
│                    Core Layer                           │
│    (FusionCore - Actor调度、消息路由、线程管理)           │
├─────────────────────────────────────────────────────────┤
│                   Base Layer                            │
│       (FusionBase - 基础类、工具、分类扩展)                │
├─────────────────────────────────────────────────────────┤
│                  Utility Layer                          │
│         (Utility - 加密、文件、JSON、Lua)                 │
├─────────────────────────────────────────────────────────┤
│               Environment Layer                         │
│        (Enviroment - 环境配置、用户偏好)                 │
└─────────────────────────────────────────────────────────┘
```

### 2.2 依赖关系

```
FusionBase → (FusionCore, Utility, Enviroment)
                 ↓
    (FusionUI, CoreService)
                 ↓
            TestApp
```

---

## 3. 核心架构 - Actor模型

### 3.1 Actor模型概述

FusionFramework 实现了经典的Actor模型：

- **Actor**: 处理消息的基本单元
- **Message**: 不可变的消息对象，包含指令和数据
- **Mailbox**: 隐式的消息队列（框架内部管理）
- **Isolation**: 每个Actor独立处理消息，不共享状态

### 3.2 核心类层次

```
FusionMessage (基类)
    └── FusionNativeMessage (原生消息)

FusionFilter (过滤器基类)
    ├── FusionAndFilter (与组合)
    ├── FusionOrFilter (或组合)
    └── FusionNotFilter (非组合)

FusionService (服务容器)
    └── [自定义Service]

FusionActor (消息处理器)
    └── [自定义Actor]

FusionCore (单例调度器)
```

### 3.3 消息生命周期状态机

```
                    ┌─────────────┐
                    │   Origin    │  ← 初始状态 (0)
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

**状态常量定义** ([FusionNativeMessage.h:16-19](FusionCore/FusionCore/FusionNativeMessage.h)):

```objc
#define FusionNativeMessageOrigin 0       // 初始状态
#define FusionNativeMessageFinish 1       // 完成状态
#define FusionNativeMessageFailed 2       // 失败状态
#define FusionNativeMessageMaxNum 99999   // 最大状态值
```

### 3.4 线程模型

FusionCore 维护4种专用线程：

| 线程类型 | 用途 | Actor分配 |
|---------|------|----------|
| **CoreThread** | 核心调度、Service管理 | 系统级Service |
| **NetworkThread** | 网络请求处理 | `FusionService_NET` 类型的Service |
| **WorkerThreads** | 通用业务逻辑 | `FusionService_Default` 类型的Service |
| **MainThread** | UI更新 | `FusionService_UI` 类型的Service |

**线程数量计算**:
```objc
WorkerThreads = CPU核心数 × 2
```

**Service线程类型** ([FusionService.h:14-19](FusionCore/FusionCore/FusionService.h)):

```objc
typedef enum {
    FusionService_Default   = 0,  // WorkerThread池
    FusionService_NET       = 1,  // NetworkThread
    FusionService_UI        = 2,  // MainThread
} FusionServiceThreadType;
```

### 3.5 消息路由格式

消息采用URL风格的字符串格式：

```
native://{service_name}/{actor_name}?command={cmd}&param1=value1
```

**示例**:
```
native://NetworkService/HttpGetActor?command=fetchUser&userId=123
native://PageNavigator/PageActor?command=push&page=ProfilePage
```

---

## 4. 模块详解

### 4.1 FusionCore - 核心引擎

#### 4.1.1 职责

- 单例消息调度中心
- Service懒加载管理
- 线程池管理
- 消息状态机维护
- 子消息生命周期管理

#### 4.1.2 核心API

```objc
// 获取单例
+ (FusionCore *)getInstance;

// 同步/异步发送消息
- (void)syncSendMessage:(FusionNativeMessage *)message;
- (void)asyncSendMessage:(FusionNativeMessage *)message;

// 延迟发送
- (void)asyncSendMessage:(FusionNativeMessage *)message 
              withDelay:(NSTimeInterval)delay;

// 批量发送
- (void)syncBatchMessages:(NSArray *)messages;
- (void)asyncBatchMessages:(NSArray *)messages;
```

#### 4.1.3 消息处理流程

```
[Sender] → asyncSendMessage() → [MessagePool] → [CoreThread] 
                                              ↓
[Service] ← 路由分发 ← [Thread Selector] ← [Dispatcher]
   ↓
[Filter] → filterFusionNativeMessage()
   ↓ (通过)
[Actor] → processFusionNativeMessage()
   ↓
[State Update] → Finish/Failed
   ↓
[Callback] → processCallbackMessage() (如果有父消息)
```

### 4.2 FusionService - 服务容器

#### 4.2.1 职责

- Actor的容器和管理者
- 消息预处理（Filter）
- 线程类型定义
- 并发执行控制

#### 4.2.2 生命周期方法

```objc
// 初始化
- (id)initWithConfig:(NSDictionary *)config;

// 消息过滤（在Actor之前执行）
- (BOOL)filterFusionNativeMessage:(FusionNativeMessage *)message;

// 消息处理（通常转发给Actor）
- (void)processFusionNativeMessage:(FusionNativeMessage *)message;

// 回调处理
- (void)processCallbackFusionNativeMessage:(FusionNativeMessage *)message;

// 取消处理
- (void)processCancelFusionNativeMessage:(FusionNativeMessage *)message;

// 并发控制
- (BOOL)canConcurrentExecute:(FusionNativeMessage*)message;
```

### 4.3 FusionActor - 消息处理器

#### 4.3.1 职责

- 具体业务逻辑的实现者
- 消息的细粒度过滤
- 子消息的发起和管理

#### 4.3.2 核心方法

```objc
// 消息过滤
- (BOOL)filterFusionNativeMessage:(FusionNativeMessage *)message;

// 消息处理（子类必须实现）
- (void)processFusionNativeMessage:(FusionNativeMessage *)message;

// 回调处理（子消息完成时调用）
- (void)processCallbackMessage:(FusionNativeMessage *)message 
                 ParentMessage:(FusionNativeMessage *)parent;

// 取消处理
- (void)cancelFusionNativeMessage:(FusionNativeMessage *)message;
```

### 4.4 FusionNativeMessage - 消息对象

#### 4.4.1 核心属性

```objc
@property(readonly, atomic) NSString *service;     // 目标服务名
@property(readonly, atomic) NSString *actor;       // 目标Actor名
@property(assign, nonatomic) NSUInteger state;     // 当前状态
@property(retain, atomic) NSThread *originThread;  // 发送线程
@property(retain, atomic) NSString *workerNick;    // 工作线程标识
@property(retain, atomic) NSLock *locker;         // 线程安全锁
```

#### 4.4.2 数据传递

```objc
// 数据表操作
- (id)getValueFromDataTableWith:(NSString*)key;
- (void)setValue:(id)value ToDataTableWith:(NSString*)key;
- (void)importToDataTable:(NSDictionary*)params;

// 子消息管理
- (void)insertSubMessage:(FusionNativeMessage *)message;
- (void)removeSubMessage:(FusionNativeMessage *)message;
- (NSArray *)getChildren;
```

#### 4.4.3 父子消息机制

当消息A触发消息B时：
1. B的parent指向A
2. A的children包含B
3. 当所有children完成（Finish或Failed），A自动完成
4. 每个child完成时调用A所在Actor的 `processCallbackMessage`

### 4.5 FusionUI - 页面导航

#### 4.5.1 FusionPageNavigator

中央导航控制器，管理页面栈。

**核心协议** ([FusionPageNavigator.h:17-62](FusionUI/FusionUI/Navigation/FusionPageNavigator.h)):

```objc
// 页面协议
@protocol IFusionPageProtocol <NSObject>
- (id)initWithConfig:(NSDictionary *)pageConfig;
- (NSDictionary *)getPageConfig;
- (void)processPageCommand:(NSString *)command args:(NSDictionary *)args;
// ... 生命周期回调
@end

// 适配器协议
@protocol IFusionPageAdapterProtocol <NSObject>
- (UIViewController<IFusionPageProtocol> *)generateFusionPageController:(NSDictionary *)pageConfig;
- (NSDictionary *)getPageConfig:(NSString *)pageName;
- (FusionTabBar *)generateFusionTabbar:(NSString *)tabbarName;
@end
```

#### 4.5.2 页面配置格式

```objc
@{
    @"pageName": @"ProfilePage",
    @"class": @"ProfileViewController",
    @"title": @"个人资料",
    @"tabbar_name": @"MainTabBar",
    @"singleton": @YES,        // 是否单例
    @"navi_anime": @"slide",   // 导航动画类型
    @"track_name": @"profile"   // 埋点名称
}
```

#### 4.5.3 导航动画

支持多种预设动画 ([FusionUI/FusionUI/Navigation/Anime/](FusionUI/FusionUI/Navigation/Anime/)):

| 类名 | 动画效果 |
|-----|---------|
| FusionSlideL2RAnime | 从左滑入 |
| FusionSlideR2LAnime | 从右滑入 |
| FusionSlideT2BAnime | 从上滑入 |
| FusionSlideB2TAnime | 从下滑入 |
| FusionScrollL2RAnime | 滚动从左 |
| FusionScrollR2LAnime | 滚动从右 |
| FusionNavi2DAnime | 2D转场效果 |

### 4.6 CoreService - 网络引擎

#### 4.6.1 NeoNetEngine 架构

基于libcurl的多socket事件驱动架构：

```
┌─────────────────────────────────────────┐
│           NeoNetEngine                  │
│  ┌─────────────────────────────────┐  │
│  │      CURLM (multi handle)         │  │
│  │  ┌─────────┐ ┌─────────┐         │  │
│  │  │CURL* #1 │ │CURL* #2 │  ...    │  │
│  │  └────┬────┘ └────┬────┘         │  │
│  │       └────────────┘               │  │
│  │            ↓ socket                │  │
│  │       ┌─────────┐                  │  │
│  │       │socket_fd│                  │  │
│  │       └────┬────┘                  │  │
│  │            ↓ event                 │  │
│  │       DNSSocketContext             │  │
│  └─────────────────────────────────┘  │
│            ↓ _updateTimer (每50ms)      │
│       curl_multi_perform()              │
│            ↓ callback                   │
│       NeoNetTask (onComplete)           │
└─────────────────────────────────────────┘
```

#### 4.6.2 任务类型

```objc
// 基础任务
NeoNetTask (抽象基类)
    ├── NeoHttpTask (HTTP GET/通用请求)
    │       └── NeoHttpPostTask (POST表单)
    │       └── NeoHttpFormTask (Multipart表单)
    └── NeoHttpDownloadTask (文件下载)
```

#### 4.6.3 配置选项

```objc
@{
    @"dns_service": @"8.8.8.8",      // DNS服务器
    @"dns_cache_time": @600,         // DNS缓存时间(秒)
    @"timeout": @30,                  // 请求超时
    @"connect_timeout": @10,           // 连接超时
    @"enable_ssl_verify": @YES       // SSL证书验证
}
```

---

## 5. 关键技术点

### 5.1 SafeARC - 兼容性宏

[Workspace/CommonHeader/SafeARC.h](Workspace/CommonHeader/SafeARC.h) 提供ARC/非ARC兼容：

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

### 5.2 Lua代码生成系统

#### 5.2.1 配置流程

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│   *.lua      │────▶│ MacroMaker   │────▶│   *.h宏      │
│   配置       │     │   脚本       │     │   定义       │
└──────────────┘     └──────────────┘     └──────────────┘
                            │
                            ▼
                     ┌──────────────┐
                     │ Script.bundle│
                     │   Lua脚本    │
                     └──────────────┘
                            │
                            ▼
                     ┌──────────────┐
                     │  config.zip  │
                     │   (发布用)    │
                     └──────────────┘
```

#### 5.2.2 Service配置示例

```lua
-- Script/Service/NetworkService.lua
local service = FusionService.new("NetworkService", "TRIPNetworkService")

service:addActor(FusionActor.new("HttpGet", "HttpGetActor"))
service:addActor(FusionActor.new("HttpPost", "HttpPostActor"))
service:addActor(FusionActor.new("Download", "DownloadActor"))

-- 添加过滤器（可选）
service:addFilter(FusionFilter.new("NetworkFilter"))

register_logic_service(service)
```

#### 5.2.3 Page配置示例

```lua
-- Script/Page/MainPages.lua
local page = Page.new("HomePage", "HomeViewController", "home_track")
page:addCommand("refresh")
page:addCommand("loadMore")
register_page(page)

-- H5页面
local h5page = Page.newH5Host("WebPage", {
    test = "https://test.example.com",
    prepare = "https://pre.example.com",
    release = "https://www.example.com"
}, "web_track")
register_page(h5page)
```

#### 5.2.4 生成的宏

运行 `lua Workspace/MacroMaker.lua` 后生成：

```objc
// TRIPServiceMacro.h
#define NETWORKSERVICE_SERVICE @"NetworkService"
#define HTTPGET_ACTOR @"HttpGet"
#define HTTPPOST_ACTOR @"HttpPost"
#define DOWNLOAD_ACTOR @"Download"

// TRIPPageMacro.h
#define HOMEPAGE_PAGE @"HomePage"
#define WEBPAGE_PAGE @"WebPage"
```

### 5.3 Filter组合模式

支持Filter的逻辑组合 ([FusionCore/FusionCore/Filter/](FusionCore/FusionCore/Filter/)):

```objc
// 单个Filter
FusionFilter *filter = [[FusionFilter alloc] initWithConfig:@{@"type": @"network"}];

// AND组合（全部通过才算通过）
FusionAndFilter *andFilter = [[FusionAndFilter alloc] initWithConfig:nil];
[andFilter addFilter:filter1];
[andFilter addFilter:filter2];

// OR组合（任一通过即通过）
FusionOrFilter *orFilter = [[FusionOrFilter alloc] initWithConfig:nil];
[orFilter addFilter:filter1];
[orFilter addFilter:filter2];

// NOT组合（取反）
FusionNotFilter *notFilter = [[FusionNotFilter alloc] initWithFilter:filter];

// 应用到Service
FusionService *service = [[FusionService alloc] initWithConfig:nil];
service.filter = andFilter;
```

### 5.4 消息池优化

FusionCore使用消息池复用消息对象，避免频繁创建/销毁：

```objc
// FusionMessagePool 管理消息对象
@interface FusionMessagePool : NSObject
+ (FusionMessagePool *)getInstance;
- (FusionNativeMessage *)dequeueMessage;
- (void)enqueueMessage:(FusionNativeMessage *)message;
@end
```

---

## 6. 使用指南

### 6.1 快速开始

#### 步骤1: 创建工作空间

```bash
cd Workspace
open FusionWorkspace.xcworkspace
```

#### 步骤2: 创建自定义Service和Actor

**MyService.h**
```objc
#import <FusionCore/FusionService.h>

@interface MyService : FusionService
@end
```

**MyService.m**
```objc
#import "MyService.h"
#import "MyActor.h"

@implementation MyService

- (id)initWithConfig:(NSDictionary *)config {
    self = [super initWithConfig:config];
    if (self) {
        _name = @"MyService";
        _threadType = FusionService_Default; // WorkerThread
        
        // 注册Actor
        _actorDic = [[NSMutableDictionary alloc] init];
        [_actorDic setValue:[[MyActor alloc] initWithConfig:nil]
                     forKey:@"MyActor"];
    }
    return self;
}

@end
```

**MyActor.h**
```objc
#import <FusionCore/FusionActor.h>

@interface MyActor : FusionActor
@end
```

**MyActor.m**
```objc
#import "MyActor.h"

@implementation MyActor

- (id)initWithConfig:(NSDictionary *)config {
    self = [super initWithConfig:config];
    if (self) {
        _name = @"MyActor";
    }
    return self;
}

- (void)processFusionNativeMessage:(FusionNativeMessage *)message {
    // 获取参数
    NSDictionary *args = [message args];
    NSString *command = [args valueForKey:@"command"];
    
    if ([command isEqualToString:@"doSomething"]) {
        // 执行业务逻辑
        id result = [self doSomething];
        
        // 设置结果到数据表
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
    // 处理子消息回调
    id subResult = [message getValueFromDataTableWith:@"result"];
    [parent setValue:subResult ToDataTableWith:@"subResult"];
    
    // 父消息自动完成（当所有子消息完成时）
}

- (void)cancelFusionNativeMessage:(FusionNativeMessage *)message {
    // 清理资源
}

@end
```

#### 步骤3: 配置Lua

**YourModule/Script/Service/MyService.lua**
```lua
local service = FusionService.new("MyService", "MyService")
service:addActor(FusionActor.new("MyActor", "MyActor"))
register_logic_service(service)
```

#### 步骤4: 生成宏

```bash
cd Workspace
lua MacroMaker.lua
```

#### 步骤5: 发送消息

```objc
#import <FusionCore/FusionCore.h>
#import "TRIPServiceMacro.h"

// 创建消息
FusionNativeMessage *msg = [[FusionNativeMessage alloc]
    initWithSerivice:MYSERVICE_SERVICE
               actor:MYACTOR_ACTOR
                args:@{
                    @"command": @"doSomething",
                    @"param1": @"value1"
                }];

// 异步发送
[[FusionCore getInstance] asyncSendMessage:msg];
```

### 6.2 页面导航使用

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
    // 设置UI
}

- (void)processPageCommand:(NSString *)command args:(NSDictionary *)args {
    if ([command isEqualToString:@"init"]) {
        // 页面初始化
    } else if ([command isEqualToString:@"refresh"]) {
        // 刷新数据
    }
}

// 动画回调
- (void)enterAnimeStart { /* 进入动画开始 */ }
- (void)enterAnimeFinish { /* 进入动画完成 */ }
- (void)exitAnimeStart { /* 退出动画开始 */ }
- (void)exitAnimeFinish { /* 退出动画完成 */ }

@end
```

#### 页面跳转

```objc
#import <FusionUI/FusionPageNavigator.h>

// 获取导航器
FusionPageNavigator *navigator = /* 获取方式 */;

// 构建页面消息
FusionPageMessage *pageMsg = [[FusionPageMessage alloc] init];
[pageMsg setTargetPageName:MYPAGE_PAGE];
[pageMsg setArgs:@{@"userId": @"123"}];

// 发送导航消息
[[FusionCore getInstance] asyncSendMessage:pageMsg];
```

### 6.3 网络请求使用

```objc
#import <CoreService/NeoNetEngine.h>
#import <CoreService/NeoHttpTask.h>

// 创建任务
NeoHttpTask *task = [[NeoHttpTask alloc] init];
[task setRequestUrl:@"https://api.example.com/data"];
[task setHeaderDic:@{@"Authorization": @"Bearer token"}];
[task setTimeout:30.0];

// 设置回调
[task setOnComplete:^(NeoNetTask *task, id result) {
    NSData *responseData = result;
    // 处理响应
}];

[task setOnFailed:^(NeoNetTask *task, NSError *error) {
    // 处理错误
}];

// 启动任务
[[NeoNetEngine getInstance] startTask:task];
```

### 6.4 带依赖的复杂消息

```objc
// 父消息
FusionNativeMessage *parentMsg = [[FusionNativeMessage alloc]
    initWithSerivice:DATASERVICE_SERVICE
               actor:AGGREGATE_ACTOR
                args:@{@"type": @"aggregate"}];

// 子消息1
FusionNativeMessage *child1 = [[FusionNativeMessage alloc]
    initWithSerivice:DATASERVICE_SERVICE
               actor:FETCHUSER_ACTOR
                args:@{@"userId": @"123"}];
[child1 insertSubMessage:parentMsg]; // 设置父子关系

// 子消息2
FusionNativeMessage *child2 = [[FusionNativeMessage alloc]
    initWithSerivice:DATASERVICE_SERVICE
               actor:FETCHORDER_ACTOR
                args:@{@"userId": @"123"}];
[child2 insertSubMessage:parentMsg];

// 发送子消息
[[FusionCore getInstance] asyncSendMessage:child1];
[[FusionCore getInstance] asyncSendMessage:child2];

// 当child1和child2都完成后，parentMsg自动完成
// 并调用AGGREGATE_ACTOR的processCallbackMessage
```

---

## 7. 最佳实践

### 7.1 Service设计原则

1. **单一职责**：每个Service只负责一个功能领域
2. **线程安全**：Service的方法会被多线程调用，注意加锁
3. **懒加载**：Service在第一次收到消息时才初始化
4. **优雅降级**：网络Service在离线时提供缓存数据

### 7.2 Actor设计原则

1. **无状态**：Actor不保存业务状态，状态放在Message中
2. **幂等性**：相同的消息多次处理结果一致
3. **快速返回**：process方法尽快返回，耗时操作异步执行
4. **异常处理**：所有异常捕获并设置Failed状态

### 7.3 消息设计原则

1. **不可变性**：消息创建后不应修改args
2. **小数据**：dataTable只传递必要数据，大数据用key传递
3. **及时完成**：消息处理完成后立即设置状态
4. **取消支持**：实现cancel方法清理资源

### 7.4 目录结构规范

```
YourModule/
├── Script/
│   ├── Service/           # Service配置
│   │   └── YourService.lua
│   ├── Page/               # Page配置
│   │   └── YourPages.lua
│   └── Logic/              # 业务逻辑Lua
├── Source/
│   ├── Service/            # Service实现
│   ├── Actor/              # Actor实现
│   └── Model/              # 数据模型
├── Resource.bundle/        # 资源文件
└── YourModule.xcodeproj
```

---

## 8. 性能优化

### 8.1 消息池复用

框架自动使用消息池，开发者无需干预。注意在Actor中及时清理引用。

### 8.2 线程调优

```objc
// Service选择合适的线程类型
// IO密集型 → FusionService_Default (WorkerThreads)
// 网络请求 → FusionService_NET (NetworkThread)
// UI更新 → FusionService_UI (MainThread)
```

### 8.3 批量消息处理

```objc
// 批量发送减少线程切换
NSArray *messages = @[msg1, msg2, msg3, msg4];
[[FusionCore getInstance] asyncBatchMessages:messages];
```

### 8.4 内存管理

1. 使用SafeARC宏避免内存泄漏
2. 在dealloc中清理资源
3. 大对象使用弱引用

---

## 附录

### A. 术语表

| 术语 | 说明 |
|-----|------|
| Actor | 消息处理器，封装了行为和数据 |
| Service | Actor的容器，管理线程和生命周期 |
| Message | 携带指令和数据的消息对象 |
| Filter | 消息过滤器，决定是否处理 |
| Navigator | 页面导航管理器 |
| Adapter | 页面配置适配器 |

### B. 参考资料

- [Actor Model](https://en.wikipedia.org/wiki/Actor_model)
- [libcurl Documentation](https://curl.se/libcurl/c/)
- [Lua 5.1 Reference Manual](https://www.lua.org/manual/5.1/)

---

*文档结束*
