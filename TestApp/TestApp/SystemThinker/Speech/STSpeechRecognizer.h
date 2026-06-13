//
//  STSpeechRecognizer.h
//  SystemThinker
//
//  语音识别封装：Speech(SFSpeechRecognizer) + AVAudioEngine 流式识别。
//  对外提供权限请求、开始/停止/取消，识别中文（zh-CN）。
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, STSpeechAuthStatus) {
    STSpeechAuthStatusAuthorized = 0,
    STSpeechAuthStatusDenied,        // 用户拒绝（语音或麦克风任一被拒）
    STSpeechAuthStatusUnavailable    // 设备不支持 / 语言不可用
};

@interface STSpeechRecognizer : NSObject

// 识别中实时部分结果回调（主线程）
@property (nonatomic, copy) void (^onPartialText)(NSString *text);

// 是否正在录音识别
@property (nonatomic, readonly) BOOL isRecording;

// 请求权限（语音识别 + 麦克风），结果回主线程
- (void)requestAuthorization:(void (^)(STSpeechAuthStatus status))completion;

// 开始录音识别；返回是否成功启动
- (BOOL)startRecording:(NSError **)error;

// 结束识别并返回最终文本（停止音频引擎）
- (void)stopRecordingWithCompletion:(void (^)(NSString *finalText))completion;

// 取消本次识别，丢弃结果
- (void)cancelRecording;

@end
