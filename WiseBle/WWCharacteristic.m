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
        self.serviceID = serviceID;
        self.characteristicID = characteristicID;
    }
    
    return self;
}

//有值且不为空
- (BOOL)isHaveValue
{
    NSCharacterSet *set = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    NSString *trimedString = [self.serviceID stringByTrimmingCharactersInSet:set];
    
    if (trimedString.length == 0) {
        return false;
    }
    
    trimedString = [self.characteristicID stringByTrimmingCharactersInSet:set];
    
    if (trimedString.length == 0) {
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
 
 @param object 待比较对象
 @return 相同true，否则为false
 */
- (BOOL)isEqual:(id)object
{
    if (self == object) {
        return true;
    }
    if (![object isKindOfClass:[WWCharacteristic class]]) {
        return false;
    }

    WWCharacteristic *characteristic = object;
    if ([self.serviceID isEqualToString:characteristic.serviceID] &&
        [self.characteristicID isEqualToString:characteristic.characteristicID]) {
        
        return true;
    }
    
    return false;
}

- (NSUInteger)hash
{
    return self.serviceID.hash ^ self.characteristicID.hash;
}

@end
