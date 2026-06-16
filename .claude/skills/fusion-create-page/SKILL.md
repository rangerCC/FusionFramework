---
name: fusion-create-page
description: Create a new page (screen) in the FusionFramework iOS app — a UIViewController subclass of FusionPageController, registered through the page Adapter. Use when adding a new screen, view controller, or page to a Fusion-based app.
---

# Create a Fusion Page

A "page" is a screen managed by `FusionPageNavigator`. It is a `UIViewController`
subclass of `FusionPageController` (which implements `IFusionPageProtocol`), and it
becomes reachable once its config dictionary is returned by the app's page **Adapter**.

## Steps

### 1. Create the controller

Subclass `FusionPageController`. Override `processPageCommand:args:` to handle the
`init` command (and any custom commands). The base class provides `_naviBar`
(a `FusionNaviBar`) and navigator/tabbar accessors.

```objc
// MyPageController.h
#import <FusionUI/FusionUI.h>

@interface MyPageController : FusionPageController
@end
```

```objc
// MyPageController.m
#import "MyPageController.h"

@implementation MyPageController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.view setBackgroundColor:[UIColor whiteColor]];
    // build UI; _naviBar is available from FusionPageController
}

- (void)processPageCommand:(NSString *)command args:(NSDictionary *)args {
    if (command == nil || [command isEqualToString:@"init"]) {
        // initialize page from args
    }
    // handle custom commands here
}

@end
```

### 2. Register the page in the Adapter

The navigator resolves pages through an object conforming to
`IFusionPageAdapterProtocol` (set via `[navigator setAdapter:...]` in AppDelegate).
Add a branch to its `getPageConfig:` returning your page's config dict.

```objc
- (NSDictionary *)getPageConfig:(NSString *)pageName {
    if ([pageName isEqualToString:@"MyPage"]) {
        return @{
            @"pageName": @"MyPage",
            @"class":    @"MyPageController",   // NSClassFromString target
            @"title":    @"My Page",
            // optional:
            @"tabbar_name": @"MyTabBar",        // attach to a tab bar
            @"singleton":   @YES                // YES: reuse instance; NO: new each push
        };
    }
    // ... other pages
    return nil;
}
```

`generateFusionPageController:` then instantiates the class:
`[[NSClassFromString(config[@"class"]) alloc] initWithConfig:config]`.

### 3. Navigate to it

See the `fusion-navigate-page` skill. Quick version:

```objc
FusionPageMessage *msg = [[FusionPageMessage alloc]
    initWithPageName:@"MyPage" pageNick:nil command:@"init" args:@{} callback:nil];
[[self getNavigator] gotoPage:msg];
```

## Reference (verified against this repo)

- Base class: `FusionUI/FusionUI/FusionPageController.h`
- Adapter protocol: `IFusionPageAdapterProtocol` in `FusionUI/FusionUI/Navigation/FusionPageNavigator.h`
- Working example: `TestApp/TestApp/TestAPageController.{h,m}` + `TestApp/TestApp/TestAdapter.m`

## Notes

- **Two ways to provide page config**, both producing the same config dict the navigator
  consumes:
  - **Adapter** (`getPageConfig:`): return the dict in code, as shown above. The demo app
    (`TestAdapter.m`) uses this — simplest for a small app.
  - **Lua** (`{Module}/Script/Page/MyPage.lua`): `Page.new(name, class, trackName)`,
    `page:addCommand(...)`, `register_page(page)`. `Workspace/MacroMaker.lua` reads these
    tables to emit `*_PAGE` name constants into `TRIPPageMacro.h` **and** bundle the scripts
    into `config.zip` (loaded at runtime via `LuaScriptManager`). The Lua table carries full
    page attributes — class, commands, `trackName`, H5 host URLs — not just the name.
- `singleton: @YES` reuses one controller instance across pushes; omit or set `@NO` for a
  fresh instance each time.
