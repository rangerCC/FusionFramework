//
//  STMessageCell.h
//  SystemThinker
//
//  对话气泡 cell：
//   - 用户气泡（右，纯文本，UITextView）
//   - 助手气泡（左，WebView 渲染 Markdown/表格，支持打字机）
//  WebView 高度异步回传，通过 delegate 通知外部刷新行高。
//

#import <UIKit/UIKit.h>
#import "STModels.h"

@class STMessageCell;

@protocol STMessageCellDelegate <NSObject>
// 助手气泡 WebView 内容高度变化（带 messageId 以便定位行）
- (void)messageCell:(STMessageCell *)cell didMeasureHeight:(CGFloat)height forMessageId:(NSString *)messageId;
@end

@interface STMessageCell : UITableViewCell

@property (nonatomic, weak) id<STMessageCellDelegate> delegate;

// 配置气泡内容；isTypewriter=YES 时助手气泡走打字机推进
- (void)configureWithMessage:(STMessage *)message typewriter:(BOOL)isTypewriter;

// 用户气泡纯文本高度（同步可算）
+ (CGFloat)userBubbleHeightForMessage:(STMessage *)message width:(CGFloat)width;

// 内容横向可用宽度（气泡内 WebView 宽度），供外部建 WebView 尺寸参考
+ (CGFloat)bubbleContentWidthForTableWidth:(CGFloat)width;

@end
