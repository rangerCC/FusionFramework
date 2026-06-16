# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build System

This is a modular iOS framework managed by **CocoaPods**. Each module is a local pod
(a `*.podspec` at the repo root) consumed by the `TestApp` target via `:path => '.'`.

**Setup** (run after cloning, and whenever a podspec or the Podfile changes):
```bash
pod install
```

**Workspace**: open `Workspace/FusionWorkspace.xcworkspace` in Xcode. It references only
`TestApp/TestApp.xcodeproj` and the generated `Pods/Pods.xcodeproj` — CocoaPods compiles
each module from its podspec source globs. (The per-module `.xcodeproj` files still exist on
disk but are no longer the build targets.)

**Local module pods** (root `*.podspec`):
- `FusionBase` — base message/utility layer, no module dependencies
- `Enviroment` — app configuration, depends on FusionBase
- `Utility` — Crypto, FileKit, Zip, Lua; vendors `libcrypto.a`/`libssl.a`, links `z`/`sqlite3`; depends on FusionBase, Enviroment
- `FusionCore` — Actor model & message dispatch; depends on FusionBase, Utility
- `FusionUI` — navigation & UI; depends on FusionBase
- `CoreService` — network actors (built on AFNetworking); depends on FusionCore, FusionBase, Utility, AFNetworking

**Third-party pods** (TestApp target): SDWebImage, AFNetworking, FMDB, CocoaLumberjack,
MJRefresh, Masonry, IQKeyboardManager.

**Deployment target**: Podfile pins iOS 15.0 (forced for all pods in `post_install`). The
`post_install` hook also strips a private-header import from AFNetworking 4.0.1
(`<netinet6/in6.h>`) that Xcode 26.4+ rejects under `use_frameworks!`.

**Build / run the demo app**:
```bash
xcodebuild -workspace Workspace/FusionWorkspace.xcworkspace \
           -scheme TestApp \
           -configuration Debug \
           -sdk iphonesimulator \
           -derivedDataPath /tmp/FusionBuild
```

## Architecture Overview

FusionFramework is an **Actor-model message-driven iOS framework** with **Lua-based code generation**. The framework enforces strict message-passing architecture with automatic thread routing.

### Core Message System (FusionCore)

**Actor Model Hierarchy**:
```
FusionCore (singleton message dispatcher)
  └── FusionService (service container, manages Actors)
      └── FusionActor (message handler unit)
```

**Message Flow**:
1. Client creates `FusionNativeMessage` with service/actor/command
2. Sends to `FusionCore` via `asyncSendMessage()` or `sendMessage()`
3. FusionCore routes to appropriate service based on `threadType`
4. Service instantiates/reuses Actor and calls `processFusionNativeMessage:()`
5. Actor processes and sets result via `setValue:ToDataTableWith:`
6. Message state transitions to `FusionNativeMessageFinish` or `FusionNativeMessageFailed`
7. Result callback fires on originating thread (for async sends)

**Message State Machine**:
```objc
#define FusionNativeMessageOrigin  0   // Initial state when created
#define FusionNativeMessageFinish  1   // Completed successfully
#define FusionNativeMessageFailed  2   // Error occurred
#define FusionNativeMessageMaxNum  99999  // Custom states start here
```

**Message Structure** (FusionNativeMessage.h):
```objc
@interface FusionNativeMessage : FusionMessage
  @property NSTimeInterval delay;              // For delayed dispatch
  @property NSTimeInterval triggerTime;        // When to trigger delayed message
  @property NSString *service;                 // Service name (read-only)
  @property NSString *actor;                   // Actor name (read-only)
  @property NSUInteger state;                  // Current state
  @property NSThread *originThread;            // Thread that sent message
  @property NSString *workerNick;              // Assigned worker thread
  @property FusionNativeMessage *parent;       // Parent for sub-messages
  @property NSMutableDictionary _dataTable;    // Result storage
  
  // Sub-message management for parallel processing
  - (NSArray *)getChildren;
  - (void)insertSubMessage:(FusionNativeMessage *)message;
  - (void)removeSubMessage:(FusionNativeMessage *)message;
  // Parent auto-completes when all children finish
@end
```

**Threading Model**:

FusionCore maintains multiple dedicated threads. A service's `threadType` (read from its
config `thread_type` key, not set by subclassing) determines the execution thread:

