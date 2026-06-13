//
//  STMessageCell.m
//  SystemThinker
//

#import "STMessageCell.h"
#import <WebViewKit/WebViewKit.h>

static const CGFloat kBubbleMaxWidthRatio = 0.76;
static const CGFloat kBubblePaddingH = 12.0;
static const CGFloat kBubblePaddingV = 9.0;
static const CGFloat kSideMargin = 12.0;
static const CGFloat kVerticalMargin = 6.0;
static const CGFloat kWebBubblePadding = 12.0;  // WebView 气泡内边距

@interface STMessageCell () <WebViewBubbleDelegate>
@property (nonatomic, strong) UIView *bubbleView;
@property (nonatomic, strong) UITextView *userTextView;   // 用户气泡（纯文本）
@property (nonatomic, strong) WebViewBubble *webBubble;    // 助手气泡（WebView）
@property (nonatomic, assign) BOOL isUserBubble;
@property (nonatomic, copy)   NSString *currentMessageId;
@property (nonatomic, assign) CGFloat measuredWebHeight;
@end

@implementation STMessageCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.contentView.backgroundColor = [UIColor clearColor];
        self.selectionStyle = UITableViewCellSelectionStyleNone;

        _bubbleView = [UIView new];
        _bubbleView.layer.cornerRadius = 14.0;
        _bubbleView.clipsToBounds = YES;
        [self.contentView addSubview:_bubbleView];
    }
    return self;
}

#pragma mark - 宽度

+ (CGFloat)bubbleContentWidthForTableWidth:(CGFloat)width {
    CGFloat maxBubbleWidth = width * kBubbleMaxWidthRatio;
    return maxBubbleWidth - 2 * kWebBubblePadding;
}

#pragma mark - 配置

- (void)configureWithMessage:(STMessage *)message typewriter:(BOOL)isTypewriter {
    self.isUserBubble = (message.role == STMessageRoleUser);
    self.currentMessageId = message.messageId;

    if (self.isUserBubble) {
        [self teardownWebBubble];
        self.bubbleView.backgroundColor = [UIColor systemBlueColor];
        [self ensureUserTextView];
        self.userTextView.hidden = NO;
        NSMutableParagraphStyle *p = [NSMutableParagraphStyle new];
        p.lineSpacing = 2;
        self.userTextView.attributedText = [[NSAttributedString alloc] initWithString:(message.content ?: @"")
            attributes:@{NSFontAttributeName: [UIFont systemFontOfSize:16],
                         NSForegroundColorAttributeName: [UIColor whiteColor],
                         NSParagraphStyleAttributeName: p}];
    } else {
        self.userTextView.hidden = YES;
        self.bubbleView.backgroundColor = [UIColor secondarySystemBackgroundColor];
        [self ensureWebBubble];
        if (isTypewriter) {
            [self.webBubble typeToMarkdown:message.content ?: @""];
        } else {
            [self.webBubble setMarkdown:message.content ?: @""];
        }
    }
    [self setNeedsLayout];
}

- (void)ensureUserTextView {
    if (_userTextView) return;
    _userTextView = [UITextView new];
    _userTextView.editable = NO;
    _userTextView.scrollEnabled = NO;
    _userTextView.backgroundColor = [UIColor clearColor];
    _userTextView.textContainerInset = UIEdgeInsetsZero;
    _userTextView.textContainer.lineFragmentPadding = 0;
    [_bubbleView addSubview:_userTextView];
}

- (void)ensureWebBubble {
    if (_webBubble) return;
    _webBubble = [[WebViewBubble alloc] initWithFrame:CGRectZero];
    _webBubble.delegate = self;
    [_bubbleView addSubview:_webBubble];
}

- (void)teardownWebBubble {
    if (_webBubble) {
        [_webBubble recycle];
        [_webBubble removeFromSuperview];
        _webBubble = nil;
    }
}

#pragma mark - 布局

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat contentW = CGRectGetWidth(self.contentView.bounds);
    if (contentW <= 0) return;

    CGFloat maxBubbleWidth = contentW * kBubbleMaxWidthRatio;

    if (self.isUserBubble) {
        CGFloat maxTextWidth = maxBubbleWidth - 2 * kBubblePaddingH;
        CGSize textSize = [self.userTextView.attributedText boundingRectWithSize:CGSizeMake(maxTextWidth, CGFLOAT_MAX)
            options:(NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading) context:nil].size;
        CGFloat bubbleW = MIN(maxBubbleWidth, ceil(textSize.width) + 2 * kBubblePaddingH);
        CGFloat bubbleH = ceil(textSize.height) + 2 * kBubblePaddingV;
        CGFloat bubbleX = contentW - kSideMargin - bubbleW;
        self.bubbleView.frame = CGRectMake(bubbleX, kVerticalMargin, bubbleW, bubbleH);
        self.userTextView.frame = CGRectMake(kBubblePaddingH, kBubblePaddingV,
                                             bubbleW - 2 * kBubblePaddingH, ceil(textSize.height));
    } else {
        CGFloat bubbleW = maxBubbleWidth;
        CGFloat webH = MAX(self.measuredWebHeight, 20.0);
        CGFloat bubbleH = webH + 2 * kWebBubblePadding;
        self.bubbleView.frame = CGRectMake(kSideMargin, kVerticalMargin, bubbleW, bubbleH);
        self.webBubble.frame = CGRectMake(kWebBubblePadding, kWebBubblePadding,
                                          bubbleW - 2 * kWebBubblePadding, webH);
    }
}

#pragma mark - 高度

+ (CGFloat)userBubbleHeightForMessage:(STMessage *)message width:(CGFloat)width {
    if (width <= 0) return 44.0;
    CGFloat maxTextWidth = width * kBubbleMaxWidthRatio - 2 * kBubblePaddingH;
    NSMutableParagraphStyle *p = [NSMutableParagraphStyle new];
    p.lineSpacing = 2;
    NSAttributedString *attr = [[NSAttributedString alloc] initWithString:(message.content ?: @"")
        attributes:@{NSFontAttributeName: [UIFont systemFontOfSize:16],
                     NSParagraphStyleAttributeName: p}];
    CGSize size = [attr boundingRectWithSize:CGSizeMake(maxTextWidth, CGFLOAT_MAX)
        options:(NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading) context:nil].size;
    return ceil(size.height) + 2 * kBubblePaddingV + 2 * kVerticalMargin;
}

#pragma mark - WebViewBubbleDelegate

- (void)webViewBubble:(WebViewBubble *)bubble didUpdateContentHeight:(CGFloat)height {
    self.measuredWebHeight = height;
    [self setNeedsLayout];
    if ([self.delegate respondsToSelector:@selector(messageCell:didMeasureHeight:forMessageId:)]) {
        // 上报"整行高度" = WebView 内容高 + 气泡内边距 + 行间距
        CGFloat rowHeight = height + 2 * kWebBubblePadding + 2 * kVerticalMargin;
        [self.delegate messageCell:self didMeasureHeight:rowHeight forMessageId:self.currentMessageId];
    }
}

- (void)prepareForReuse {
    [super prepareForReuse];
    self.measuredWebHeight = 0;
}

- (void)dealloc {
    [self teardownWebBubble];
}

@end
