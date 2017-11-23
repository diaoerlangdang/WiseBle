//
//  WiseBleData.m
//  WiseBleDemo
//
//  Created by wuruizhi on 2017/8/21.
//  Copyright © 2017年 wuruizhi. All rights reserved.
//

#import "WiseBleData.h"

@implementation WiseBleData

+(instancetype)shareBLEData
{
    static WiseBleData *shareInstance = nil;
    
    static dispatch_once_t predicate;
    //该函数接收一个dispatch_once用于检查该代码块是否已经被调度,可不用使用@synchronized进行解决同步问题
    dispatch_once(&predicate, ^{
        if (shareInstance == nil) {
            shareInstance = [[self alloc] init];
        }
    });
    
    return shareInstance;

}

- (NSData *)ble:(WWBluetoothLE *)ble didPreReceive:(CBPeripheral *)peripheral characteristic:(WWCharacteristic *)characteristic data:(NSData *)data
{
    NSLog(@"wrz: %@",@"pre receive");
    return data;
}

- (NSData *)ble:(WWBluetoothLE *)ble didPreSend:(CBPeripheral *)peripheral characteristic:(WWCharacteristic *)characteristic data:(NSData *)data
{
    NSLog(@"wrz: %@",@"pre send");
    return data;
}

@end
