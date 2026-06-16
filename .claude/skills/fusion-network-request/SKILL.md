---
name: fusion-network-request
description: Make an HTTP request or file download in a FusionFramework app through the CoreService network actors (NetNormalActor / DownloadFileActor, built on AFNetworking). Covers the standard message arg keys, result keys, and service setup. Use when fetching data over HTTP or downloading files.
---

# Network Requests via CoreService

CoreService provides two `FusionActor`s for networking, built on **AFNetworking**
(`NSURLSession`):

- `NetNormalActor` — HTTP GET/POST, returns raw `NSData`
- `DownloadFileActor` — file download to a local path, with same-URL dedupe

You drive them by sending a `FusionNativeMessage` (see `fusion-call-service`) to a service
configured on the **NET thread** (`thread_type = 1`). The standard arg/result keys are
defined in `CoreService/CoreService/Network/NetworkCommon.h`.

## 1. Register a network service (once)

In your `IFusionConfig getCoreService` (see `fusion-create-service`):

```objc
@{
    @"name":  @"netService",
    @"class": @"FusionService",
    @"thread_type": @(1),                 // FusionService_NET — required for these actors
    @"actors": @{
        @"netNormal": @{ @"class": @"NetNormalActor" },
        @"download":  @{ @"class": @"DownloadFileActor" },
    }
}
```

## 2. HTTP GET / POST

```objc
#import <FusionCore/FusionCore.h>
// arg/result key macros come from NetworkCommon.h (in CoreService)

FusionNativeMessage *msg = [[FusionNativeMessage alloc]
    initWithSerivice:@"netService"
               actor:@"netNormal"
                args:@{
        NET_REMOTE_URL:  @"https://api.example.com/data",
        NET_HTTP_METHOD: HTTP_GET_METHOD,        // or HTTP_POST_METHOD
        NET_HTTP_HEADER: @{@"Accept": @"application/json"},   // optional
        NET_HTTP_PARAMS: @{@"q": @"term"},                    // optional (GET query / POST body)
        // HTTP_DISABLE_FOLLOW: @YES,            // optional: don't auto-follow 301/302
    }];
[[FusionCore getInstance] asyncSendMessage:msg];
```

Read results in the completion notification handler (see `fusion-call-service`):

```objc
NSData    *data    = [message getValueFromDataTableWith:HTTP_RESPONSE_DATA];
NSNumber  *code    = [message getValueFromDataTableWith:HTTP_RESPONSE_CODE];   // HTTP status
NSDictionary *hdr  = [message getValueFromDataTableWith:HTTP_RESPONSE_HEADER];
NSString  *finalUrl = [message getValueFromDataTableWith:HTTP_EFFECTIVE_URL];  // if redirected
```

On failure (`message.state == FusionNativeMessageFailed`) the actor also records error info
via the `FusionNativeMessage (Error)` category (`error_domain` / `error_code` / `error_msg`
keys in the dataTable).

## 3. File download

```objc
FusionNativeMessage *msg = [[FusionNativeMessage alloc]
    initWithSerivice:@"netService"
               actor:@"download"
                args:@{
        NET_REMOTE_URL:    @"https://example.com/file.zip",
        NET_LOCAL_PATH:    localFilePath,            // destination
        // NET_TEMP_PATH:   tempPath,                // optional; defaults via FileHelper
        // NET_HTTP_HEADER: @{...},                  // optional
        // NET_FORCE_DOWNLOAD: @YES,                 // re-download even if file exists
    }];
[[FusionCore getInstance] asyncSendMessage:msg];
```

Behavior:
- If the file already exists at `NET_LOCAL_PATH` and `NET_FORCE_DOWNLOAD` is not set, it
  completes immediately (and refreshes the file's modify time).
- Concurrent requests for the same URL are deduped: one download, all messages notified.
- Results carry `HTTP_RESPONSE_CODE` and `HTTP_RESPONSE_HEADER`.

## Reference (verified against this repo)

- `CoreService/CoreService/Network/NetworkCommon.h` — all arg/result key macros
- `CoreService/CoreService/Network/NetNormalActor.{h,m}` — GET/POST (AFHTTPSessionManager)
- `CoreService/CoreService/Network/DownloadFileActor.{h,m}` — download (AFURLSessionManager)
- `CoreService/CoreService/Network/FusionNativeMessage+Error.h` — error keys
- `CoreService.podspec` — depends on `AFNetworking ~> 4.0`

## Notes

- These actors **must** run on a NET-thread service (`thread_type = 1`). AFNetworking
  completion blocks fire on the main queue; the actors marshal back to the Fusion network
  thread internally, so callers don't need to.
- Custom per-request DNS override (the old `NET_DNS_RESOLVE` from the libcurl engine) is no
  longer supported — NSURLSession has no per-request DNS override.
- NSURLSession auto-follows 301/302 unless `HTTP_DISABLE_FOLLOW` is set; the final URL is
  reported in `HTTP_EFFECTIVE_URL`.
