//
//  WebViewBubble.h
//  WebViewKit
//
//  承载一个出池 WKWebView 的容器视图，负责载入 bundle 模板、
//  暴露 setMarkdown/typeTo、回传内容高度。供聊天气泡 cell 内嵌使用。
//

#import <UIKit/UIKit.h>

@class WebViewBubble;

@protocol WebViewBubbleDelegate <NSObject>
// 内容高度变化（CSS 像素 == point），用于驱动 cell 高度刷新
- (void)webViewBubble:(WebViewBubble *)bubble didUpdateContentHeight:(CGFloat)height;
@end

@interface WebViewBubble : UIView

@property (nonatomic, weak) id<WebViewBubbleDelegate> delegate;
@property (nonatomic, readonly) CGFloat contentHeight;

// 整段渲染（历史消息）
- (void)setMarkdown:(NSString *)markdown;
// 打字机推进到目标全文
- (void)typeToMarkdown:(NSString *)markdown;
// 立即完成打字机
- (void)finishTyping;

// 归还内部 WebView 到池（cell 复用/销毁时调用）
- (void)recycle;

@end
