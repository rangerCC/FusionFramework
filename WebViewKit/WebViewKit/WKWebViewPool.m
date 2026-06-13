//
//  WKWebViewPool.m
//  WebViewKit
//

#import "WKWebViewPool.h"

@interface WKWebViewPool ()
@property (nonatomic, strong) WKProcessPool *processPool;
@property (nonatomic, strong) NSMutableArray<WKWebView *> *idleWebViews;
@end

@implementation WKWebViewPool

+ (instancetype)sharedPool {
    static WKWebViewPool *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [WKWebViewPool new];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _processPool = [WKProcessPool new];
        _idleWebViews = [NSMutableArray new];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(clear)
                                                     name:UIApplicationDidReceiveMemoryWarningNotification
                                                   object:nil];
    }
    return self;
}

- (WKWebViewConfiguration *)freshConfiguration {
    WKWebViewConfiguration *config = [WKWebViewConfiguration new];
    config.processPool = _processPool;           // 共享进程池省内存
    config.allowsInlineMediaPlayback = YES;
    config.suppressesIncrementalRendering = NO;
    return config;
}

- (WKWebView *)newWebView {
    WKWebView *wv = [[WKWebView alloc] initWithFrame:CGRectZero configuration:[self freshConfiguration]];
    wv.opaque = NO;
    wv.backgroundColor = [UIColor clearColor];
    wv.scrollView.backgroundColor = [UIColor clearColor];
    wv.scrollView.scrollEnabled = NO;            // 高度自适应，由外层列表滚动
    wv.scrollView.bounces = NO;
    return wv;
}

- (void)prewarm:(NSInteger)count {
    for (NSInteger i = 0; i < count; i++) {
        WKWebView *wv = [self newWebView];
        [_idleWebViews addObject:wv];
    }
}

- (WKWebView *)dequeueWebView {
    WKWebView *wv = [_idleWebViews lastObject];
    if (wv) {
        [_idleWebViews removeLastObject];
        return wv;
    }
    return [self newWebView];
}

- (void)recycleWebView:(WKWebView *)webView {
    if (webView == nil) return;
    [webView stopLoading];
    // 解除挂载与脚本消息处理器，载入空白页
    [webView removeFromSuperview];
    webView.navigationDelegate = nil;
    webView.UIDelegate = nil;
    [webView loadHTMLString:@"" baseURL:nil];
    if (_idleWebViews.count < 8) {               // 上限，避免无限囤积
        [_idleWebViews addObject:webView];
    }
}

- (void)clear {
    [_idleWebViews removeAllObjects];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
