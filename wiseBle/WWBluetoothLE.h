//
//  WWBluetoothLE.h
//  WiseBleDemo
//
//  Created by wuruizhi on 2017/4/21.
//  Copyright © 2017年 wuruizhi. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import "NSData+String.h"
#import "NSString+Hex.h"
#import "WWCharacteristic.h"

typedef NS_ENUM(NSInteger, WWBleLocalState) {
    WWBleLocalStatePowerOff,         //本地蓝牙已关闭
    WWBleLocalStatePowerOn,          //本地蓝牙已开启
    WWBleLocalStateUnsupported,     //本地不支持蓝牙
};

@class WWBluetoothLE;

//蓝牙管理数据代理
@protocol WWBluetoothLEManagerData <NSObject>
@optional

/**
 *  下发数据预处理 会在发送数据之前调用该函数预处理
 *
 *  @param ble                  蓝牙
 *  @param peripheral           蓝牙设备
 *  @param characteristic       发送的服务
 *  @param data                 当前蓝牙的状态
 *
 */
- (NSData *)ble:(WWBluetoothLE *)ble didPreSend:(CBPeripheral *)peripheral characteristic:(WWCharacteristic *)characteristic data:(NSData *)data;


/**
 *  上行数据预处理 会在接收数据之后调用该函数预处理，当该函数返回不为空时，在调用接收回调函数或者结束接收等待
 *
 *  @param ble                  蓝牙
 *  @param peripheral           蓝牙设备
 *  @param characteristic       发送的服务
 *  @param data                 当前蓝牙的状态
 *
 */
- (NSData *)ble:(WWBluetoothLE *)ble didPreReceive:(CBPeripheral *)peripheral characteristic:(WWCharacteristic *)characteristic data:(NSData *)data;


@end

//蓝牙管理代理
@protocol WWBluetoothLEManagerDelegate <NSObject>
@optional


/**
 *  蓝牙状态，仅在本地蓝牙状态为开启时, 即WWBleLocalStatePowerOn，其他函数方可使用
 *
 *  @param ble     蓝牙
 *  @param state   当前蓝牙的状态
 *
 */
- (void)ble:(WWBluetoothLE *)ble didLocalState:(WWBleLocalState)state;

/**
 *  扫描函数回调
 *
 *  @param ble                  蓝牙
 *  @param peripheral           扫描到的蓝牙设备
 *  @param advertisementData    广播数据
 *  @param rssi                 rssi值
 *
 */
- (void)ble:(WWBluetoothLE *)ble didScan:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData rssi:(NSNumber *)rssi;

@end

//蓝牙代理
@protocol WWBluetoothLEDelegate <NSObject>
@optional

/**
 *  蓝牙链接回调
 *
 *  @param ble                  蓝牙
 *  @param peripheral           蓝牙设备
 *  @param isSuccess            成功true或失败false
 *
 */
- (void)ble:(WWBluetoothLE *)ble didConnect:(CBPeripheral *)peripheral result:(BOOL)isSuccess;

/**
 *  蓝牙断开回调，主动断开不会走此回调
 *
 *  @param ble                  蓝牙
 *  @param peripheral           蓝牙设备
 *
 */
- (void)ble:(WWBluetoothLE *)ble didDisconnect:(CBPeripheral *)peripheral;


/**
 *  蓝牙通知回调
 *
 *  @param ble                  蓝牙
 *  @param peripheral           蓝牙设备
 *  @param characteristic       改变的服务
 *  @param enable               打开通知true，否则false
 *  @param isSuccess            成功true或失败false
 *
 */
- (void)ble:(WWBluetoothLE *)ble didNotify:(CBPeripheral *)peripheral characteristic:(WWCharacteristic *)characteristic enable:(BOOL)enable result:(BOOL)isSuccess;


/**
 *  蓝牙发送数据回调
 *
 *  @param ble                  蓝牙
 *  @param peripheral           蓝牙设备
 *  @param characteristic       发送的服务
 *  @param isSuccess            成功true或失败false
 *
 */
- (void)ble:(WWBluetoothLE *)ble didSendData:(CBPeripheral *)peripheral characteristic:(WWCharacteristic *)characteristic  result:(BOOL)isSuccess;