- `FusionService_Default` (0) → WorkerThread pool (CPU*2 threads, round-robin allocation)
- `FusionService_NET` (1) → NetworkThread (dedicated for I/O)
- `FusionService_UI` (2) → MainThread (for UIKit calls)

Thread counts on modern devices:
- CoreThread (always running, processes delayed messages)
- NetworkThread (always running, for async I/O)
- WorkerThreads: 2 × CPU count (e.g., 8 threads on quad-core)
- MainThread (implicit UIKit thread)

### Service and Actor Implementation

**FusionService** (FusionCore/FusionCore/FusionService.h):
- Container for related Actors
- Handles message filtering via `FusionFilter`
- Supports concurrent execution control via `canConcurrentExecute:()`
- Lazy-loads Actors on first message

**FusionActor** (FusionCore/FusionCore/FusionActor.h):
- Base class for message handlers
- New instance created per message (stateless by design)
- Override `processFusionNativeMessage:` to handle messages
- Can define message filters for pre-processing

**Filter System** (FusionCore/FusionCore/Filter/):
- Composable message validation
- `FusionFilter` (base class)
- `FusionAndFilter` (all conditions must pass)
- `FusionOrFilter` (any condition can pass)
- `FusionNotFilter` (inverts condition)

### Lua Code Generation System

The `Workspace/MacroMaker.lua` script generates Objective-C macros from Lua configuration. This enables compile-time verification of service/actor/page names.

**How it Works**:
1. Scans all `*/Script/Service/*.lua` and `*/Script/Page/*.lua` files
2. Executes Lua scripts to populate service/page registry
3. Generates two header files:
   - `TRIPServiceMacro.h` - Service and Actor name constants
   - `TRIPPageMacro.h` - Page name constants
4. Creates `Script.bundle/` with processed scripts and `config.zip`

**Running Code Generation**:
```bash
cd Workspace
lua MacroMaker.lua
# Generates: TRIPServiceMacro.h, TRIPPageMacro.h, Script.bundle/, config.zip
```

**Service Definition** (Script/Service/YourService.lua):
```lua
local service = FusionService.new("myService", "MyServiceClass")
service:addActor(FusionActor.new("actor1", "MyActor1"))
service:addActor(FusionActor.new("actor2", "MyActor2"))
service:addFilter(SomeFilter.new())  -- Optional message filter
register_core_service(service)  -- or register_logic_service()
```

Generated macro usage:
```objc
#import "TRIPServiceMacro.h"

FusionNativeMessage *msg = [[FusionNativeMessage alloc]
    initWithSerivice:MYSERVICE_SERVICE
               actor:ACTOR1_ACTOR
                args:@{@"key": @"value"}];
[[FusionCore getInstance] asyncSendMessage:msg];
```

**Page Definition** (Script/Page/YourPage.lua):
```lua
local page = Page.new("PageName", "ViewControllerClass", "TrackingName")
page:addCommand("customCommand")
register_page(page)
```

**Special Page Types**:
- H5 Host pages: `Page.newH5Host("name", urls_dict, "trackName")`
  - `urls` table has keys: `test`, `prepare`, `release` for different environments

### Message Communication Pattern

**Sending Messages**:
```objc
// Create message with service/actor/args
FusionNativeMessage *msg = [[FusionNativeMessage alloc]
    initWithSerivice:@"serviceName"
               actor:@"actorName"
                args:@{@"key": @"value"}];

// Async send (callback fires on originating thread)
[[FusionCore getInstance] asyncSendMessage:msg];

// Sync send (blocks until complete)
[[FusionCore getInstance] sendMessage:msg];

// Delayed send
msg.delay = 5.0;  // 5 second delay
[[FusionCore getInstance] asyncSendMessage:msg];
```

**Processing Messages in Actor**:
```objc
- (void)processFusionNativeMessage:(FusionNativeMessage *)message {
    // Access input arguments
    NSDictionary *args = [message args];
    NSString *value = [args objectForKey:@"key"];
    
    // Store result in dataTable
    [message setValue:result ToDataTableWith:@"resultKey"];
    
    // Mark as finished
    [message setState:FusionNativeMessageFinish];
    
    // Or mark as failed
    // [message setState:FusionNativeMessageFailed];
}

// Callback from parent message completion
- (void)processCallbackMessage:(FusionNativeMessage *)message
                 ParentMessage:(FusionNativeMessage *)parent {
    id result = [message getValueFromDataTableWith:@"resultKey"];
    // Parent auto-completes when all children finish
}
```

