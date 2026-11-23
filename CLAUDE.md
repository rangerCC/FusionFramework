# CLAUDE.md

本文件为 Claude Code（claude.ai/code）在本仓库中处理代码时提供指引。

## 构建系统

本项目是一个由 **CocoaPods** 管理的模块化 iOS 框架。每个模块都是一个本地 Pod（即仓库根目录下的
`*.podspec`），由 `TestApp` target 通过 `:path => '.'` 引用。

**环境初始化**（克隆仓库后，以及任何 podspec 或 Podfile 发生变更后执行）：
```bash
pod install
```

**工作空间**：在 Xcode 中打开 `Workspace/FusionWorkspace.xcworkspace`。该工作空间仅引用
`TestApp/TestApp.xcodeproj` 与自动生成的 `Pods/Pods.xcodeproj`，各模块由 CocoaPods 依据其
podspec 中的源文件匹配规则（source globs）进行编译。（各模块原有的 `.xcodeproj` 文件仍保留在磁盘上，
但已不再作为构建目标。）

**本地模块 Pod**（根目录 `*.podspec`）：
- `FusionBase`：基础消息与工具层，不依赖其他模块
- `Enviroment`：应用配置；依赖 FusionBase
- `Utility`：加密（Crypto）、文件操作（FileKit）、压缩（Zip）、Lua；内置 `libcrypto.a`/`libssl.a` 静态库，链接 `z`/`sqlite3`；依赖 FusionBase、Enviroment
- `FusionCore`：Actor 模型与消息分发；依赖 FusionBase、Utility
- `FusionUI`：页面导航与 UI；依赖 FusionBase
- `CoreService`：网络 Actor（基于 AFNetworking 实现）；依赖 FusionCore、FusionBase、Utility、AFNetworking

**第三方 Pod**（TestApp target）：SDWebImage、AFNetworking、FMDB、CocoaLumberjack、
MJRefresh、Masonry、IQKeyboardManager。

**最低部署版本**：Podfile 将最低版本固定为 iOS 15.0，并在 `post_install` 中对所有 Pod 强制生效。
`post_install` 钩子还会移除 AFNetworking 4.0.1 中对私有头文件 `<netinet6/in6.h>` 的引用，
因为 Xcode 26.4 及以上版本在 `use_frameworks!` 模式下会拒绝该引用。

**构建 / 运行示例应用**：
```bash
xcodebuild -workspace Workspace/FusionWorkspace.xcworkspace \
           -scheme TestApp \
           -configuration Debug \
           -sdk iphonesimulator \
           -derivedDataPath /tmp/FusionBuild
```

## 架构概览

FusionFramework 是一个**基于 Actor 模型的消息驱动型 iOS 框架**，并配套**基于 Lua 的代码生成**机制。
框架强制采用严格的消息传递架构，并自动完成线程路由。

### 核心消息系统（FusionCore）

**Actor 模型层级**：
```
FusionCore（单例消息分发器）
  └── FusionService（服务容器，管理 Actor）
      └── FusionActor（消息处理单元）
```

**消息流转过程**：
1. 调用方创建 `FusionNativeMessage`，指定 service / actor / command
2. 通过 `asyncSendMessage:` 或 `asyncSendMessageArray:` 发送至 `FusionCore`（框架只提供异步发送）
3. FusionCore 在 CoreThread 上查找或懒加载 Service，并根据其 `threadType` 将消息路由到目标线程
4. Service 懒加载 Actor（首次创建后一直复用），执行 Actor 过滤器后调用 `processFusionNativeMessage:`
5. Actor 处理消息，并通过 `setValue:ToDataTableWith:` 写入结果
6. 消息状态迁移为 `FusionNativeMessageFinish` 或 `FusionNativeMessageFailed`
7. 对于顶层消息（无父消息），框架在发起线程上发送 `FusionNativeMessageNotification` 通知，
   `object` 为消息本身；对于子消息，则回调父消息所在 Actor 的 `processCallbackMessage:ParentMessage:`

**消息状态机**：
```objc
#define FusionNativeMessageOrigin  0   // 创建时的初始状态
#define FusionNativeMessageFinish  1   // 处理成功
#define FusionNativeMessageFailed  2   // 处理出错
#define FusionNativeMessageMaxNum  99999  // 自定义状态从此值开始
```

