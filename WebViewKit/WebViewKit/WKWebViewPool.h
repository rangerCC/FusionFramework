//
//  WKWebViewPool.h
//  WebViewKit
//
//  WKWebView 复用池：共享 WKProcessPool 省内存，预热 + 出池/回收，
//  避免聊天列表里每个气泡都新建 WebView 造成的卡顿与内存峰值。
//

#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>

@interface WKWebViewPool : NSObject

+ (instancetype)sharedPool;

// 预热 count 个 WebView（建议 App 启动或进聊天页时调用）
- (void)prewarm:(NSInteger)count;

// 取一个可复用的 WebView（池空则新建）
- (WKWebView *)dequeueWebView;

// 归还 WebView（清空内容后入池）
- (void)recycleWebView:(WKWebView *)webView;

// 清空池（内存告警时调用）
- (void)clear;

@end