**Sub-Message Coordination**:
Parent messages can spawn child messages that execute in parallel. Parent automatically completes when all children finish:
```objc
// In parent actor:
FusionNativeMessage *child = [FusionNativeMessage alloc]
    initWithSerivice:@"service" actor:@"actor" args:args];
[parentMsg insertSubMessage:child];
[[FusionCore getInstance] asyncSendMessage:child];
// Parent completes after all children finish
```

### ARC Compatibility

All source files include `SafeARC.h` from `Workspace/CommonHeader/` for compatibility with both ARC and non-ARC projects:

```objc
SafeRetain(obj)           // Retains in non-ARC, no-op in ARC
SafeRelease(obj)          // Releases/nils in non-ARC, nils in ARC
SafeAutoRelease(obj)      // Autorelease in non-ARC, no-op in ARC
SafeSuperDealloc()        // [super dealloc] in non-ARC, no-op in ARC
SafeAutoReleasePoolStart  // Begin @autoreleasepool in non-ARC
SafeAutoReleasePoolEnd    // End @autoreleasepool in non-ARC
```

### UI Navigation Architecture

**PageNavigator** (`FusionUI/FusionUI/Navigation/FusionPageNavigator.h`):
- Central navigation controller managing view controller stack
- Handles push/pop, TabBar integration, custom animations
- Page lifecycle protocol: `IFusionPageProtocol`
- Adapter pattern for page instantiation: `IFusionPageAdapterProtocol`

**Page Controller** (`FusionUI/FusionUI/FusionPageController.h`):
- Base class for all pages, implements `IFusionPageProtocol`
- Lifecycle methods: `enterAnimeStart/Finish/Cancel`, `exitAnimeStart/Finish/Cancel`
- Receives commands via `processPageCommand:args:`
- Context save/restore via `dumpPageContext` / `reloadPageContext:`

**IFusionPageProtocol** (required methods):
```objc
- (id)initWithConfig:(NSDictionary *)pageConfig;
- (void)processPageCommand:(NSString *)command args:(NSDictionary *)args;
- (void)setNavigator:(FusionPageNavigator *)navigator;
- (FusionPageNavigator *)getNavigator;
- (void)setTabBar:(FusionTabBar *)tabBar;
```

**Page Configuration Dictionary**:
```objc
@{
    @"pageName": @"HomePage",              // Unique page identifier
    @"class": @"HomeViewController",        // UIViewController class
    @"title": @"Home",                     // Navigation title
    @"tabbar_name": @"MainTabBar",         // Optional TabBar name
    @"singleton": @YES                     // YES: reuse instance, NO: new each time
}
```

**Page Adapter** (IFusionPageAdapterProtocol):
```objc
@protocol IFusionPageAdapterProtocol<NSObject>
- (UIViewController<IFusionPageProtocol> *)generateFusionPageController:(NSDictionary *)pageConfig;
- (NSDictionary *)getPageConfig:(NSString *)pageName;
- (FusionTabBar *)generateFusionTabbar:(NSString *)tabbarName;
@end
```

**Page Transitions**:
- Custom animation types set via `setNaviAnimeType:` (e.g., 2D effects, slide)
- Snapshot views for smooth transitions: `setPrevSnapView:`, `getPrevSnapView:`
- Mask views for overlay effects: `setPrevMaskView:`, `getPrevMaskView:`
- Layout updates after rotation: `updateSubviewsLayout` (optional)

**TabBar Integration**:
```objc
FusionPageMessage *msg = [[FusionPageMessage alloc]
    initWithPageName:@"PageName"
            pageNick:nil
             command:@"init"
                args:@{}
            callback:nil];
[navigator gotoPage:msg];
```

### Network Architecture (CoreService)

CoreService exposes networking through two **FusionActors** built on **AFNetworking**
(`NSURLSession`). There is no longer a custom network engine — the legacy NeoNetEngine
(libcurl + c-ares) was removed. Network actors run on a service whose `threadType` is
`FusionService_NET`, so their methods execute on the Fusion network thread.

