//
//  WWWaitEvent.m
//  WiseBleDemo
//
//  Created by wuruizhi on 2017/4/21.
//  Copyright © 2017年 wuruizhi. All rights reserved.
//

#import "WWWaitEvent.h"

@interface WWWaitEvent()
{
    WWWaitResult _wResult;          //等待结果
    dispatch_semaphore_t _semaphore;
}

@end

@implementation WWWaitEvent

-(id)init
{
    self = [super init];
    if (self != nil) {
        
        //创建信号量
        _semaphore = dispatch_semaphore_create(0);
        
    }
    
    return self;
}


/**
 *  等待结果,直到调用waitOver，或mills（ms）后超时
 *
 *  @param mills     超时时间
 *
 *  @return 等待结果
 */
-(WWWaitResult)waitSignle:(NSUInteger) mills
{
    WWWaitResult result;
    
    //创建信号量
    _semaphore = dispatch_semaphore_create(0);
    
    //线程同步
    @synchronized(self)
    {
        _wResult = WWWaitResultWaiting;
    }
    
    dispatch_time_t time = dispatch_time ( DISPATCH_TIME_NOW , mills * NSEC_PER_MSEC ) ;
    //信号等待,不为0表示超时
    if ( dispatch_semaphore_wait(_semaphore, time) != 0 ){
        [self waitTimeOut];
    }
    
    @synchronized(self)
    {
        result = _wResult;
    }
    
    return result;
}


/**
 *  结束等待，并设置waitSignle返回结果
 *
 *  @param result     等待结束原因
 *
 */
-(void)waitOver:(WWWaitResult)result
{
    //线程同步
    @synchronized(self)
    {
        _wResult = result;
    }
    
    dispatch_semaphore_signal(_semaphore);
}

/**
 *  获取等待状态
 *
 *  @return 等待状态
 */
- (WWWaitResult)getWaitStatus
{
    WWWaitResult result = WWWaitResultSuccess;
    //线程同步
    @synchronized(self)
    {
        result = _wResult;
    }
    
    return result;
}


//超时
-(void)waitTimeOut
{
    [self waitOver:WWWaitResultTimeOut];
}

@end
