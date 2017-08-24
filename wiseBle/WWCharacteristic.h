//
//  WWCharacteristic.h
//  WiseBleDemo
//
//  Created by wuruizhi on 2017/7/24.
//  Copyright © 2017年 wuruizhi. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface WWCharacteristic : NSObject

//特征所在服务的uuid
@property (nonatomic, strong) NSString *serviceID;

//特征的uuid
@property (nonatomic, strong) NSString *characteristicID;

//serviceID characteristicID是否有值
@property (nonatomic, assign, readonly) BOOL isHaveValue;

/**
 *  初始化
 *
 *  @param serviceID           服务id
 *  @param characteristicID    特征id
 *
 *  @return 特征值
 */
- (instancetype)initWithServiceID:(NSString *)serviceID characteristicID:(NSString *)characteristicID;

@end