/**
 *  蓝牙接收数据回调
 *
 *  @param ble                  蓝牙
 *  @param peripheral           蓝牙设备
 *  @param characteristic       接收的服务
 *  @param data                 接收的数据
 *
 */
- (void)ble:(WWBluetoothLE *)ble didReceiveData:(CBPeripheral *)peripheral characteristic:(WWCharacteristic *)characteristic  data:(NSData *)data;

/**
 *  蓝牙RSSI更新回调
 *
 *  @param ble                  蓝牙
 *  @param peripheral           蓝牙设备
 *  @param rssi                 rssi
 *  @param isSuccess            成功true或失败false
 *
 */
- (void)ble:(WWBluetoothLE *)ble didUpdateRssi:(CBPeripheral *)peripheral rssi:(NSNumber *)rssi result:(BOOL)isSuccess;


@end

@interface WWBluetoothLE : NSObject

//蓝牙代理
@property (nonatomic, weak) id<WWBluetoothLEManagerDelegate> managerDelegate;

//蓝牙数据代理
@property (nonatomic, weak) id<WWBluetoothLEManagerData> managerData;

//蓝牙代理
@property (nonatomic, weak) id<WWBluetoothLEDelegate> bleDelegate;

//是否正在扫描
@property (readonly) BOOL isScanning;

//蓝牙本地状态
@property(readonly) WWBleLocalState loaclState;

//设置一个常用的通知服务，用户数据返回
@property(atomic, strong) WWCharacteristic *commonNotifyCharacteristic;

//设置一个常用的发送服务，用户数据发送
@property(atomic, strong) WWCharacteristic *commonSendCharacteristic;


/**
 *  蓝牙单例
 *
 *  @return 蓝牙单例
 *
 *  @note 蓝牙状态见回调函数 ble:didLocalState:
 */
+ (instancetype)shareBLE;


/**
 *  打开蓝牙日志
 *
 *  @param isOpen      是否打开日志，true打开，false关闭
 *
 */
- (void)openBleLog:(BOOL)isOpen;


/**
 *  开始扫描
 *
 *  @param isPowerSaving      是否为省电模式；true为省电模式即不会更新重复的设备，false为非省电模式
 *
 *  @return 成功true，否则false
 *
 *  @note 结果见回调函数 ble:didScan:advertisementData:rssi:
 */
- (BOOL)startScan:(BOOL)isPowerSaving;


/**
 *  开始扫描
 *
 *  @param isPowerSaving      是否为省电模式；true为省电模式即不会更新重复的设备，false为非省电模式
 *  @param serviceUUIDs       仅扫描有该服务的设备
 *
 *  @return 成功true，否则false
 *
 *  @note 结果见回调函数 ble:didScan:advertisementData:rssi:
 */
- (BOOL)startScan:(BOOL)isPowerSaving services:(NSArray <NSString *> *)serviceUUIDs;


/**
 *  停止扫描
 *
 */
- (void)stopScan;


/**
 *  根据uuid获取蓝牙实例
 *
 *  @param identifyUUID           蓝牙uuid
 *
 *  @return 蓝牙实例
 */
-(CBPeripheral *)getPeripheral:(NSString *)identifyUUID;


/**
 *  异步链接连接蓝牙
 *
 *  @param peripheral           蓝牙设备
 *
 *  @note 走回调函数 ble:didConnect:result:
 */
- (void)connect:(CBPeripheral *)peripheral;



/**
 *  同步连接蓝牙
 *
 *  @param peripheral           蓝牙设备
 *  @param timeOut              超时时间，单位ms
 *
 *  @return 成功true，否则false
 *
 *  @note 不走回调函数 ble:didConnect:result:
 */
- (BOOL)synchronizedConnect:(CBPeripheral *)peripheral time:(NSUInteger)timeOut;


/**
 *  断开连接
 *
 *  @param peripheral           蓝牙设备
 *
 *  @note 调用该函数断开蓝牙，不会回调函数 ble:didDisconnect:
 */
- (void)disconnect:(CBPeripheral *)peripheral;



/**
 *  获取所有的特征值
 *
 *  @param peripheral           蓝牙设备
 *
 *  @return 特征值字典，key为服务uuid，value为特征数组
 */