**消息结构**（FusionNativeMessage.h）：
```objc
@interface FusionNativeMessage : FusionMessage
  @property NSTimeInterval delay;              // 延迟分发时长
  @property NSTimeInterval triggerTime;        // 延迟消息的触发时间
  @property NSString *service;                 // Service 名称（只读）
  @property NSString *actor;                   // Actor 名称（只读）
  @property NSUInteger state;                  // 当前状态
  @property NSThread *originThread;            // 发送消息的线程
  @property NSString *workerNick;              // 分配到的工作线程
  @property FusionNativeMessage *parent;       // 子消息所属的父消息
  @property NSMutableDictionary _dataTable;    // 结果存储

  // 用于并行处理的子消息管理
  - (NSArray *)getChildren;
  - (void)insertSubMessage:(FusionNativeMessage *)message;
  - (void)removeSubMessage:(FusionNativeMessage *)message;
  // 所有子消息完成后，FusionActor 的默认回调实现会将父消息置为 Finish
@end
```

**线程模型**：

FusionCore 维护多条专用线程。Service 的 `threadType` 决定其执行线程；该值读取自配置中的
`thread_type` 键，而非通过子类化设置：

- `FusionService_Default`（0）→ 工作线程池（线程数为 CPU 核数 × 2，由空闲线程从消息池取任务）
- `FusionService_NET`（1）→ 网络线程（专用于 I/O）
- `FusionService_UI`（2）→ 主线程（用于 UIKit 调用）

线程组成：
- CoreThread：常驻运行，负责消息路由、工作线程调度，并以 0.5 秒为周期检查延迟消息
- NetworkThread：常驻运行，负责异步 I/O
- WorkerThreads：CPU 核数 × 2（例如四核设备为 8 条）
- MainThread：UIKit 主线程（隐式存在）

### Service 与 Actor 实现

**FusionService**（FusionCore/FusionCore/FusionService.h）：
- 相关 Actor 的容器
- 根据配置中的 `actors` 字典，在 Actor 首次收到消息时懒加载
- 将消息转发给 Actor，转发前执行 Actor 的过滤器（未通过则直接置为 Failed）
- 通过 `canConcurrentExecute:` 控制并发执行（默认返回 YES；返回 NO 时消息留待下一轮调度）

**FusionActor**（FusionCore/FusionCore/FusionActor.h）：
- 消息处理器的基类
- 每个 Actor 在所属 Service 内只有**一个实例**，处理该 Actor 名下的全部消息；
  `Default` 类型下还可能在多个工作线程上并发执行。单条请求的数据应放在 args 与 dataTable 中，
  确需保存的实例状态必须保证线程安全
- 重写 `processFusionNativeMessage:` 以处理消息；每条消息最终都必须置为 Finish 或 Failed
- 可在配置中通过 `filter` 键声明消息过滤器，用于预处理

**过滤器体系**（FusionCore/FusionCore/Filter/）：
- 可组合的消息校验机制，通过配置字典声明，按 `class` 键实例化
- `FusionFilter`（基类；重写 `filterFusionNativeMessage:`，返回 YES 表示放行）
- `FusionAndFilter`（`filters` 数组中的条件均须满足）
- `FusionOrFilter`（`filters` 数组中满足任一条件即可）
- `FusionNotFilter`（对 `filter` 字典描述的子过滤器取反）

### Lua 代码生成系统

`Workspace/MacroMaker.lua` 脚本根据 Lua 配置生成 Objective-C 宏，从而在编译期校验 service / actor / page 名称。

**工作原理**：
1. 扫描所有 `*/Script/Service/*.lua` 与 `*/Script/Page/*.lua` 文件
2. 执行 Lua 脚本，填充 service / page 注册表
3. 生成两个头文件：
   - `TRIPServiceMacro.h`：Service 与 Actor 名称常量
   - `TRIPPageMacro.h`：页面名称常量
4. 生成包含处理后脚本的 `Script.bundle/` 以及 `config.zip`

**执行代码生成**：
```bash
cd Workspace
lua MacroMaker.lua
# 生成：TRIPServiceMacro.h、TRIPPageMacro.h、Script.bundle/、config.zip
```

**Service 定义**（Script/Service/YourService.lua）：
```lua
local service = FusionService.new("myService", "MyServiceClass")
service:addActor(FusionActor.new("actor1", "MyActor1"))
service:addActor(FusionActor.new("actor2", "MyActor2"))
service:addFilter(SomeFilter.new())  -- 可选的消息过滤器
register_core_service(service)  -- 或 register_logic_service()
```

