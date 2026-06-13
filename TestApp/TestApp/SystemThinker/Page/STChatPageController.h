//
//  STChatPageController.h
//  SystemThinker
//
//  对话主界面（FusionPageController 子类）。
//  组装 FusionNativeMessage 投递 CozeService，回调更新列表/上下文卡片/会话状态。
//

#import <FusionUI/FusionUI.h>

@interface STChatPageController : FusionPageController <UITableViewDataSource, UITableViewDelegate, UITextViewDelegate>
@end
