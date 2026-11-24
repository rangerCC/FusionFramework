//
//  PCFusionPipelineTests.m
//  PhotoCleanerTests
//
//  Acceptance test for task M0-03: a message sent through FusionCore reaches
//  the actor configured in Lua (config.zip) and the completion notification
//  arrives on the sending thread with state Finish.
//

#import <XCTest/XCTest.h>
#import <FusionCore/FusionCore.h>
#import <PhotoClean/PhotoClean.h>
#import "TRIPServiceMacro.h"

@interface PCFusionPipelineTests : XCTestCase
@end

@implementation PCFusionPipelineTests

- (FusionNativeMessage *)sendAndWait:(FusionNativeMessage *)message {
    __block FusionNativeMessage *received = nil;
    __block BOOL onMain = NO;
    XCTestExpectation *done = [self expectationWithDescription:@"message finished"];
    id token = [[NSNotificationCenter defaultCenter] addObserverForName:FusionNativeMessageNotification
                                                                 object:nil
                                                                  queue:nil
                                                             usingBlock:^(NSNotification *note) {
        if (note.object != message) return;
        received = note.object;
        onMain = [NSThread isMainThread];
        [done fulfill];
    }];
    [[FusionCore getInstance] asyncSendMessage:message];
    [self waitForExpectations:@[done] timeout:5];
    [[NSNotificationCenter defaultCenter] removeObserver:token];
    XCTAssertTrue(onMain, @"notification must be delivered on the sending (main) thread");
    return received;
}

- (void)testPingFinishesOnWorkerThread {
    FusionNativeMessage *msg = [[FusionNativeMessage alloc] initWithSerivice:DIAGNOSTICSERVICE_SERVICE
                                                                       actor:PINGACTOR_ACTOR
                                                                        args:@{PCPingPayloadKey: @"hello"}];
    FusionNativeMessage *result = [self sendAndWait:msg];
    XCTAssertEqual(result.state, (NSUInteger)FusionNativeMessageFinish);
    XCTAssertEqualObjects([result getValueFromDataTableWith:PCPingResultKey], @"hello");
    XCTAssertNotEqualObjects([result getValueFromDataTableWith:PCPingThreadKey], @"main",
                             @"thread_type 0 services must run on the worker pool");
}

- (void)testPingWithoutPayloadFails {
    FusionNativeMessage *msg = [[FusionNativeMessage alloc] initWithSerivice:DIAGNOSTICSERVICE_SERVICE
                                                                       actor:PINGACTOR_ACTOR
                                                                        args:@{}];
    FusionNativeMessage *result = [self sendAndWait:msg];
    XCTAssertEqual(result.state, (NSUInteger)FusionNativeMessageFailed);
}

@end
