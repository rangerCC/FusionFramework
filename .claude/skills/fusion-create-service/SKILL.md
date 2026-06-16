---
name: fusion-create-service
description: Create a new Service and Actor in the FusionFramework message system — a FusionService container with FusionActor message handlers, wired through an IFusionConfig provider. Use when adding backend message-handling logic, a new actor, or a new service to a Fusion-based app.
---

# Create a Fusion Service + Actor

The message system is `FusionCore` → `FusionService` (container) → `FusionActor`
(per-message handler). You define an Actor (your logic), declare it inside a Service config
dict, and expose that config through the app's `IFusionConfig` provider.

## Steps

### 1. Write the Actor

Subclass `FusionActor` and override `processFusionNativeMessage:`. A new Actor instance is
created per actor-name on first use and reused; treat actors as effectively stateless
handlers. Read inputs from `message.args`, write outputs into the dataTable, then set state.

```objc
// MyActor.h
#import <FusionCore/FusionCore.h>
@interface MyActor : FusionActor
@end
```

```objc
// MyActor.m
#import "MyActor.h"

@implementation MyActor
- (void)processFusionNativeMessage:(FusionNativeMessage *)message {
    NSDictionary *args = [message args];
    id input = [args objectForKey:@"key"];

    // ... do work ...

    [message setValue:result ToDataTableWith:@"resultKey"];
    [message setState:FusionNativeMessageFinish];   // or FusionNativeMessageFailed
}
@end
```

### 2. Define the Service config dict

A Service is described by a config dictionary, **not** by subclassing for thread choice.
Key fields (consumed by `FusionService initWithConfig:` and `FusionCore startCoreService`):

```objc
NSDictionary *myServiceConfig = @{
    @"name":  @"myService",
    @"class": @"FusionService",       // or a FusionService subclass name
    @"thread_type": @(1),             // 0=Default(worker pool) 1=NET 2=UI(main)
    @"actors": @{
        @"myActor": @{ @"class": @"MyActor" },
        // @"another": @{ @"class": @"AnotherActor", @"filter": @{@"class": @"..."} },
    },
    // optional service-level filter:
    // @"filter": @{ @"class": @"SomeFilter" },
};
```

- `thread_type` controls the execution thread: `0` worker-thread pool (default),
  `1` dedicated network thread, `2` main thread (for UIKit). Defined as
  `FusionService_Default` / `FusionService_NET` / `FusionService_UI`.
- Each entry under `actors` is keyed by actor name; its `class` is resolved via
  `NSClassFromString` and must be a `FusionActor` subclass.

### 3. Expose it through IFusionConfig

`FusionCore` loads services from an `id<IFusionConfig>` passed to `prepareWithConfig:`
(called once at startup). Return your service config from `getCoreService`:

```objc
@interface MyFusionConfig : NSObject <IFusionConfig>
@end

@implementation MyFusionConfig
- (NSString *)appScheme { return @"myapp"; }
- (NSArray *)getCoreService {
    return @[ myServiceConfig /* , otherServiceConfig ... */ ];
}
- (NSDictionary *)getLogicServiceByName:(NSString *)name { return nil; }
@end
```

Startup wiring (once, e.g. in AppDelegate):

```objc
[[FusionCore getInstance] prepareWithConfig:[MyFusionConfig new]];
```

Alternatively register a pre-built service instance directly:
`[[FusionCore getInstance] registerCoreService:serviceInstance];`

### 4. Send a message to it

See the `fusion-call-service` skill.

## Reference (verified against this repo)

- `FusionCore/FusionCore/FusionActor.h` — actor base class
- `FusionCore/FusionCore/FusionService.{h,m}` — config keys: `thread_type`, `actors`, `filter`
- `FusionCore/FusionCore/FusionCoreEx.h` — `IFusionConfig`, `prepareWithConfig:`,
  `registerCoreService:`, `getNetworkThread`
- `FusionCore/FusionCore/FusionNativeMessage.h` — state constants, dataTable API

## Notes

- Message state constants: `FusionNativeMessageFinish` (1) success,
  `FusionNativeMessageFailed` (2) failure, custom states start at `FusionNativeMessageMaxNum`.
- **Two ways to provide service config**, both producing the same config dict consumed at
  runtime:
  - **Lua** (`{Module}/Script/Service/MyService.lua`): `FusionService.new(...)`,
    `service.thread_type = 1`, `service:addActor(...)`, `register_core_service(service)`.
    `Workspace/MacroMaker.lua` reads these tables to (a) emit `*_SERVICE` / `*_ACTOR` name
    constants into `TRIPServiceMacro.h`, and (b) bundle the scripts into `config.zip`, which
    is loaded at runtime (via `FileHelper getConfigFilePath` + `LuaScriptManager`). The Lua
    table carries the **full** attributes — `thread_type`, actor classes, filters — not just
    names.
  - **Code/`IFusionConfig`**: return the config dict directly from `getCoreService`
    (shown above). The demo app shortcuts page config this way via the Adapter; either path
    is valid.
- For network actors, set `thread_type` to `1` (NET); see `fusion-network-request`.