生成宏的使用方式：
```objc
#import "TRIPServiceMacro.h"

FusionNativeMessage *msg = [[FusionNativeMessage alloc]
    initWithSerivice:MYSERVICE_SERVICE
               actor:ACTOR1_ACTOR
                args:@{@"key": @"value"}];
[[FusionCore getInstance] asyncSendMessage:msg];
```

**页面定义**（Script/Page/YourPage.lua）：
```lua
local page = Page.new("PageName", "ViewControllerClass", "TrackingName")
page:addCommand("customCommand")
register_page(page)
```

**特殊页面类型**：
- H5 宿主页面：`Page.newH5Host("name", urls_dict, "trackName")`
  - `urls` 表包含 `test`、`prepare`、`release` 三个键，分别对应不同环境

### 消息通信模式

**发送消息**：
```objc
// 使用 service / actor / args 创建消息
FusionNativeMessage *msg = [[FusionNativeMessage alloc]
    initWithSerivice:@"serviceName"
               actor:@"actorName"
                args:@{@"key": @"value"}];

// 异步发送（框架不提供同步发送接口）
[[FusionCore getInstance] asyncSendMessage:msg];

// 批量发送
[[FusionCore getInstance] asyncSendMessageArray:@[msg1, msg2]];

// 延迟发送（实际触发可能比 delay 晚约 0.5 秒）
msg.delay = 5.0;  // 延迟 5 秒
[[FusionCore getInstance] asyncSendMessage:msg];

// 取消
[[FusionCore getInstance] asyncCancelMessage:msg];
```

**接收结果**：顶层消息完成后，框架在发起线程上发送 `FusionNativeMessageNotification`。
该通知面向所有顶层消息广播，需在回调中判断是否为自己发出的消息：
```objc
[[NSNotificationCenter defaultCenter] addObserver:self
                                         selector:@selector(onMessageFinished:)
                                             name:FusionNativeMessageNotification
                                           object:nil];

- (void)onMessageFinished:(NSNotification *)notification {
    FusionNativeMessage *message = notification.object;
    if (message != _myMessage) return;
    if (message.state == FusionNativeMessageFinish) {
        id result = [message getValueFromDataTableWith:@"resultKey"];
    }
}
```

**在 Actor 中处理消息**：
```objc
- (void)processFusionNativeMessage:(FusionNativeMessage *)message {
    // 读取输入参数
    NSDictionary *args = [message args];
    NSString *value = [args objectForKey:@"key"];

    // 将结果写入 dataTable
    [message setValue:result ToDataTableWith:@"resultKey"];

    // 标记为完成
    [message setState:FusionNativeMessageFinish];

    // 或标记为失败
    // [message setState:FusionNativeMessageFailed];
}

// 每个子消息完成（Finish 或 Failed）时回调至父消息所在的 Actor
- (void)processCallbackMessage:(FusionNativeMessage *)message
                 ParentMessage:(FusionNativeMessage *)parent {
    id result = [message getValueFromDataTableWith:@"resultKey"];
    [parent setValue:result ToDataTableWith:@"childResult"];

    // 默认实现会在父消息已无剩余子消息时将其置为 Finish。
    // 重写本方法时须调用 super，或自行设置父消息状态，否则父消息不会完成。
    [super processCallbackMessage:message ParentMessage:parent];
}
```

**子消息协同**：
父消息可派生多个并行执行的子消息。框架在每个子消息完成时先将其从父消息中移除，再回调父消息所在 Actor；
`FusionActor` 的默认回调实现会在全部子消息完成后将父消息置为 Finish。若父消息提前进入 Finish 或
Failed 状态，其尚未完成的子消息会被自动取消。
```objc
// 在父消息所在 Actor 的 processFusionNativeMessage: 中：
FusionNativeMessage *child = [[FusionNativeMessage alloc]
    initWithSerivice:@"service" actor:@"actor" args:args];
[parentMsg insertSubMessage:child];   // 由父消息挂载子消息
[[FusionCore getInstance] asyncSendMessage:child];
// 此处不设置 parentMsg 的状态，由回调负责完成
```

### ARC 兼容

所有源文件均引入 `FusionBase/FusionBase/CommonHeader/` 下的 `SafeARC.h`（各 podspec 通过
`HEADER_SEARCH_PATHS` 引入该目录），以同时兼容 ARC 与非 ARC 工程：

