---
name: fusion-call-service
description: Send a message to a Service/Actor in the FusionFramework message system and handle the result — building a FusionNativeMessage, sending via asyncSendMessage, reading the dataTable result, and observing the completion notification. Use when invoking existing backend logic or dispatching work to an actor.
---

# Call a Fusion Service (send a message)

You invoke an Actor by sending a `FusionNativeMessage` to `FusionCore`. Results come back
through the message's dataTable; completion is delivered via a notification on the thread
that sent the message.

## 1. Build and send a message

```objc
#import <FusionCore/FusionCore.h>

FusionNativeMessage *msg = [[FusionNativeMessage alloc]
    initWithSerivice:@"myService"     // service name (note original spelling: "Serivice")
               actor:@"myActor"       // actor name within that service
                args:@{@"key": @"value"}];

[[FusionCore getInstance] asyncSendMessage:msg];
```

`FusionCore` routes the message to the service's thread (worker pool / network / main per the
service's `thread_type`), instantiates/reuses the actor, and calls
`processFusionNativeMessage:`.

Optional delayed dispatch:

```objc
msg.delay = 5.0;                       // seconds
[[FusionCore getInstance] asyncSendMessage:msg];
```

## 2. Receive the result

When the actor sets the message state to `FusionNativeMessageFinish` or
`FusionNativeMessageFailed`, the framework posts `FusionNativeMessageNotification`
(with the message as `object`) **on the originating thread**. Observe it:

```objc
[[NSNotificationCenter defaultCenter]
    addObserver:self
       selector:@selector(onFusionMessage:)
           name:FusionNativeMessageNotification
         object:msg];          // pass the specific msg to filter, or nil for all
```

```objc
- (void)onFusionMessage:(NSNotification *)note {
    FusionNativeMessage *message = note.object;
    if (message.state == FusionNativeMessageFinish) {
        id result = [message getValueFromDataTableWith:@"resultKey"];
        // use result
    } else if (message.state == FusionNativeMessageFailed) {
        // inspect error keys the actor wrote (see actor's contract)
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self
        name:FusionNativeMessageNotification object:message];
}
```

## 3. Cancel an in-flight message

```objc
[[FusionCore getInstance] asyncCancelMessage:msg];
```

## Sub-messages (parallel fan-out)

An actor can spawn child messages; the parent auto-completes when all children finish.
Inside an actor's `processFusionNativeMessage:`:

```objc
FusionNativeMessage *child = [[FusionNativeMessage alloc]
    initWithSerivice:@"svc" actor:@"act" args:childArgs];
[parentMsg insertSubMessage:child];
[[FusionCore getInstance] asyncSendMessage:child];
```

Handle aggregation in the parent actor's
`processCallbackMessage:ParentMessage:` (base behavior: parent finishes when child count
reaches 0).

## Reference (verified against this repo)

- `FusionCore/FusionCore/FusionCoreEx.h` — `asyncSendMessage:`, `asyncCancelMessage:`,
  `getInstance`
- `FusionCore/FusionCore/FusionNativeMessage.{h,m}` — `initWithSerivice:actor:args:`,
  dataTable accessors, `FusionNativeMessageNotification`, state constants
- Result delivery posts `FusionNativeMessageNotification` from
  `processFusionNativeMessageCallback:` on the origin thread.

## Notes

- The initializer selector is `initWithSerivice:actor:args:` — "Serivice" is the original
  (misspelled) API name; use it verbatim.
- The completion notification fires only for top-level messages (those without a parent);
  child messages route their callbacks to the parent actor instead.
- To target a network actor (e.g. HTTP GET/download), prefer the higher-level
  `fusion-network-request` skill, which documents the standard arg/result keys.
