//
//  WebViewBubble.m
//  WebViewKit
//

#import "WebViewBubble.h"
#import "WKWebViewPool.h"

static NSString *const kHeightHandler = @"heightHandler";

@interface WebViewBubble () <WKNavigationDelegate, WKScriptMessageHandler>
@property (nonatomic, strong) WKWebView *webView;
@property (nonatomic, assign) CGFloat contentHeight;
@property (nonatomic, assign) BOOL loaded;
@property (nonatomic, copy)   NSString *pendingMarkdown;   // 载入完成前暂存
@property (nonatomic, assign) BOOL pendingTypewriter;
@end

@implementation WebViewBubble

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        _webView = [[WKWebViewPool sharedPool] dequeueWebView];
        _webView.navigationDelegate = self;
        // 复用的 WebView 可能残留旧 handler，先移除再加
        @try { [_webView.configuration.userContentController removeScriptMessageHandlerForName:kHeightHandler]; } @catch (__unused NSException *e) {}
        [_webView.configuration.userContentController addScriptMessageHandler:self name:kHeightHandler];
        _webView.frame = self.bounds;
        _webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self addSubview:_webView];
        [self loadTemplate];
    }
    return self;
}

- (void)loadTemplate {
    NSBundle *res = [self resourceBundle];
    NSString *htmlPath = [res pathForResource:@"bubble" ofType:@"html"];
    NSString *html = [NSString stringWithContentsOfFile:htmlPath encoding:NSUTF8StringEncoding error:nil];
    if (html) {
        [_webView loadHTMLString:html baseURL:[NSURL fileURLWithPath:[htmlPath stringByDeletingLastPathComponent] isDirectory:YES]];
    }
}

- (NSBundle *)resourceBundle {
    // pod resource_bundles 产物：WebViewKitResource.bundle
    NSBundle *main = [NSBundle bundleForClass:[self class]];
    NSURL *url = [main URLForResource:@"WebViewKitResource" withExtension:@"bundle"];
    if (url) {
        NSBundle *b = [NSBundle bundleWithURL:url];
        if (b) return b;
    }
    return main;
}

#pragma mark - 对外接口

- (void)setMarkdown:(NSString *)markdown {
    if (!_loaded) {
        _pendingMarkdown = markdown;
        _pendingTypewriter = NO;
        return;
    }
    [self callJS:@"setMarkdown" arg:markdown];
}

- (void)typeToMarkdown:(NSString *)markdown {
    if (!_loaded) {
        _pendingMarkdown = markdown;
        _pendingTypewriter = YES;
        return;
    }
    [self callJS:@"typeTo" arg:markdown];
}

- (void)finishTyping {
    if (!_loaded) return;
    [_webView evaluateJavaScript:@"STBubble.finish();" completionHandler:nil];
}

- (void)callJS:(NSString *)func arg:(NSString *)arg {
    NSData *json = [NSJSONSerialization dataWithJSONObject:@[arg ?: @""] options:0 error:nil];
    NSString *jsonArr = [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding];
    // 用 JSON 数组安全转义参数：STBubble.func.apply(null, [arg])
    NSString *js = [NSString stringWithFormat:@"STBubble.%@.apply(null, %@);", func, jsonArr];
    [_webView evaluateJavaScript:js completionHandler:nil];
}

- (void)recycle {
    @try { [_webView.configuration.userContentController removeScriptMessageHandlerForName:kHeightHandler]; } @catch (__unused NSException *e) {}
    [[WKWebViewPool sharedPool] recycleWebView:_webView];
    _webView = nil;
}

#pragma mark - WKNavigationDelegate

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    _loaded = YES;
    if (_pendingMarkdown) {
        if (_pendingTypewriter) {
            [self callJS:@"typeTo" arg:_pendingMarkdown];
        } else {
            [self callJS:@"setMarkdown" arg:_pendingMarkdown];
        }
        _pendingMarkdown = nil;
    }
}

#pragma mark - WKScriptMessageHandler

- (void)userContentController:(WKUserContentController *)userContentController
      didReceiveScriptMessage:(WKScriptMessage *)message {
    if ([message.name isEqualToString:kHeightHandler]) {
        CGFloat h = [message.body doubleValue];
        if (h > 0 && fabs(h - _contentHeight) > 0.5) {
            _contentHeight = h;
            if ([self.delegate respondsToSelector:@selector(webViewBubble:didUpdateContentHeight:)]) {
                [self.delegate webViewBubble:self didUpdateContentHeight:h];
            }
        }
    }
}

- (void)dealloc {
    if (_webView) {
        @try { [_webView.configuration.userContentController removeScriptMessageHandlerForName:kHeightHandler]; } @catch (__unused NSException *e) {}
        [[WKWebViewPool sharedPool] recycleWebView:_webView];
    }
}

@end