```objc
SafeRetain(obj)           // 非 ARC 下执行 retain，ARC 下为空操作
SafeRelease(obj)          // 非 ARC 下 release 并置 nil，ARC 下仅置 nil
SafeAutoRelease(obj)      // 非 ARC 下执行 autorelease，ARC 下为空操作
SafeSuperDealloc(super)   // 非 ARC 下调用 [super dealloc]，ARC 下为空操作
SafeAutoReleasePoolStart  // 非 ARC 下开始 @autoreleasepool
SafeAutoReleasePoolEnd    // 非 ARC 下结束 @autoreleasepool
```

### UI 导航架构

**PageNavigator**（`FusionUI/FusionUI/Navigation/FusionPageNavigator.h`）：
- 中央导航控制器，管理视图控制器栈
- 负责 push / pop、TabBar 集成及自定义转场动画
- 页面生命周期协议：`IFusionPageProtocol`
- 采用适配器模式实例化页面：`IFusionPageAdapterProtocol`

**页面控制器**（`FusionUI/FusionUI/FusionPageController.h`）：
- 所有页面的基类，实现 `IFusionPageProtocol`
- 生命周期方法：`enterAnimeStart/Finish/Cancel`、`exitAnimeStart/Finish/Cancel`
- 通过 `processPageCommand:args:` 接收命令
- 通过 `dumpPageContext` / `reloadPageContext:` 保存与恢复页面上下文

**IFusionPageProtocol**（必须实现的方法）：
```objc
- (id)initWithConfig:(NSDictionary *)pageConfig;
- (void)processPageCommand:(NSString *)command args:(NSDictionary *)args;
- (void)setNavigator:(FusionPageNavigator *)navigator;
- (FusionPageNavigator *)getNavigator;
- (void)setTabBar:(FusionTabBar *)tabBar;
```

**页面配置字典**：
```objc
@{
    @"pageName": @"HomePage",              // 页面唯一标识
    @"class": @"HomeViewController",        // UIViewController 类名
    @"title": @"Home",                     // 导航栏标题
    @"tabbar_name": @"MainTabBar",         // 可选的 TabBar 名称
    @"singleton": @YES                     // YES：复用实例；NO：每次新建
}
```

**页面适配器**（IFusionPageAdapterProtocol）：
```objc
@protocol IFusionPageAdapterProtocol<NSObject>
- (UIViewController<IFusionPageProtocol> *)generateFusionPageController:(NSDictionary *)pageConfig;
- (NSDictionary *)getPageConfig:(NSString *)pageName;
- (FusionTabBar *)generateFusionTabbar:(NSString *)tabbarName;
@end
```

**页面转场**：
- 通过 `setNaviAnimeType:` 设置自定义动画类型（如 2D 效果、滑动）
- 通过快照视图实现平滑转场：`setPrevSnapView:`、`getPrevSnapView:`
- 通过遮罩视图实现覆盖效果：`setPrevMaskView:`、`getPrevMaskView:`
- 屏幕旋转后更新布局：`updateSubviewsLayout`（可选）

**TabBar 集成**：
```objc
FusionPageMessage *msg = [[FusionPageMessage alloc]
    initWithPageName:@"PageName"
            pageNick:nil
             command:@"init"
                args:@{}
            callback:nil];
[navigator gotoPage:msg];
```

### 网络架构（CoreService）

CoreService 通过两个基于 **AFNetworking**（`NSURLSession`）实现的 **FusionActor** 提供网络能力。
框架已不再包含自研网络引擎，原有的 NeoNetEngine（libcurl + c-ares）已被移除。网络 Actor 运行在
`threadType` 为 `FusionService_NET` 的 Service 上，因此其方法均在 Fusion 网络线程上执行。

**Actor**（`CoreService/CoreService/Network/`）：
- `NetNormalActor`：通过共享的 `AFHTTPSessionManager` 发起 GET / POST 请求。接受任意状态码与
  内容类型（响应为原始 `NSData`）。通过重定向 block 支持 `HTTP_DISABLE_FOLLOW`（否则 NSURLSession
  会自动跟随 301/302 重定向）。
- `DownloadFileActor`：通过 `AFURLSessionManager` 的下载任务下载文件。复用 `DownloadFileCluster`
  对同一 URL 的并发请求去重；若文件已存在且未设置 `force_download`，则直接返回。