**Actors** (`CoreService/CoreService/Network/`):
- `NetNormalActor` — GET/POST via a shared `AFHTTPSessionManager`. Accepts any status code
  and content type (raw `NSData` response). Honors `HTTP_DISABLE_FOLLOW` via a redirection
  block (NSURLSession auto-follows 301/302 otherwise).
- `DownloadFileActor` — file download via `AFURLSessionManager` download tasks. Reuses
  `DownloadFileCluster` to dedupe concurrent requests for the same URL; short-circuits when
  the file already exists unless `force_download` is set.

**Threading note**: AFNetworking completion blocks fire on the main queue. Both actors
marshal completion back to the Fusion network thread (`[[FusionCore getInstance]
getNetworkThread]`) before mutating actor state and calling `setState:`, preserving the
single-threaded-confinement invariant.

**Message args / result keys** (`NetworkCommon.h`):
- Inputs: `NET_REMOTE_URL`, `NET_HTTP_METHOD`, `NET_HTTP_HEADER`, `NET_HTTP_PARAMS`,
  `NET_LOCAL_PATH`, `NET_TEMP_PATH`, `NET_FORCE_DOWNLOAD`, `HTTP_DISABLE_FOLLOW`
- Results in dataTable: `HTTP_RESPONSE_DATA`, `HTTP_RESPONSE_HEADER`, `HTTP_RESPONSE_CODE`,
  `HTTP_EFFECTIVE_URL`
- Errors via the `FusionNativeMessage (Error)` category:
  `setErrorDomainCode:errorCode:errorMsg:`

**Sending a request** (through the message system, not by calling the actor directly):
```objc
FusionNativeMessage *msg = [[FusionNativeMessage alloc]
    initWithSerivice:@"netService"
               actor:@"netNormal"
                args:@{NET_REMOTE_URL: @"https://api.example.com/data",
                       NET_HTTP_METHOD: HTTP_GET_METHOD}];
[[FusionCore getInstance] asyncSendMessage:msg];
// On completion the callback fires on the originating thread; read results from dataTable.
```

### Common Headers

`Workspace/CommonHeader/` contains shared definitions used across all modules:
- `SafeARC.h` - ARC compatibility macros
- `CommonErrorCode.h` - Standard error codes and domains
- `CommonNotification.h` - NSNotification names used framework-wide

## Working with Code

### Adding a New Service

A Service's attributes — including its **thread type** — come from its config dictionary
(supplied by the Lua `Script/Service/*.lua` definition, bundled into `config.zip`, or built
directly in code). You do not override `_threadType` in a subclass; `FusionService
initWithConfig:` reads the `thread_type` key. Subclassing is only needed for custom
container behavior (e.g. `canConcurrentExecute:`).

1. **Create Actor class(es)** (your handler logic):
   ```objc
   @interface MyActor : FusionActor
   @end

   @implementation MyActor
   - (void)processFusionNativeMessage:(FusionNativeMessage *)message {
       // Process message
       [message setState:FusionNativeMessageFinish];
   }
   @end
   ```

2. **Define the Service via Lua** (`{Module}/Script/Service/MyService.lua`). The Lua table
   carries the full config — service class, actors, and attributes like thread type:
   ```lua
   local service = FusionService.new("myService", "FusionService")  -- or a subclass
   service.thread_type = 1   -- 0=Default(worker pool) 1=NET 2=UI(main)
   service:addActor(FusionActor.new("myActor", "MyActor"))
   register_core_service(service)
   ```
   Equivalent config dictionary (what the framework consumes at runtime):
   ```objc
   @{ @"name": @"myService", @"class": @"FusionService", @"thread_type": @(1),
      @"actors": @{ @"myActor": @{ @"class": @"MyActor" } } }
   ```

3. **Regenerate macros** (also bundles the Lua config into `config.zip`):
   ```bash
   cd Workspace
   lua MacroMaker.lua
   # Generates TRIPServiceMacro.h
   ```

4. **Use in code**:
   ```objc
   #import "TRIPServiceMacro.h"
   
   FusionNativeMessage *msg = [[FusionNativeMessage alloc]
       initWithSerivice:MYSERVICE_SERVICE
                  actor:MYACTOR_ACTOR
                   args:@{}];
   [[FusionCore getInstance] asyncSendMessage:msg];
   ```

