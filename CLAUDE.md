# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build System

This is a modular iOS framework using Xcode workspaces:

- **Main Workspace**: `Workspace/FusionWorkspace.xcworkspace` - Open this in Xcode to build all modules
- **Module Projects**: Each module has its own `.xcodeproj` under its directory:
  - `FusionBase/FusionBase.xcodeproj` (base utilities, no dependencies)
  - `FusionCore/FusionCore.xcodeproj` (message core, depends on FusionBase)
  - `Utility/Utility.xcodeproj` (Crypto, FileKit, Zip, Lua, depends on FusionBase)
  - `Enviroment/Enviroment.xcodeproj` (app configuration, depends on FusionBase)
  - `CoreService/CoreService.xcodeproj` (network engine, depends on FusionBase, Utility)
  - `FusionUI/FusionUI.xcodeproj` (navigation & UI, depends on FusionCore, FusionBase)
  - `TestApp/TestApp.xcodeproj` (demo app, depends on all)

**Build order**: FusionBase → (FusionCore, Utility, Enviroment) → (FusionUI, CoreService) → TestApp

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

FusionCore maintains multiple dedicated threads. Service `threadType` determines execution thread:

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

### Network Architecture (NeoNetEngine)

**NeoNetEngine** (`CoreService/CoreService/Network/NeoNetEngine/NeoNetEngine.h`):
- Multi-socket event-driven HTTP/HTTPS engine built on libcurl
- Dedicated NetworkThread for async I/O
- DNS resolution via c-ares with optional caching
- Connection pooling and reuse via `CURLSH` (share handle)

**Task Types**:
- `NeoHttpTask` - Basic GET request
- `NeoHttpPostTask` - POST with body data
- `NeoHttpDownloadTask` - Large file download

**Engine Configuration**:
```objc
NSDictionary *config = @{
    @"dns_service": @"8.8.8.8",      // Custom DNS server (optional)
    @"dns_cache_time": @3600,         // DNS cache TTL in seconds
    @"timeout": @30,                  // Request timeout
    @"connect_timeout": @10           // Connection timeout
};
[[NeoNetEngine getInstance] setConfig:config];
```

**Starting Tasks**:
```objc
NeoHttpTask *task = [[NeoHttpTask alloc] init];
task.url = @"https://api.example.com/data";
task.method = @"GET";
task.callback = ^(NSData *response, NSError *error) {
    if (!error) {
        // Handle response
    }
};
[[NeoNetEngine getInstance] startTask:task];
```

### Common Headers

`Workspace/CommonHeader/` contains shared definitions used across all modules:
- `SafeARC.h` - ARC compatibility macros
- `CommonErrorCode.h` - Standard error codes and domains
- `CommonNotification.h` - NSNotification names used framework-wide

## Working with Code

### Adding a New Service

1. **Create Service class**:
   ```objc
   // MyServiceName.h
   @interface MyServiceName : FusionService
   @end
   
   // MyServiceName.m
   @implementation MyServiceName
   - (id)initWithConfig:(NSDictionary *)config {
       self = [super initWithConfig:config];
       if (self) {
           _threadType = FusionService_NET;  // or _Default, or _UI
       }
       return self;
   }
   @end
   ```

2. **Create Actor class(es)**:
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

3. **Add Lua configuration** (`{Module}/Script/Service/MyService.lua`):
   ```lua
   local service = FusionService.new("myService", "MyServiceName")
   service:addActor(FusionActor.new("myActor", "MyActor"))
   register_core_service(service)
   ```

4. **Regenerate macros**:
   ```bash
   cd Workspace
   lua MacroMaker.lua
   # Generates TRIPServiceMacro.h
   ```

5. **Use in code**:
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
               callback:nil];
   [navigator gotoPage:msg];
   ```

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

**Utility** (depends on FusionBase):
- Crypto, file operations, Zip, Lua engine
- Optional dependency; included only by modules needing specific utils

**Enviroment** (depends on FusionBase):
- App configuration, user defaults wrapper
- Optional; used for environment-specific settings

**CoreService** (depends on FusionBase, Utility):
- Network engine, HTTP tasks
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

Build and run TestApp to verify framework is working:
```bash
xcodebuild -workspace Workspace/FusionWorkspace.xcworkspace \
           -scheme TestApp \
           -configuration Debug \
           -derivedDataPath /tmp/FusionBuild
```

Key test scenarios:
1. Page push/pop navigation
2. TabBar switching
3. Message dispatch to services
4. Network requests via NeoNetEngine
5. Page context preservation across rotations