**线程注意事项**：AFNetworking 的完成回调在主队列上触发。两个 Actor 均先将回调切回 Fusion 网络线程
（`[[FusionCore getInstance] getNetworkThread]`），再修改 Actor 状态并调用 `setState:`，
以保证"状态仅限单线程访问"这一约束不被破坏。

**消息参数 / 结果键**（`NetworkCommon.h`）：
- 输入：`NET_REMOTE_URL`、`NET_HTTP_METHOD`、`NET_HTTP_HEADER`、`NET_HTTP_PARAMS`、
  `NET_LOCAL_PATH`、`NET_TEMP_PATH`、`NET_FORCE_DOWNLOAD`、`HTTP_DISABLE_FOLLOW`
- dataTable 中的结果：`HTTP_RESPONSE_DATA`、`HTTP_RESPONSE_HEADER`、`HTTP_RESPONSE_CODE`、
  `HTTP_EFFECTIVE_URL`
- 错误通过 `FusionNativeMessage (Error)` 分类设置：
  `setErrorDomainCode:errorCode:errorMsg:`

**发起请求**（须经由消息系统发送，不要直接调用 Actor）：
```objc
FusionNativeMessage *msg = [[FusionNativeMessage alloc]
    initWithSerivice:@"netService"
               actor:@"netNormal"
                args:@{NET_REMOTE_URL: @"https://api.example.com/data",
                       NET_HTTP_METHOD: HTTP_GET_METHOD}];
[[FusionCore getInstance] asyncSendMessage:msg];
// 完成后回调在发起线程上触发；从 dataTable 中读取结果。
```

### 公共头文件

`FusionBase/FusionBase/CommonHeader/` 包含各模块共用的定义：
- `SafeARC.h`：ARC 兼容宏
- `CommonErrorCode.h`：标准错误码与错误域
- `CommonNotification.h`：框架范围内使用的 NSNotification 名称

## 开发指南

### 新增 Service

Service 的属性（包括**线程类型**）均来自其配置字典。配置可由 Lua 文件 `Script/Service/*.lua` 定义并打包进
`config.zip`，也可直接在代码中构建。无需在子类中重写 `_threadType`，`FusionService initWithConfig:`
会读取 `thread_type` 键。仅当需要定制容器行为（例如 `canConcurrentExecute:`）时才需要子类化。

1. **创建 Actor 类**（实现处理逻辑）：
   ```objc
   @interface MyActor : FusionActor
   @end

   @implementation MyActor
   - (void)processFusionNativeMessage:(FusionNativeMessage *)message {
       // 处理消息
       [message setState:FusionNativeMessageFinish];
   }
   @end
   ```

2. **通过 Lua 定义 Service**（`{Module}/Script/Service/MyService.lua`）。Lua 表承载完整配置，
   包括 Service 类、Actor 以及线程类型等属性：
   ```lua
   local service = FusionService.new("myService", "FusionService")  -- 或其子类
   service.thread_type = 1   -- 0=Default（工作线程池） 1=NET 2=UI（主线程）
   service:addActor(FusionActor.new("myActor", "MyActor"))
   register_core_service(service)
   ```
   等价的配置字典（即框架运行时实际读取的内容）：
   ```objc
   @{ @"name": @"myService", @"class": @"FusionService", @"thread_type": @(1),
      @"actors": @{ @"myActor": @{ @"class": @"MyActor" } } }
   ```

3. **重新生成宏**（同时将 Lua 配置打包进 `config.zip`）：
   ```bash
   cd Workspace
   lua MacroMaker.lua
   # 生成 TRIPServiceMacro.h
   ```

4. **在代码中使用**：
   ```objc
   #import "TRIPServiceMacro.h"

   FusionNativeMessage *msg = [[FusionNativeMessage alloc]
       initWithSerivice:MYSERVICE_SERVICE
                  actor:MYACTOR_ACTOR
                   args:@{}];
   [[FusionCore getInstance] asyncSendMessage:msg];
   ```

### 新增页面

1. **创建 ViewController**：
   ```objc
   @interface MyViewController : FusionPageController <IFusionPageProtocol>
   @end

   @implementation MyViewController
   - (void)processPageCommand:(NSString *)command args:(NSDictionary *)args {
       if ([command isEqualToString:@"init"]) {
           // 初始化页面
       }
   }
   @end
   ```

