//
//  NetNormalActor.h
//  Trip2013
//
//  Created by 淘中天 on 13-11-25.
//  Copyright (c) 2013年 alibaba. All rights reserved.
//

#import <FusionCore/FusionCore.h>

@class AFHTTPSessionManager;

@interface NetNormalActor : FusionActor {
@protected
    AFHTTPSessionManager*   _manager;
    NSMutableDictionary*    _taskDic;   // message 指针(NSValue) -> NSURLSessionDataTask
}

@end
