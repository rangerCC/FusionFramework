//
//  STSpeechRecognizer.m
//  SystemThinker
//

#import "STSpeechRecognizer.h"
#import <Speech/Speech.h>
#import <AVFoundation/AVFoundation.h>

@interface STSpeechRecognizer () <SFSpeechRecognizerDelegate> {
    SFSpeechRecognizer                  *_recognizer;
    SFSpeechAudioBufferRecognitionRequest *_request;
    SFSpeechRecognitionTask             *_task;
    AVAudioEngine                       *_audioEngine;
    NSString                            *_latestText;
    BOOL                                _isRecording;
}
@end

@implementation STSpeechRecognizer

- (instancetype)init {
    self = [super init];
    if (self) {
        _recognizer = [[SFSpeechRecognizer alloc] initWithLocale:[NSLocale localeWithLocaleIdentifier:@"zh-CN"]];
        _audioEngine = [[AVAudioEngine alloc] init];
        _latestText = @"";
    }
    return self;
}

- (BOOL)isRecording {
    return _isRecording;
}

#pragma mark - 权限

- (void)requestAuthorization:(void (^)(STSpeechAuthStatus))completion {
    // 1. 语音识别权限
    [SFSpeechRecognizer requestAuthorization:^(SFSpeechRecognizerAuthorizationStatus speechStatus) {
        if (speechStatus != SFSpeechRecognizerAuthorizationStatusAuthorized) {
            [self callOnMain:completion status:STSpeechAuthStatusDenied];
            return;
        }
        // 2. 麦克风权限
        [[AVAudioSession sharedInstance] requestRecordPermission:^(BOOL granted) {
            if (!granted) {
                [self callOnMain:completion status:STSpeechAuthStatusDenied];
            } else if (self->_recognizer == nil || !self->_recognizer.isAvailable) {
                [self callOnMain:completion status:STSpeechAuthStatusUnavailable];
            } else {
                [self callOnMain:completion status:STSpeechAuthStatusAuthorized];
            }
        }];
    }];
}

- (void)callOnMain:(void (^)(STSpeechAuthStatus))completion status:(STSpeechAuthStatus)status {
    if (!completion) return;
    dispatch_async(dispatch_get_main_queue(), ^{ completion(status); });
}

#pragma mark - 录音识别

- (BOOL)startRecording:(NSError **)error {
    if (_isRecording) return YES;
    _latestText = @"";

    // 配置音频会话
    AVAudioSession *session = [AVAudioSession sharedInstance];
    if (![session setCategory:AVAudioSessionCategoryRecord
                         mode:AVAudioSessionModeMeasurement
                      options:AVAudioSessionCategoryOptionDuckOthers
                        error:error]) {
        return NO;
    }
    if (![session setActive:YES withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:error]) {
        return NO;
    }

    _request = [[SFSpeechAudioBufferRecognitionRequest alloc] init];
    _request.shouldReportPartialResults = YES;

    AVAudioInputNode *inputNode = _audioEngine.inputNode;
    __weak typeof(self) weakSelf = self;
    _task = [_recognizer recognitionTaskWithRequest:_request
                                       resultHandler:^(SFSpeechRecognitionResult *result, NSError *err) {
        __strong typeof(weakSelf) self = weakSelf;
        if (self == nil) return;
        if (result) {
            self->_latestText = result.bestTranscription.formattedString ?: @"";
            if (self.onPartialText) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.onPartialText(self->_latestText);
                });
            }
        }
    }];

    AVAudioFormat *format = [inputNode outputFormatForBus:0];
    [inputNode installTapOnBus:0 bufferSize:1024 format:format
                         block:^(AVAudioPCMBuffer *buffer, AVAudioTime *when) {
        [weakSelf appendBuffer:buffer];
    }];

    [_audioEngine prepare];
    if (![_audioEngine startAndReturnError:error]) {
        [self teardown];
        return NO;
    }
    _isRecording = YES;
    return YES;
}

- (void)appendBuffer:(AVAudioPCMBuffer *)buffer {
    [_request appendAudioPCMBuffer:buffer];
}

- (void)stopRecordingWithCompletion:(void (^)(NSString *))completion {
    if (!_isRecording) {
        if (completion) completion(@"");
        return;
    }
    [self teardown];
    // 给识别引擎一点时间产出最终结果
    NSString *text = _latestText ?: @"";
    if (completion) {
        dispatch_async(dispatch_get_main_queue(), ^{ completion(text); });
    }
}

- (void)cancelRecording {
    if (!_isRecording) return;
    [self teardown];
    _latestText = @"";
}

- (void)teardown {
    _isRecording = NO;
    if (_audioEngine.isRunning) {
        [_audioEngine stop];
        [_audioEngine.inputNode removeTapOnBus:0];
    }
    [_request endAudio];
    [_task cancel];
    _request = nil;
    _task = nil;
    // 释放音频会话（忽略错误）
    [[AVAudioSession sharedInstance] setActive:NO
                                   withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation
                                         error:nil];
}

- (void)dealloc {
    [self teardown];
}

@end
