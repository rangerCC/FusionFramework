//
//  STVoiceHUD.h
//  SystemThinker
//
//  「按住说话」录音浮层：居中显示，正常态(松开发送)/取消态(上滑取消)。
//

#import <UIKit/UIKit.h>

@interface STVoiceHUD : NSObject

// 在指定 window 上显示/更新/隐藏
- (void)showInView:(UIView *)container;
- (void)setCancelHighlighted:(BOOL)cancel;  // YES=上滑取消态
- (void)updateText:(NSString *)recognizingText;  // 实时识别文本预览
- (void)hide;

@end
