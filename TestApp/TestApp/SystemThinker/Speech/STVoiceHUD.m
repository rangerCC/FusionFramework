//
//  STVoiceHUD.m
//  SystemThinker
//

#import "STVoiceHUD.h"

@interface STVoiceHUD () {
    UIView   *_panel;
    UILabel  *_iconLabel;
    UILabel  *_hintLabel;
    UILabel  *_previewLabel;
}
@end

@implementation STVoiceHUD

- (void)showInView:(UIView *)container {
    if (_panel == nil) {
        _panel = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 160, 160)];
        _panel.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.75];
        _panel.layer.cornerRadius = 14;

        _iconLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 28, 160, 48)];
        _iconLabel.textAlignment = NSTextAlignmentCenter;
        _iconLabel.font = [UIFont systemFontOfSize:40];
        _iconLabel.text = @"🎤";
        [_panel addSubview:_iconLabel];

        _previewLabel = [[UILabel alloc] initWithFrame:CGRectMake(8, 80, 144, 34)];
        _previewLabel.textAlignment = NSTextAlignmentCenter;
        _previewLabel.font = [UIFont systemFontOfSize:13];
        _previewLabel.textColor = [UIColor whiteColor];
        _previewLabel.numberOfLines = 2;
        [_panel addSubview:_previewLabel];

        _hintLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 122, 160, 26)];
        _hintLabel.textAlignment = NSTextAlignmentCenter;
        _hintLabel.font = [UIFont systemFontOfSize:13];
        _hintLabel.textColor = [UIColor whiteColor];
        [_panel addSubview:_hintLabel];
    }
    _panel.center = CGPointMake(container.bounds.size.width / 2, container.bounds.size.height / 2 - 40);
    [container addSubview:_panel];
    [self setCancelHighlighted:NO];
    [self updateText:@""];
}

- (void)setCancelHighlighted:(BOOL)cancel {
    if (cancel) {
        _panel.backgroundColor = [[UIColor systemRedColor] colorWithAlphaComponent:0.85];
        _iconLabel.text = @"✕";
        _hintLabel.text = @"松开手指，取消";
    } else {
        _panel.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.75];
        _iconLabel.text = @"🎤";
        _hintLabel.text = @"上滑取消 · 松开发送";
    }
}

- (void)updateText:(NSString *)recognizingText {
    _previewLabel.text = recognizingText ?: @"";
}

- (void)hide {
    [_panel removeFromSuperview];
}

@end
