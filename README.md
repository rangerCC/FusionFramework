# FusionFramework

FusionFramework 是一个模块化的 iOS 应用开发框架，采用 Actor 模型设计，提供清晰的模块划分和高效的消息驱动架构。

> 📚 **完整文档**: 详见 [ARCHITECTURE.md](ARCHITECTURE.md) - 包含详细的架构设计、核心技术点和使用指南

## 特性

- **模块化设计**：框架由多个独立模块组成，每个模块负责特定功能领域
- **Actor 模型**：基于 Actor 模型的消息驱动架构，实现高并发和松耦合
- **页面导航管理**：强大的页面导航系统，支持自定义转场动画和 TabBar 管理
- **网络层封装**：基于 libcurl 的高性能网络引擎，支持 DNS 缓存和并发请求
- **Lua 代码生成**：通过 Lua 配置自动生成 Objective-C 宏和服务注册代码
- **ARC 兼容**：SafeARC.h 提供 ARC 和非 ARC 环境的完美兼容
- **完整工具链**：提供 JSON 处理、加密解密、文件操作、Lua 脚本等工具类

## 架构概览

```
┌─────────────────────────────────────────────────────────────┐
│                        TestApp                              │
│                     (示例应用程序)                           │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│                        FusionUI                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │ PageNavigator│  │PageController│  │NaviBar/TabBar│       │
│  └──────────────┘  └──────────────┘  └──────────────┘       │
│  ┌──────────────┐  ┌──────────────┐                         │
│  │Animation/    │  │  Transitions │                         │
│  │   Effects    │  │              │                         │
│  └──────────────┘  └──────────────┘                         │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│                       FusionCore                            │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │    Actor     │  │    Service   │  │ NativeMessage│       │
│  └──────────────┘  └──────────────┘  └──────────────┘       │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │ MessagePool  │  │TimerService/ │  │    Thread    │       │
│  │              │  │   TimerTask  │  │              │       │
│  └──────────────┘  └──────────────┘  └──────────────┘       │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│                       FusionBase                            │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │    Message   │  │ JSONCategory │  │RemoveNSNull  │       │
│  └──────────────┘  └──────────────┘  └──────────────┘       │
│  ┌──────────────┐                                            │
│  │ NSURLUtility │                                            │
│  └──────────────┘                                            │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│  CoreService │   Utility    │   Enviroment                  │
│  ┌──────────┐ │  ┌────────┐ │  ┌──────────┐                 │
│  │NeoNetEngine│ │  │ Crypto │ │  │AppEnvironment│             │
│  │(HTTP/HTTPS)│ │  ├────────┤ │  ├──────────┤                 │
│  ├──────────┤ │  │ FileKit│ │  │AppUserDefault│              │
│  │DownloadFile│ │  ├────────┤ │  └──────────┘                 │
│  │  Cluster  │ │  │  Zip   │ │                               │
│  ├──────────┤ │  ├────────┤ │                               │
│  │AutoClean │ │  │  Lua   │ │                               │
│  │   Cache   │ │  └────────┘ │                               │
│  └──────────┘ └─────────────┘                               │
└─────────────────────────────────────────────────────────────┘
```

## 模块说明

### 1. FusionCore
核心消息处理模块，基于 Actor 模型设计：
- **FusionActor**：消息处理单元，接收并处理特定类型的消息
- **FusionService**：服务管理器，管理一组 Actor，支持多线程配置
- **FusionNativeMessage**：原生消息对象，用于模块间通信
- **FusionMessagePool**：消息池管理，优化内存使用
- **FusionTimerService / FusionTimerTask**：定时任务服务

### 2. FusionUI
UI 层框架，提供页面管理和导航功能：
- **FusionPageNavigator**：页面导航控制器，支持 push/pop、TabBar 管理
- **FusionPageController**：页面基类，提供统一的页面生命周期管理
- **FusionPageMessage**：页面间消息传递
- **FusionNaviBar / FusionTabBar**：导航栏和标签栏组件
- **转场动画系统**：支持自定义页面转场动画（2D/滑动效果）

### 3. FusionBase
基础工具模块：
- **FusionMessage**：基础消息类，支持 URL 格式消息
- **JSON 扩展**：NSArray/NSDictionary/NSString 的 JSON 序列化扩展
- **NSNull 清理**：自动清理集合中的 NSNull 值
- **NSURL 工具**：URL 解析和构建工具

### 4. CoreService
核心服务模块：
- **NeoNetEngine**：基于 libcurl 的网络引擎，支持 HTTP/HTTPS、DNS 缓存
- **NeoNetTask / NeoHttpTask**：网络任务基类
- **NeoDNSEngine**：DNS 引擎，支持自定义 DNS 解析
- **DownloadFileCluster**：文件下载管理器，支持断点续传
- **AutoCleanCacheTask**：自动缓存清理任务

### 5. Utility
工具类集合：
- **Crypto**：DES 加密/解密、Base64 编解码
- **FileKit / FileHelper**：文件操作工具
- **Zip**：ZIP 压缩/解压（基于 minizip）
- **Lua**：Lua 5.1.5 脚本引擎集成
- **UIColor+Extension**：颜色处理工具
- **SignatureHelper**：签名生成工具

### 6. Enviroment
环境管理模块：
- **AppEnvironment**：应用环境配置管理
- **AppUserDefault**：NSUserDefaults 封装

## 使用方法

### 基本配置

1. 打开 `Workspace/FusionWorkspace.xcworkspace` 工作空间
2. 各模块为独立的 Xcode 项目，可根据需要引用

### 初始化页面导航

```objc
#import <FusionUI/FusionUI.h>

- (BOOL)application:(UIApplication *)application 
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    
    // 创建导航控制器
    FusionPageNavigator *navigator = [[FusionPageNavigator alloc] init];
    [navigator.view setBackgroundColor:[UIColor whiteColor]];
    
    // 设置页面适配器
    [navigator setAdapter:[YourAdapter getInstance]];
    
    self.window.rootViewController = navigator;
    [self.window makeKeyAndVisible];
    
    // 跳转到首页
    FusionPageMessage *message = [[FusionPageMessage alloc] 
        initWithPageName:@"HomePage"
                pageNick:nil
                 command:@"init"
                    args:@{}
                callback:nil];
    [navigator gotoPage:message];
    
    return YES;
}
```

### 发送消息

```objc
#import <FusionCore/FusionCore.h>

// 创建消息
FusionNativeMessage *message = [[FusionNativeMessage alloc] 
    initWithURL:[NSURL URLWithString:@"AppName://service/actor?command=doSomething"]];

// 发送消息
[[FusionCore getInstance] sendMessage:message];
```

### 网络请求

```objc
#import <CoreService/CoreService.h>

// 创建网络任务
NeoHttpTask *task = [[NeoHttpTask alloc] init];
task.url = @"https://api.example.com/data";
task.method = @"GET";

// 启动任务
[[NeoNetEngine getInstance] startTask:task];
```

## 系统要求

- iOS 7.0+
- Xcode 6.0+
- ARC 支持

## 依赖库

- libcurl（网络层）
- c-ares（DNS 解析）
- Lua 5.1.5（脚本引擎）
- OpenSSL（加密）
- minizip（ZIP 处理）

## 许可证

MIT License - 详见 [LICENSE](LICENSE) 文件

## 作者

Ryou Zhang

## 贡献

欢迎提交 Issue 和 Pull Request。