2. **添加 Lua 配置**（`{Module}/Script/Page/MyPage.lua`）：
   ```lua
   local page = Page.new("MyPage", "MyViewController", "MyPageTracking")
   page:addCommand("customCommand")
   register_page(page)
   ```

3. **重新生成宏**：
   ```bash
   cd Workspace
   lua MacroMaker.lua
   # 生成 TRIPPageMacro.h
   ```

4. **实现适配器**（在 AppDelegate 或配置类中）：
   ```objc
   - (UIViewController<IFusionPageProtocol> *)generateFusionPageController:(NSDictionary *)pageConfig {
       NSString *className = [pageConfig objectForKey:@"class"];
       Class pageClass = NSClassFromString(className);
       return [[pageClass alloc] initWithConfig:pageConfig];
   }
   ```

5. **跳转到页面**：
   ```objc
   FusionPageMessage *msg = [[FusionPageMessage alloc]
       initWithPageName:@"MyPage"
               pageNick:nil
                command:@"init"
                   args:@{@"data": @"value"}
               callback:nil];   // callback 是 NSURL（而非 block），详见下文
   [navigator gotoPage:msg];
   ```
   `callback:` 参数的类型是 **`NSURL`**，而非 block。如需将结果回传给当前页面，可调用
   `[FusionPageNavigator generateCallbackUrl:self]` 生成回调 URL，并在其后追加参数与 `#command` 片段；
   被打开的页面结束时，框架会将该命令投递到发起页面的 `processPageCommand:args:`。

### 调试消息流

1. **开启日志**：在 FusionCoreEx.m 中启用日志，以查看消息路由情况
2. **检查消息状态**：通过 `[message state]` 属性
3. **查看处理结果**：通过 `[message getDataTable]` 检查 dataTable
4. **监控线程分配**：通过 `[message workerNick]` 属性
5. **使用延迟消息辅助测试**：`message.delay = 0.5; [[FusionCore getInstance] asyncSendMessage:message];`
6. **消息没有回调时**：先确认 Actor 是否在所有分支上都设置了 Finish / Failed；再确认 service / actor
   名称与配置一致（找不到 Service 或 Actor 时，消息会被静默丢弃）

### 验证 Lua 脚本修改

修改 `Script/Service/*.lua` 或 `Script/Page/*.lua` 后执行：
```bash
cd Workspace
lua MacroMaker.lua
```

该命令会重新生成宏头文件。若出现 Lua 错误，脚本会执行失败，但保留原有的宏文件不变。此时请检查错误输出，并修正语法或逻辑问题。

### 模块依赖

**FusionBase**（无依赖）：
- 基础消息类、JSON 工具、URL 辅助工具
- 被所有模块引用

**FusionCore**（依赖 FusionBase、Utility）：
- Actor 模型、消息分发、线程管理
- 被 CoreService 及自定义 Service 引用

**Utility**（依赖 FusionBase、Enviroment）：
- 加密、文件操作、Zip、Lua 引擎；内置 OpenSSL 静态库
- 被需要相应工具能力的模块引用

**Enviroment**（依赖 FusionBase）：
- 应用配置、UserDefaults 封装
- 可选；用于区分不同环境的配置

**CoreService**（依赖 FusionCore、FusionBase、Utility、AFNetworking）：
- 基于 AFNetworking 的网络 Actor（GET / POST 与文件下载）
- 不涉及网络 I/O 时可不引入

**FusionUI**（依赖 FusionBase）：
- 页面导航器、页面控制器、TabBar
- 基于 UI 的应用必须引入

**TestApp**（依赖全部模块）：
- 演示全部功能：消息通信、页面导航、TabBar

## 测试

`TestApp/` 目录提供了完整示例：
- `TestPageA/B/C`：演示页面导航的示例页面
- `TestPageController`：基础页面实现
- `TestAppDelegate`：应用初始化及导航器配置
- `TestAdapter`：页面适配器实现

构建并运行 TestApp 以验证框架工作正常（若 Pod 未同步，请先执行 `pod install`）：
```bash
xcodebuild -workspace Workspace/FusionWorkspace.xcworkspace \
           -scheme TestApp \
           -configuration Debug \
           -sdk iphonesimulator \
           -derivedDataPath /tmp/FusionBuild
```

重点测试场景：
1. 页面 push / pop 导航
2. TabBar 切换
3. 向 Service 分发消息
4. 通过 CoreService 网络 Actor（AFNetworking）发起网络请求
5. 屏幕旋转时页面上下文的保持
