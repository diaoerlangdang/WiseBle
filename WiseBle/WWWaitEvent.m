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
    BOOL _needsConsumption;
    BOOL _hasPrepared;
}

@end

@implementation WWWaitEvent

-(id)init
{
    self = [super init];
    if (self != nil) {
        
        //创建信号量
        _semaphore = dispatch_semaphore_create(0);
        _wResult = WWWaitResultSuccess;
        
    }
    
    return self;
}

- (BOOL)prepareWait
{
    @synchronized(self) {
        if (_hasPrepared) {
            return NO;
        }

        _semaphore = dispatch_semaphore_create(0);
        _wResult = WWWaitResultWaiting;
        _needsConsumption = YES;
        _hasPrepared = YES;
        return YES;
    }
}

- (WWWaitResult)waitPrepared:(NSUInteger)mills
{
    dispatch_semaphore_t semaphore;
    @synchronized(self) {
        if (!_needsConsumption) {
            return _wResult;
        }
        if (_wResult != WWWaitResultWaiting) {
            WWWaitResult result = _wResult;
            _needsConsumption = NO;
            return result;
        }
        semaphore = _semaphore;
    }

    uint64_t timeout = mills > ((uint64_t)INT64_MAX / NSEC_PER_MSEC)
        ? (uint64_t)INT64_MAX
        : (uint64_t)mills * NSEC_PER_MSEC;
    dispatch_time_t time = dispatch_time(DISPATCH_TIME_NOW, (int64_t)timeout);
    if (dispatch_semaphore_wait(semaphore, time) != 0) {
        @synchronized(self) {
            if (_semaphore == semaphore && _wResult == WWWaitResultWaiting) {
                _wResult = WWWaitResultTimeOut;
            }
        }
    }

    WWWaitResult result;
    @synchronized(self) {
        result = _wResult;
        if (_semaphore == semaphore) {
            _needsConsumption = NO;
        }
    }
    return result;
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
    if (![self prepareWait]) {
        return WWWaitResultFailed;
    }
    return [self waitPrepared:mills];
}


/**
 *  结束等待，并设置waitSignle返回结果
 *
 *  @param result     等待结束原因
 *
 */
-(void)waitOver:(WWWaitResult)result
{
    dispatch_semaphore_t semaphore = nil;
    @synchronized(self) {
        if (_wResult != WWWaitResultWaiting) {
            return;
        }
        _wResult = result;
        semaphore = _semaphore;
    }

    dispatch_semaphore_signal(semaphore);
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
@end
