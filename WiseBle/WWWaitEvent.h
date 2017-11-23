//
//  WWWaitEvent.h
//  WiseBleDemo
//
//  Created by wuruizhi on 2017/4/21.
//  Copyright © 2017年 wuruizhi. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum : NSUInteger {
    WWWaitResultSuccess = 0,  //成功
    WWWaitResultFailed,       //失败
    WWWaitResultTimeOut,      //等待超时
    WWWaitResultWaiting,      //正在等待
} WWWaitResult;

@interface WWWaitEvent : NSObject

/**
 *  等待结果,直到调用waitOver，或mills（ms）后超时
 *
 *  @param mills     超时时间
 *
 *  @return 等待结果
 */
-(WWWaitResult)waitSignle:(NSUInteger) mills;


/**
 *  结束等待，并设置waitSignle返回结果
 *
 *  @param result     等待结束原因
 *
 */
-(void)waitOver:(WWWaitResult)result;


/**
 *  获取等待状态
 *
 *  @return 等待状态
 */
- (WWWaitResult)getWaitStatus;

@end