### Adding a New Page

1. **Create ViewController**:
   ```objc
   @interface MyViewController : FusionPageController <IFusionPageProtocol>
   @end
   
   @implementation MyViewController
   - (void)processPageCommand:(NSString *)command args:(NSDictionary *)args {
       if ([command isEqualToString:@"init"]) {
           // Initialize page
       }
   }
   @end
   ```

2. **Add Lua configuration** (`{Module}/Script/Page/MyPage.lua`):
   ```lua
   local page = Page.new("MyPage", "MyViewController", "MyPageTracking")
   page:addCommand("customCommand")
   register_page(page)
   ```

3. **Regenerate macros**:
   ```bash
   cd Workspace
   lua MacroMaker.lua
   # Generates TRIPPageMacro.h
   ```

4. **Implement adapter** (in your AppDelegate or config):
   ```objc
   - (UIViewController<IFusionPageProtocol> *)generateFusionPageController:(NSDictionary *)pageConfig {
       NSString *className = [pageConfig objectForKey:@"class"];
       Class pageClass = NSClassFromString(className);
       return [[pageClass alloc] initWithConfig:pageConfig];
   }
   ```

5. **Navigate to page**:
   ```objc
   FusionPageMessage *msg = [[FusionPageMessage alloc]
       initWithPageName:@"MyPage"
               pageNick:nil
                command:@"init"
                   args:@{@"data": @"value"}
               callback:nil];   // callback is an NSURL (not a block); see below
   [navigator gotoPage:msg];
   ```
   The `callback:` parameter is an **`NSURL`**, not a block. To get a result back to the
   current page, generate one with `[FusionPageNavigator generateCallbackUrl:self]`, append
   params and a `#command` fragment; the framework delivers that command to the originating
   page's `processPageCommand:args:` when the opened page finishes.

### Debugging Message Flow

1. **Enable logging** in FusionCoreEx.m to see message routing
2. **Check message state** via `[message state]` property
3. **Inspect dataTable** via `[message getDataTable]` for results
4. **Monitor thread assignment** via `[message workerNick]` property
5. **Use delayed messages** for testing: `message.delay = 0.5; [FusionCore asyncSendMessage:msg];`

### Testing Lua Script Changes

After modifying `Script/Service/*.lua` or `Script/Page/*.lua`:
```bash
cd Workspace
lua MacroMaker.lua
```

This regenerates macro headers. If you get Lua errors, the script will fail but leave old macros in place—check error output and fix syntax/logic.

### Module Dependencies

**FusionBase** (no dependencies):
- Base message class, JSON utilities, URL helpers
- Included by: everything

**FusionCore** (depends on FusionBase):
- Actor model, message dispatch, threading
- Included by: FusionUI, CoreService, custom services

**Utility** (depends on FusionBase, Enviroment):
- Crypto, file operations, Zip, Lua engine; vendors OpenSSL static libs
- Included by modules needing specific utils

**Enviroment** (depends on FusionBase):
- App configuration, user defaults wrapper
- Optional; used for environment-specific settings

**CoreService** (depends on FusionCore, FusionBase, Utility, AFNetworking):
- Network actors (GET/POST + download) on AFNetworking
- Optional if not doing network I/O

**FusionUI** (depends on FusionCore, FusionBase):
- Page navigator, controllers, TabBar
- Required for UI-based apps

**TestApp** (depends on all):
- Demo showing all features: messaging, navigation, TabBar

## Testing

The `TestApp/` directory contains a complete example:
- `TestPageA/B/C` - Sample pages demonstrating navigation
- `TestPageController` - Base page implementation
- `TestAppDelegate` - App initialization with navigator setup
- `TestAdapter` - Page adapter implementation

Build and run TestApp to verify framework is working (run `pod install` first if pods are
out of date):
```bash
xcodebuild -workspace Workspace/FusionWorkspace.xcworkspace \
           -scheme TestApp \
           -configuration Debug \
           -sdk iphonesimulator \
           -derivedDataPath /tmp/FusionBuild
```

Key test scenarios:
1. Page push/pop navigation
2. TabBar switching
3. Message dispatch to services
4. Network requests via CoreService network actors (AFNetworking)
5. Page context preservation across rotations
