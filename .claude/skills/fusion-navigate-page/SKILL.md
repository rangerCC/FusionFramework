---
name: fusion-navigate-page
description: Navigate between pages in a FusionFramework iOS app — push, pop, switch, or open a page using FusionPageMessage and FusionPageNavigator (gotoPage/openPage/poptoPage), including passing args, callbacks, and transition animations. Use when wiring screen-to-screen navigation.
---

# Navigate Between Fusion Pages

Navigation is driven by `FusionPageMessage` objects sent to a `FusionPageNavigator`.
A page controller reaches the navigator via `[self getNavigator]`.

## Build a page message

```objc
FusionPageMessage *msg = [[FusionPageMessage alloc]
    initWithPageName:@"TargetPage"   // must match a name your Adapter resolves
            pageNick:nil             // optional instance nickname
             command:@"init"         // command delivered to processPageCommand:args:
                args:@{@"key": @"value"}
            callback:nil];           // optional NSURL (see callbacks below)
```

Optional transition animation:

```objc
[msg setNaviAnimeType:SlideR2L_NaviAnime];   // see FusionPageNavigator+NaviAnime.h for types
```

## Navigator methods

On `FusionPageNavigator` (auto-managed transitions, in `+Auto` category):

```objc
[[self getNavigator] gotoPage:msg];     // push / go to a page
[[self getNavigator] openPage:msg];     // open a page
[[self getNavigator] poptoPage:msg];    // pop back to a page
```

For caller-managed transitions, the `+Manual` category returns a `FusionNaviAnime`:
`manualGotoPage:` / `manualOpenPage:` / `manualPoptoPage:`.

## Callbacks (returning data to the previous page)

The `callback` parameter is an **`NSURL`** (not a block). Generate one for the current
controller, attach params and a `#command` fragment; when the opened page finishes, the
framework delivers that command back to the originating page's `processPageCommand:args:`.

```objc
NSURL *cb = [FusionPageNavigator generateCallbackUrl:self];
NSString *merged = [NSURL mergeUrl:[cb absoluteString]
                        withParams:@{@"args": [@{@"a": @1} jsonString]}];
cb = [NSURL URLWithString:[NSString stringWithFormat:@"%@#back", merged]];

FusionPageMessage *msg = [[FusionPageMessage alloc]
    initWithPageName:@"TargetPage" pageNick:nil command:nil
                args:@{} callback:cb];
[[self getNavigator] gotoPage:msg];
```

The target page later triggers the callback; the source page receives `command == @"back"`.

## App root setup (AppDelegate)

```objc
_navigator = [FusionPageNavigator new];
[_navigator setRewriter:nil];
[_navigator setAdapter:[MyAdapter getInstance]];   // resolves page configs
[self.window setRootViewController:_navigator];

FusionPageMessage *home = [[FusionPageMessage alloc]
    initWithPageName:@"HomePage" pageNick:nil command:@"init" args:@{} callback:nil];
[_navigator gotoPage:home];
```

## Reference (verified against this repo)

- `FusionUI/FusionUI/Navigation/FusionPageMessage.h`
- `FusionUI/FusionUI/Navigation/FusionPageNavigator+Auto.h` (gotoPage/openPage/poptoPage)
- `FusionUI/FusionUI/Navigation/FusionPageNavigator+Manual.h`
- Working example: `TestApp/TestApp/AppDelegate.m`, `TestApp/TestApp/TestAPageController.m`

## Notes

- The target `pageName` must be resolvable by the navigator's Adapter — see the
  `fusion-create-page` skill.
- Animation type constants live in `FusionPageNavigator+NaviAnime.h`.
