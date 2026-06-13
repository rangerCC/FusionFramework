//
//  STDefines.h
//  SystemThinker
//
//  系统思维助手 - 全局常量定义
//

#ifndef STDefines_h
#define STDefines_h

#pragma mark - Coze 接口

// Coze 工作流流式接口地址（SSE）
#define kCozeStreamURL          @"https://57pqs4yq6k.coze.site/stream_run"
// Coze 接口鉴权 Token（生产环境应从安全存储注入，勿硬编码进仓库明文）
#define kCozeAuthToken          @"eyJhbGciOiJSUzI1NiIsImtpZCI6ImQ1MmFkYzEyLTliNmYtNGIwNi05OTBmLWY5MmRjMWQyNTQwNyJ9.eyJpc3MiOiJodHRwczovL2FwaS5jb3plLmNuIiwiYXVkIjpbIlNEODlqRE04SXFBMHQ4enM4ejNGOTlYV2o0cFJVREdFIl0sImV4cCI6ODIxMDI2Njg3Njc5OSwiaWF0IjoxNzgxMTkzMTI4LCJzdWIiOiJzcGlmZmU6Ly9hcGkuY296ZS5jbi93b3JrbG9hZF9pZGVudGl0eS9pZDo3NjUwMTQxMDc2MTYxODIyNzYyIiwic3JjIjoiaW5ib3VuZF9hdXRoX2FjY2Vzc190b2tlbl9pZDo3NjUwMTY2MjM0MzU2MzgzNzU5In0.mGlv3lDMPbTCHlPk_ku8638T96ZfSdVAalBUJ9PfYg8FPh7KDEGjT5ScPiAc431DLnksqC0jzvxZrQWXyJqBuPuFOCY594QcYaejZ6aB98movRp11Wyey1PBjxNj72m8Px-XkOyOJVdKhWmrmnj02rdGxHaid7AptIYbRGspri3FNoKq-2mZHwu5ysxAGaggZ8L3sKMYWlGHlltb2OOjLgrsn48Rubf93C1-hg5Jk-61xfpT_qKIRSobBK1OxvqztLsd4SacOxT1tLfU-jjY2Qb9RNlM2xrSB1QR-S1PbZ6K7PYgo19hLt6uCX5BLv2cC34dFATdl9IUFUu1U_cflA"
// 接口超时（秒）—— Coze 工作流响应较慢
#define kCozeTimeout            60

#pragma mark - 消息 args / dataTable 键

// 入参键
#define ST_ARG_USER_INPUT       @"user_input"
#define ST_ARG_SESSION_CONTEXT  @"session_context"
#define ST_ARG_OUTPUT_LEVEL     @"output_level"
#define ST_ARG_IS_URGENT        @"is_urgent"
// 首次调用上下文占位
#define ST_CONTEXT_NONE         @"None"

// 出参键（写回 dataTable）
#define ST_RESULT_ANALYSIS      @"analysis_result"
#define ST_RESULT_NEW_CONTEXT   @"new_context"
#define ST_RESULT_ERROR_MSG     @"error_msg"

#pragma mark - 流式进度通知

// 流式节点进度通知（object 为 FusionNativeMessage，userInfo 带 ST_PROGRESS_TEXT）
#define ST_STREAM_PROGRESS_NOTIFICATION  @"ST_STREAM_PROGRESS_NOTIFICATION"
#define ST_PROGRESS_TEXT        @"progress_text"

#pragma mark - 输出详细程度

#define ST_OUTPUT_BRIEF         @"brief"
#define ST_OUTPUT_STANDARD      @"standard"
#define ST_OUTPUT_FULL          @"full"

#pragma mark - NSUserDefaults 键

#define ST_PREF_OUTPUT_LEVEL    @"st_output_level"
#define ST_PREF_DEFAULT_URGENT  @"st_default_urgent"

#endif /* STDefines_h */
