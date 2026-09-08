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
 *  注册一次等待。必须在发起异步操作前调用，每个实例只能注册一次。
 *  后续操作应创建新的 WWWaitEvent，避免旧完成信号污染新等待。
 *
 *  @return 成功true；该实例已注册过等待时返回false
 */
- (BOOL)prepareWait;

/**
 *  等待已注册操作完成。
 *
 *  @param mills 超时时间，单位ms
 *
 *  @return 等待结果
 */
- (WWWaitResult)waitPrepared:(NSUInteger)mills;

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