- (NSDictionary<NSString *, NSArray<WWCharacteristic *> *> *)getAllCharacteristic:(CBPeripheral *)peripheral;


/**
 *  获取某个特征值的属性
 *
 *  @param peripheral           蓝牙设备
 *  @param characteristic       特征值
 *
 *  @return 特征值属性
 */
- (CBCharacteristicProperties)getCharacteristicProperties:(CBPeripheral *)peripheral characteristic:(WWCharacteristic *)characteristic;


/**
 *  打开通知
 *
 *  @param peripheral               蓝牙设备
 *  @param characteristic           通知特征值
 *
 *  @return 成功true，否则false
 *
 *  @note 走回调函数 ble:didNotify:characteristic:enable:result:
 */
- (BOOL)openNofity:(CBPeripheral *)peripheral characteristic:(WWCharacteristic *)characteristic;


/**
 *  同步打开通知
 *
 *  @param peripheral               蓝牙设备
 *  @param characteristic           通知特征值
 *  @param timeOut                  超时时间，单位ms
 *
 *  @return 成功true，否则false
 *
 *  @note 不会走回调函数 ble:didNotify:characteristic:enable:result:
 */
- (BOOL)synchronizedOpenNofity:(CBPeripheral *)peripheral characteristic:(WWCharacteristic *)characteristic time:(NSUInteger)timeOut;

/**
 *  关闭通知
 *
 *  @param peripheral               蓝牙设备
 *  @param characteristic           通知特征值
 *
 *  @return 成功true，否则false
 *
 *  @note 走回调函数 ble:didNotify:characteristic:enable:result:
 */
- (BOOL)closeNofity:(CBPeripheral *)peripheral characteristic:(WWCharacteristic *)characteristic;


/**
 *  同步关闭通知
 *
 *  @param peripheral               蓝牙设备
 *  @param characteristic           通知特征值
 *  @param timeOut                  超时时间，单位ms
 *
 *  @return 成功true，否则false
 *
 *  @note 不会走回调函数 ble:didNotify:characteristic:enable:result:
 */
- (BOOL)synchronizedCloseNofity:(CBPeripheral *)peripheral characteristic:(WWCharacteristic *)characteristic time:(NSUInteger)timeOut;

/**
 *  发送数据
 *
 *  @param peripheral           蓝牙设备
 *  @param data                 发送数据
 *
 *  @return 成功true，否则false
 *
 *  @note 回调函数 ble:didSendData:characteristic:result:
 */
- (BOOL)send:(CBPeripheral *)peripheral value:(NSData *)data;


/**
 *  发送接收数据
 *
 *  @param peripheral           蓝牙设备
 *  @param data                 发送数据
 *  @param timeOut              超时时间，单位ms
 *
 *  @return 返回的数据，失败为nil
 *
 *  @note 不走回调函数 ble:didSendData:characteristic:result:
 */
- (NSData *)sendReceive:(CBPeripheral *)peripheral value:(NSData *)data time:(NSUInteger)timeOut;

/**
 *  发送数据
 *
 *  @param peripheral           蓝牙设备
 *  @param characteristic       发送特征值
 *  @param data                 发送数据
 *
 *  @return 成功true，否则false
 *
 *  @note 回调函数 ble:didSendData:characteristic:result:
 */
- (BOOL)send:(CBPeripheral *)peripheral characteristic:(WWCharacteristic *)characteristic value:(NSData *)data;


/**
 *  发送接收数据
 *
 *  @param peripheral           蓝牙设备
 *  @param characteristic       发送特征值
 *  @param data                 发送数据
 *  @param timeOut              超时时间，单位ms
 *
 *  @return 返回的数据，失败为nil
 *
 *  @note 不走回调函数 ble:didSendData:characteristic:result:
 */
- (NSData *)sendReceive:(CBPeripheral *)peripheral characteristic:(WWCharacteristic *)characteristic value:(NSData *)data time:(NSUInteger)timeOut;


/**
 *  读取rssi
 *
 *  @param peripheral           蓝牙设备
 *
 *  @note 回调函数 ble:didUpdateRssi:rssi:result:
 */
- (void)readRssi:(CBPeripheral *)peripheral;

@end
