//
//  WWCharacteristic.m
//  WiseBleDemo
//
//  Created by wuruizhi on 2017/7/24.
//  Copyright © 2017年 wuruizhi. All rights reserved.
//

#import "WWCharacteristic.h"

@implementation WWCharacteristic

/**
 *  初始化
 *
 *  @param serviceID           服务id
 *  @param characteristicID    特征id
 *
 *  @return 特征值
 */
- (instancetype)initWithServiceID:(NSString *)serviceID characteristicID:(NSString *)characteristicID
{
    self = [super init];
    if (self) {
        _serviceID = serviceID;
        _characteristicID = characteristicID;
    }
    
    return self;
}

//有值且不为空
- (BOOL)isHaveValue
{
    NSCharacterSet *set = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    NSString *trimedString = [_serviceID stringByTrimmingCharactersInSet:set];
    
    if (trimedString.length == 0 || _serviceID.length == 0 || !_serviceID) {
        return false;
    }
    
    trimedString = [_serviceID stringByTrimmingCharactersInSet:set];
    
    if (trimedString.length == 0 || _serviceID.length == 0 || !_serviceID) {
        return false;
    }
    
    return true;
}

- (void)setCharacteristicID:(NSString *)characteristicID
{
    _characteristicID = [characteristicID uppercaseString];
}

- (void)setServiceID:(NSString *)serviceID
{
    _serviceID = [serviceID uppercaseString];
}

/**
 是否相等
 
 @param characteristic 特征
 @return 相同true，否则为false
 */
- (BOOL)isEqual:(WWCharacteristic *)characteristic
{
    if ([self.serviceID isEqualToString:characteristic.serviceID] &&
        [self.characteristicID isEqualToString:characteristic.characteristicID]) {
        
        return true;
    }
    
    return false;
}

@end
