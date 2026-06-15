//
//  DownloadFileActor.h
//  Trip2013
//
//  Created by 淘中天 on 13-11-26.
//  Copyright (c) 2013年 alibaba. All rights reserved.
//

#import <FusionCore/FusionCore.h>

@class AFURLSessionManager;

@interface DownloadFileActor : FusionActor {
@protected
    AFURLSessionManager*    _manager;
    NSMutableDictionary*    _clusterDic;   // url(NSString) -> DownloadFileCluster
    NSMutableDictionary*    _taskDic;      // cluster 指针(NSValue) -> NSURLSessionDownloadTask
}

@end
