//
//  WWBluetoothLE.m
//  WiseBleDemo
//
//  Created by wuruizhi on 2017/4/21.
//  Copyright © 2017年 wuruizhi. All rights reserved.
//

#import "WWBluetoothLE.h"
#import "WWWaitEvent.h"


//是否打印日志
BOOL ble_isOpenLog = false;

#define BLELog(fmt, ...) if(ble_isOpenLog) NSLog((@"WWBLE: " fmt), ##__VA_ARGS__);

#define BleDataLengthMax                20

@interface WWBluetoothLE()<CBCentralManagerDelegate,CBPeripheralDelegate>
{
    //蓝牙管理类
    CBCentralManager *_centeralManager;
    
    //连接等待
    WWWaitEvent *_connectEvent;
    
    //接受数据等待
    WWWaitEvent *_receiveEvent;
    
    //读取数据等待
    WWWaitEvent *_readEvent;
    
    //通知操作等待
    WWWaitEvent *_notifyEvent;
    
    //接收数据
    NSMutableData *_recvData;
    
    //读取数据
    NSMutableData *_readData;
    
    //是否为我主动断开的
    BOOL _isMyDisconnected;
    
    //总共要发送的包数
    NSUInteger  _totalSendGroup;
    
    //已经发送的包数
    NSUInteger  _hasSendGroup;
    
    //读取的特征
    WWCharacteristic *_readCharacteristic;
    
}
@end


@implementation WWBluetoothLE

-(instancetype)init
{
    self = [super init];
    if (self != nil) {
        
        _managerDelegate = nil;
        _centeralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
        
        _connectEvent = [[WWWaitEvent alloc] init];
        
        _receiveEvent = [[WWWaitEvent alloc] init];
        
        _readEvent = [[WWWaitEvent alloc] init];
        
        _notifyEvent = [[WWWaitEvent alloc] init];
        
        _recvData = [NSMutableData data];
        
        _readData = [NSMutableData data];
        
        _isMyDisconnected = false;
    }
    
    return self;
}


/**
 *  蓝牙单例
 *
 *  @return 蓝牙单例
 *
 */
+(instancetype)shareBLE
{
    static WWBluetoothLE *shareInstance = nil;
    
    static dispatch_once_t predicate;
    //该函数接收一个dispatch_once用于检查该代码块是否已经被调度,可不用使用@synchronized进行解决同步问题
    dispatch_once(&predicate, ^{
        if (shareInstance == nil) {
            shareInstance = [[self alloc] init];
        }
    });
    
    return shareInstance;
}

/**
 *  打开蓝牙日志
 *
 *  @param isOpen      是否打开日志，true打开，false关闭
 *
 */
- (void)openBleLog:(BOOL)isOpen
{
    ble_isOpenLog = isOpen;
}


/**
 *  开始扫描
 *
 *  @param isPowerSaving      是否为省电模式；true为省电模式即不会更新重复的设备，false为非省电模式
 *
 *  @return 成功true，否则false
 *
 */
-(BOOL)startScan:(BOOL)isPowerSaving
{
    return [self startScan:isPowerSaving services:nil];
}

/**
 *  开始扫描
 *
 *  @param isPowerSaving      是否为省电模式；true为省电模式即不会更新重复的设备，false为非省电模式
 *  @param serviceUUIDs       仅扫描有该服务的设备
 *
 *  @return 成功true，否则false
 *
 */
-(BOOL)startScan:(BOOL)isPowerSaving services:(NSArray <NSString *> *)serviceUUIDs
{
    if (_centeralManager.state != CBCentralManagerStatePoweredOn) {
        return NO;
    }
    
    NSMutableArray<CBUUID *> * uuids = nil;
    
    if (serviceUUIDs != nil) {
        
        for (NSString *str in serviceUUIDs) {
            
            CBUUID *temp = [CBUUID UUIDWithString:str];
            
            if (temp == nil) {
                BLELog(@"无效uuid");
                return false;
            }
            else {
                [uuids addObject:temp];
            }
        }
    }
    
    //省电模式
    if (isPowerSaving) {
        [_centeralManager scanForPeripheralsWithServices:uuids options:nil];
    }
    else {
        [_centeralManager scanForPeripheralsWithServices:uuids options:@{CBCentralManagerScanOptionAllowDuplicatesKey:@(true)}];
    }
    
    _isScanning = true;
    
    
    return YES;
}


/**
 *  停止扫描
 *
 */
-(void)stopScan
{
    [_centeralManager stopScan];
    _isScanning = false;
}

/**
 *  根据uuid获取蓝牙实例
 *
 *  @param identifyUUID           蓝牙uuid
 *
 *  @return 蓝牙实例
 */
-(CBPeripheral *)getPeripheral:(NSString *)identifyUUID
{
    NSArray *peris = [_centeralManager retrievePeripheralsWithIdentifiers:@[[[NSUUID alloc] initWithUUIDString:identifyUUID]]];
    return peris[0];
}


/**
 *  同步连接蓝牙
 *
 *  @param peripheral           蓝牙设备
 *  @param timeOut              超时时间，单位ms
 *
 */
- (BOOL)synchronizedConnect:(CBPeripheral *)peripheral time:(NSUInteger)timeOut
{
    if (peripheral == nil) {
        BLELog(@"设备不能为空");
        return false;
    }
    
    _isMyDisconnected = false;
    
    [_centeralManager connectPeripheral:peripheral options:nil];
    
    WWWaitResult result = [_connectEvent waitSignle:timeOut];
    
    if (result == WWWaitResultSuccess) {
        return true;
    }
    else{
        [self disconnect:peripheral];
        return false;
    }
    
}

/**
 *  连接蓝牙
 *
 *  @param peripheral           蓝牙设备
 *
 */
- (void)connect:(CBPeripheral *)peripheral
{
    if (peripheral == nil) {
        BLELog(@"设备不能为空");
        if (_connectDelegate != nil && [_connectDelegate respondsToSelector:@selector(ble:didConnect:result:)]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.connectDelegate ble:self didConnect:nil result:false];
            });
        }
        return ;
    }

    
    _isMyDisconnected = false;
    
    [_centeralManager connectPeripheral:peripheral options:nil];
}


/**
 *  断开连接
 *
 *  @param peripheral           蓝牙设备
 *
 */
-(void)disconnect:(CBPeripheral *)peripheral
{
    _isMyDisconnected = true;
    
    [_centeralManager cancelPeripheralConnection:peripheral];
}

/**
 *  断开连接
 *
 *  @param peripheral           蓝牙设备
 *  @param isCallBack           是否进入回调  ble:didDisconnect:
 */
- (void)disconnect:(CBPeripheral *)peripheral callBack:(BOOL)isCallBack
{
    _isMyDisconnected = false;
    
    [_centeralManager cancelPeripheralConnection:peripheral];
}


/**
 *  获取所有的特征值
 *
 *  @param peripheral           蓝牙设备
 *
 *  @return 特征值字典，key为服务uuid，value为特征uuid
 */
- (NSDictionary<NSString *, NSArray<WWCharacteristic *> *> *)getAllCharacteristic:(CBPeripheral *)peripheral
{
    if (peripheral == nil) {
        BLELog(@"设备不能为空");
        return nil;
    }
    
    //未连接
    if (peripheral.state != CBPeripheralStateConnected) {
        BLELog(@"设备未连接");
        return nil;
    }
    
    NSMutableDictionary<NSString *, NSArray<WWCharacteristic *> *> *dict = [NSMutableDictionary dictionary];
    
    for (CBService *service in peripheral.services) {
        
        NSMutableArray <WWCharacteristic *> *array = [NSMutableArray array];
        
        for (CBCharacteristic *charact in service.characteristics) {
            WWCharacteristic *c = [[WWCharacteristic alloc] init];
            c.serviceID = service.UUID.UUIDString;
            c.characteristicID = charact.UUID.UUIDString;
            [array addObject:c];
        }
        
        dict[service.UUID] = array;
    }

    
    return dict;
}


/**
 *  获取某个特征值的属性
 *
 *  @param peripheral           蓝牙设备
 *  @param characteristic       特征值
 *
 *  @return 特征值属性
 */
- (CBCharacteristicProperties)getCharacteristicProperties:(CBPeripheral *)peripheral characteristic:(WWCharacteristic *)characteristic
{
    if (peripheral == nil) {
        BLELog(@"设备不能为空");
        return 0;
    }
    
    //未连接
    if (peripheral.state != CBPeripheralStateConnected) {
        BLELog(@"设备未连接");
        return 0;
    }
    
    if (characteristic == nil || !characteristic.isHaveValue) {
        BLELog(@"characteristic 无效")
        return 0;
    }
    
    //获取BleServicesNotify服务
    CBService *ser = [self getService:characteristic.serviceID fromPeripheral:peripheral];
    
    if (ser == nil) {
        BLELog(@"characteristic serviceID不存在");
        return 0;
    }
    
    //获取BleNotifyCharacteristicsReceive特征值
    CBCharacteristic *charact = [self getCharacteristic:characteristic.characteristicID fromService:ser];
    
    if (charact == nil) {
        BLELog(@"bleWithNotify characteristicID不存在");
        return 0;
    }
    
    return charact.properties;
}

/**
 *  打开通知
 *
 *  @param peripheral               蓝牙设备
 *
 *  @return 成功true，否则false
 *
 *  @note 使用commonNotifyCharacteristic服务，走回调函数 ble:didNotify:characteristic:enable:result:
 */
- (BOOL)openNofity:(CBPeripheral *)peripheral
{
    return [self openNofity:peripheral characteristic:_commonResponeNotifyCharacteristic];
}


/**
 *  同步打开通知
 *
 *  @param peripheral               蓝牙设备
 *  @param timeOut                  超时时间，单位ms
 *
 *  @return 成功true，否则false
 *
 *  @note 使用commonNotifyCharacteristic服务，不会走回调函数 ble:didNotify:characteristic:enable:result:
 */
- (BOOL)synchronizedOpenNofity:(CBPeripheral *)peripheral time:(NSUInteger)timeOut
{
    return [self synchronizedOpenNofity:peripheral characteristic:_commonResponeNotifyCharacteristic time:timeOut];
}


/**
 *  关闭通知
 *
 *  @param peripheral               蓝牙设备
 *
 *  @return 成功true，否则false
 *
 *  @note 使用commonNotifyCharacteristic服务，走回调函数 ble:didNotify:characteristic:enable:result:
 */
- (BOOL)closeNofity:(CBPeripheral *)peripheral
{
    return [self closeNofity:peripheral characteristic:_commonResponeNotifyCharacteristic];
}


/**
 *  同步关闭通知
 *
 *  @param peripheral               蓝牙设备
 *  @param timeOut                  超时时间，单位ms
 *
 *  @return 成功true，否则false
 *
 *  @note 使用commonNotifyCharacteristic服务，不会走回调函数 ble:didNotify:characteristic:enable:result:
 */
- (BOOL)synchronizedCloseNofity:(CBPeripheral *)peripheral time:(NSUInteger)timeOut
{
    return [self synchronizedCloseNofity:peripheral characteristic:_commonResponeNotifyCharacteristic time:timeOut];
}

/**
 *  打开通知
 *
 *  @param peripheral               蓝牙设备
 *  @param characteristic           特征值
 *
 *  @return 成功true，否则false
 *
 *  @note 走回调函数 ble:didNotify:characteristic:enable:result:
 */
- (BOOL)openNofity:(CBPeripheral *)peripheral characteristic:(WWCharacteristic *)characteristic
{
    if (peripheral == nil) {
        BLELog(@"设备不能为空");
        return false;
    }
    
    //未连接
    if (peripheral.state != CBPeripheralStateConnected) {
        BLELog(@"设备未连接");
        return false;
    }

    if (characteristic == nil || !characteristic.isHaveValue) {
        BLELog(@"characteristic 无效")
        return false;
    }
    
    //获取BleServicesNotify服务
    CBService *ser = [self getService:characteristic.serviceID fromPeripheral:peripheral];
    
    if (ser == nil) {
        BLELog(@"characteristic serviceID不存在");
        return false;
    }
    
    //获取BleNotifyCharacteristicsReceive特征值
    CBCharacteristic *charact = [self getCharacteristic:characteristic.characteristicID fromService:ser];
    
    if (charact == nil) {
        BLELog(@"bleWithNotify characteristicID不存在");
        return false;
    }
    
    if ( (charact.properties & CBCharacteristicPropertyNotify) == 0x00) {
        BLELog(@"characteristic 该特征值无通知属性")
        return false;
    }
    
    //打开通知
    [peripheral setNotifyValue:true forCharacteristic:charact];
    
    return true;
}


/**
 *  同步打开通知
 *
 *  @param peripheral               蓝牙设备
 *  @param characteristic           特征值
 *  @param timeOut                  超时时间，单位ms
 *
 *  @return 成功true，否则false
 *
 *  @note 不会走回调函数 ble:didNotify:characteristic:enable:result:
 */
- (BOOL)synchronizedOpenNofity:(CBPeripheral *)peripheral characteristic:(WWCharacteristic *)characteristic time:(NSUInteger)timeOut
{
    BOOL isResult = [self openNofity:peripheral characteristic:characteristic];
    if (!isResult) {
        return false;
    }
    
    WWWaitResult result = [_notifyEvent waitSignle:timeOut];
    
    return (result == WWWaitResultSuccess);
    
}

/**
 *  关闭通知
 *
 *  @param peripheral               蓝牙设备
 *  @param characteristic           特征值
 *
 *  @return 成功true，否则false
 *
 *  @note 走回调函数 ble:didNotify:characteristic:enable:result:
 */
- (BOOL)closeNofity:(CBPeripheral *)peripheral characteristic:(WWCharacteristic *)characteristic
{
    if (characteristic == nil || !characteristic.isHaveValue) {
        BLELog(@"characteristic 无效")
        return false;
    }
    
    //获取BleServicesNotify服务
    CBService *ser = [self getService:characteristic.serviceID fromPeripheral:peripheral];
    
    if (ser == nil) {
        BLELog(@"characteristic serviceID不存在");
        return false;
    }
    
    //获取BleNotifyCharacteristicsReceive特征值
    CBCharacteristic *charact = [self getCharacteristic:characteristic.characteristicID fromService:ser];
    
    if (charact == nil) {
        BLELog(@"bleWithNotify characteristicID不存在");
        return false;
    }
    
    if ( (charact.properties & CBCharacteristicPropertyNotify) == 0x00) {
        BLELog(@"characteristic 该特征值无通知属性")
        return false;
    }
    
    //打开通知
    [peripheral setNotifyValue:false forCharacteristic:charact];
    
    return true;
}


/**
 *  同步关闭通知
 *
 *  @param peripheral               蓝牙设备
 *  @param characteristic           特征值
 *  @param timeOut                  超时时间，单位ms
 *
 *  @return 成功true，否则false
 *
 *  @note 不会走回调函数 ble:didNotify:characteristic:enable:result:
 */
- (BOOL)synchronizedCloseNofity:(CBPeripheral *)peripheral characteristic:(WWCharacteristic *)characteristic time:(NSUInteger)timeOut
{
    BOOL isResult = [self closeNofity:peripheral characteristic:characteristic];
    if (!isResult) {
        return false;
    }
    
    WWWaitResult result = [_notifyEvent waitSignle:timeOut];
    
    return (result == WWWaitResultSuccess);
}


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
-(BOOL)send:(CBPeripheral *)peripheral value:(NSData *)data
{
    return [self send:peripheral characteristic:_commonSendCharacteristic value:data];
}

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
-(NSData *)sendReceive:(CBPeripheral *)peripheral value:(NSData *)data time:(NSUInteger)timeOut
{
    return [self sendReceive:peripheral characteristic:_commonSendCharacteristic value:data time:true];
}

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
-(BOOL)send:(CBPeripheral *)peripheral characteristic:(WWCharacteristic *)characteristic value:(NSData *)data
{
    if (peripheral == nil) {
        BLELog(@"下发设备不能为空");
        return false;
    }
    
    //未连接
    if (peripheral.state != CBPeripheralStateConnected) {
        BLELog(@"设备未连接");
        return false;
    }
    
    if (data == nil) {
        BLELog(@"下发数据不能为空");
        return  false;
    }
    
    if (!characteristic.isHaveValue) {
        
        BLELog(@"发送特征值无效");
        
        return false;
    }
    
    CBService * service = [self getService:characteristic.serviceID fromPeripheral:peripheral];
    if (service == nil) {
        
        BLELog(@"发送特征值serviceID不存在");
        
        return false;
    }
    
    CBCharacteristic  *charact = [self getCharacteristic:characteristic.characteristicID fromService:service];
    if (charact == nil) {
        
        BLELog(@"发送特征值characteristicID不存在");
        return false;
    }
    
    NSData *sendData = data;
    //默认无响应
    CBCharacteristicWriteType type = CBCharacteristicWriteWithoutResponse;
    //有响应
    if ( (charact.properties&CBCharacteristicPropertyWrite) != 0x00 ) {
        type = CBCharacteristicWriteWithResponse;
    }
    
    //若代理存在，则调用代理
    if (_managerData != nil && [_managerData respondsToSelector:@selector(ble:didPreSend:characteristic:data:)]) {
        
        sendData = [_managerData ble:self didPreSend:peripheral characteristic:characteristic data:data];
    }
    
    NSMutableData *temp= [[NSMutableData alloc] initWithCapacity:0];
    
    NSUInteger nGroup = (sendData.length+BleDataLengthMax-1)/BleDataLengthMax;
    _hasSendGroup = 0;
    _totalSendGroup = nGroup;
    
    for (NSUInteger i=0; i<nGroup; i++)
    {
        [temp setLength:0];
        if (i == (nGroup-1)) {
            [temp appendBytes:(sendData.bytes+i*BleDataLengthMax) length:sendData.length-i*BleDataLengthMax ];
        }
        else{
            [temp appendBytes:(sendData.bytes+i*BleDataLengthMax) length:BleDataLengthMax];
        }
        
        [peripheral writeValue:temp forCharacteristic:charact type:type];
    }
    
    return true;
}


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
-(NSData *)sendReceive:(CBPeripheral *)peripheral characteristic:(WWCharacteristic *)characteristic value:(NSData *)data time:(NSUInteger)timeOut
{
    if (![self send:peripheral characteristic:characteristic value:data]) {
        return nil;
    }
    
    
    NSMutableData *tempData = [NSMutableData data];
    WWWaitResult result = [_receiveEvent waitSignle:timeOut];
    if (result != WWWaitResultSuccess) {
        return nil;
    }
    
    [tempData appendData:_recvData];
    _recvData = [NSMutableData data];
    
    return tempData;
}

/**
 读取数据
 
 @param peripheral 蓝牙设备
 @param characteristic 读取特征值
 
 @return 成功true，否则false
 
 @note 返回值返到ble:didReceiveData:characteristic:data:
 */
- (BOOL)readData:(CBPeripheral *)peripheral characteristic:(WWCharacteristic *)characteristic
{
    if (peripheral == nil) {
        BLELog(@"下发设备不能为空");
        return false;
    }
    
    //未连接
    if (peripheral.state != CBPeripheralStateConnected) {
        BLELog(@"设备未连接");
        return false;
    }
    
    
    if (!characteristic.isHaveValue) {
        
        BLELog(@"发送特征值无效");
        
        return false;
    }
    
    CBService * service = [self getService:characteristic.serviceID fromPeripheral:peripheral];
    if (service == nil) {
        
        BLELog(@"发送特征值serviceID不存在");
        
        return false;
    }
    
    CBCharacteristic  *charact = [self getCharacteristic:characteristic.characteristicID fromService:service];
    if (charact == nil) {
        
        BLELog(@"发送特征值characteristicID不存在");
        return false;
    }
    
    //是否为可读服务
    if ( (charact.properties&CBCharacteristicPropertyRead) == 0x00 ) {
        
        BLELog(@"发送特征值不支持读取");
        return false;
    }
    
    _readCharacteristic = characteristic;
    
    [peripheral readValueForCharacteristic:charact];
    
    return true;
}


/**
 同步读取数据
 
 @param peripheral 蓝牙设备
 @param characteristic 读取特征根治
 @param timeOut 超时时间
 @return 读取到的数据
 */
- (NSData *)synchronizedReadData:(CBPeripheral *)peripheral characteristic:(WWCharacteristic *)characteristic time:(NSUInteger)timeOut
{
    if (![self readData:peripheral characteristic:characteristic]) {
        return nil;
    }
    
    
    NSMutableData *tempData = [NSMutableData data];
    WWWaitResult result = [_readEvent waitSignle:timeOut];
    if (result != WWWaitResultSuccess) {
        return nil;
    }
    
    [tempData appendData:_readData];
    _readData = [NSMutableData data];
    
    return tempData;
}


/**
 *  读取rssi
 *
 *  @param peripheral           蓝牙设备
 *
 *  @note 回调函数 ble:didUpdateRssi:rssi:result:
 */
-(void)readRssi:(CBPeripheral *)peripheral
{
    [peripheral readRSSI];
}


//获取服务
-(CBService *)getService:(NSString *)serviceID fromPeripheral:(CBPeripheral *)peripheral
{
    for (CBService *service in peripheral.services) {
        if ([service.UUID.UUIDString isEqualToString:serviceID]) {
            return service;
        }
    }
    
    return nil;
}


//获取特征值
-(CBCharacteristic *)getCharacteristic:(NSString *)characteristicID fromService:(CBService *)service
{
    for (CBCharacteristic *charact in service.characteristics) {
        if ([charact.UUID.UUIDString isEqualToString:characteristicID]) {
            return charact;
        }
    }
    
    return nil;
}

#pragma mark - CBCentralManager代理函数

//本地蓝牙设备状态更新代理
-(void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    switch (central.state) {
        case CBCentralManagerStatePoweredOff:
            _loaclState = WWBleLocalStatePowerOff;
            BLELog(@"power off");
            break;
        case CBCentralManagerStatePoweredOn:
            _loaclState = WWBleLocalStatePowerOn;
            break;
        default:
            _loaclState = WWBleLocalStateUnsupported;
            break;
    }
    if([self.managerDelegate respondsToSelector:@selector(ble:didLocalState:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.managerDelegate ble:self didLocalState:self.loaclState];
        });
    }
}

//扫描信息代理
-(void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI
{
    if([self.managerDelegate respondsToSelector:@selector(ble:didScan:advertisementData:rssi:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.managerDelegate ble:self didScan:peripheral advertisementData:advertisementData rssi:RSSI];
        });
    }
}

//外围蓝牙设备连接代理
-(void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    BLELog(@"WWBluetoothLE  连接ok %@",peripheral);
    peripheral.delegate = self;
    
    BLELog(@"扫描服务...");
    [peripheral discoverServices:nil];
}

//外围蓝牙设备断开代理
-(void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    if (error) {
        BLELog(@"disconnect error = %@",error);
    }
    
    //被动断开
    if(!_isMyDisconnected && self.connectDelegate && [self.connectDelegate respondsToSelector:@selector(ble:didDisconnect:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.connectDelegate ble:self didDisconnect:peripheral];
        });
    }
    
    _isMyDisconnected = false;
    
}

//连接外围设备失败代理
-(void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    //_connectEvent 并未等待 且实现了代理
    if([_connectEvent getWaitStatus] != WWWaitResultWaiting && self.connectDelegate && [self.connectDelegate respondsToSelector:@selector(ble:didConnect:result:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.connectDelegate ble:self didConnect:peripheral result:NO];
        });
    }
}

#pragma mark - CBPeripheral代理函数
//搜索服务
-(void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    if (!error) {
        int count = (int)peripheral.services.count;
        
        for (int i=0; i<count; i++) {
            CBService *service = [peripheral.services objectAtIndex:i];
            [peripheral discoverCharacteristics:nil forService:service];
        }
    }
    
}

//扫描特征值
-(void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    if (!error) {
        
        //最后一个服务
        CBService *s = [peripheral.services objectAtIndex:(peripheral.services.count-1)];
        if([service.UUID isEqual:s.UUID]) {
            
            if ([_connectEvent getWaitStatus] == WWWaitResultWaiting) {
                
                [_connectEvent waitOver:WWWaitResultSuccess];
            }
            else {
                
                if (_connectDelegate != nil && [_connectDelegate respondsToSelector:@selector(ble:didConnect:result:)]) {
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                       [self.connectDelegate ble:self didConnect:peripheral result:true];
                    });
                }
            }
            
        }
    }
    else {
        
        if ([_connectEvent getWaitStatus] == WWWaitResultWaiting) {
            
            [_connectEvent waitOver:WWWaitResultFailed];
        }
        else {
            
            if (_connectDelegate != nil && [_connectDelegate respondsToSelector:@selector(ble:didConnect:result:)]) {
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.connectDelegate ble:self didConnect:peripheral result:false];
                });
                
            }
        }
    }
}


//通知状态更改
-(void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    WWCharacteristic *charact = [[WWCharacteristic alloc] init];
    charact.serviceID = characteristic.service.UUID.UUIDString;
    charact.characteristicID = characteristic.UUID.UUIDString;
    
    if (error == nil) {
        
        //同步操作
        if ([_notifyEvent getWaitStatus] == WWWaitResultWaiting) {
            
            [_notifyEvent waitOver:WWWaitResultSuccess];
        }
        //异步操作
        else {
            
            if (_bleDelegate != nil && [_bleDelegate respondsToSelector:@selector(ble:didNotify:characteristic:enable:result:)]) {
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.bleDelegate ble:self didNotify:peripheral characteristic:charact enable:characteristic.isNotifying result:true];
                });
            }
        }
        
    }
    else {
        
        BLELog(@"通知操作异常：%@", error);
        
        //同步操作
        if ([_notifyEvent getWaitStatus] == WWWaitResultWaiting) {
            
            [_notifyEvent waitOver:WWWaitResultFailed];
        }
        //异步操作
        else {
            
            if (_bleDelegate != nil && [_bleDelegate respondsToSelector:@selector(ble:didNotify:characteristic:enable:result:)]) {
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.bleDelegate ble:self didNotify:peripheral characteristic:charact enable:characteristic.isNotifying result:false];
                });
            }
        }
    }
    
}

-(void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    
    if (error == nil) {
        
        WWCharacteristic *charact = [[WWCharacteristic alloc] init];
        charact.serviceID = characteristic.service.UUID.UUIDString;
        charact.characteristicID = characteristic.UUID.UUIDString;
        
        if (_readCharacteristic != nil && [_readCharacteristic isEqual:charact]) {
            
            [self readData:peripheral updateValueForCharacteristic:characteristic];
        }
        else {
            [self receiveData:peripheral updateValueForCharacteristic:characteristic];
        }
        
    }
    else {
        BLELog(@"接收数据出错：%@", error);
    }
}

-(void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    WWCharacteristic *charact = [[WWCharacteristic alloc] init];
    charact.serviceID = characteristic.service.UUID.UUIDString;
    charact.characteristicID = characteristic.UUID.UUIDString;
    
    if (!error) {
        _hasSendGroup++;
        if (_hasSendGroup == _totalSendGroup) {
            if (_bleDelegate != nil && [_bleDelegate respondsToSelector:@selector(ble:didSendData:characteristic:result:)]) {
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.bleDelegate ble:self didSendData:peripheral characteristic:charact result:true];
                });
            }
        }
    }
    else{
        
        BLELog(@"下发数据失败：%@",error);
        
        if (_bleDelegate != nil && [_bleDelegate respondsToSelector:@selector(ble:didSendData:characteristic:result:)]) {
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.bleDelegate ble:self didSendData:peripheral characteristic:charact result:false];
            });
        }
    }
}

-(void)peripheral:(CBPeripheral *)peripheral didReadRSSI:(NSNumber *)RSSI error:(NSError *)error
{
    if (error == nil) {
        
        if (_bleDelegate != nil && [_bleDelegate respondsToSelector:@selector(ble:didUpdateRssi:rssi:result:)]) {
            
            dispatch_async(dispatch_get_main_queue(), ^{
               [self.bleDelegate ble:self didUpdateRssi:peripheral rssi:RSSI result:true];
            });
        }
    }
    else {
        if (_bleDelegate != nil && [_bleDelegate respondsToSelector:@selector(ble:didUpdateRssi:rssi:result:)]) {
            
            dispatch_async(dispatch_get_main_queue(), ^{
               [self.bleDelegate ble:self didUpdateRssi:peripheral rssi:RSSI result:false];
            });
        }
    }
}


/**
 读取数据返回

 @param peripheral 蓝牙设备
 @param characteristic 特征
 */
- (void)readData:(CBPeripheral *)peripheral updateValueForCharacteristic:(CBCharacteristic *)characteristic
{
    WWCharacteristic *charact = [[WWCharacteristic alloc] init];
    charact.serviceID = characteristic.service.UUID.UUIDString;
    charact.characteristicID = characteristic.UUID.UUIDString;
    
    NSData *valueData = characteristic.value;
    
    if ([_readEvent getWaitStatus] == WWWaitResultWaiting) {
        
        [_readData resetBytesInRange:NSMakeRange(0, _readData.length)];
        [_readData setLength:0];
        [_readData appendData:characteristic.value];
        [_readEvent waitOver:WWWaitResultSuccess];
    }
    else {
        
        if (_bleDelegate != nil && [_bleDelegate respondsToSelector:@selector(ble:didReceiveData:characteristic:data:)]) {
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.bleDelegate ble:self didReceiveData:peripheral characteristic:charact data:valueData];
            });
            
            
        }
        
    }
}

/**
 通知接收数据返回
 
 @param peripheral 蓝牙设备
 @param characteristic 特征
 */
- (void)receiveData:(CBPeripheral *)peripheral updateValueForCharacteristic:(CBCharacteristic *)characteristic
{
    WWCharacteristic *charact = [[WWCharacteristic alloc] init];
    charact.serviceID = characteristic.service.UUID.UUIDString;
    charact.characteristicID = characteristic.UUID.UUIDString;
    
    NSData *valueData = characteristic.value;
    
    if (_managerData != nil && [_managerData respondsToSelector:@selector(ble:didPreReceive:characteristic:data:)]) {
        
        //预处理接收数据
        NSData *tempData = [_managerData ble:self didPreReceive:peripheral characteristic:charact data:valueData];
        
        //不为空表示 接收数据完成
        if (tempData != nil) {
            
            //返回响应
            if (_commonResponeNotifyCharacteristic != nil && [charact isEqual:_commonResponeNotifyCharacteristic] && [_receiveEvent getWaitStatus] == WWWaitResultWaiting) {
                
                [_recvData resetBytesInRange:NSMakeRange(0, _recvData.length)];
                [_recvData setLength:0];
                [_recvData appendData:tempData];
                
                [_receiveEvent waitOver:WWWaitResultSuccess];
                
            }
            else {
                
                if (_bleDelegate != nil && [_bleDelegate respondsToSelector:@selector(ble:didReceiveData:characteristic:data:)]) {
                    
                    //接收数据
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.bleDelegate ble:self didReceiveData:peripheral characteristic:charact data:tempData];
                    });
                }
            }
            
            
        }
        
    }
    else {
        
        //返回响应
        if (_commonResponeNotifyCharacteristic != nil && [charact isEqual:_commonResponeNotifyCharacteristic] && [_receiveEvent getWaitStatus] == WWWaitResultWaiting) {
            
            [_recvData resetBytesInRange:NSMakeRange(0, _recvData.length)];
            [_recvData setLength:0];
            [_recvData appendData:valueData];
            
            [_receiveEvent waitOver:WWWaitResultSuccess];
            
        }
        else {
            
            if (_bleDelegate != nil && [_bleDelegate respondsToSelector:@selector(ble:didReceiveData:characteristic:data:)]) {
                
                //接收数据
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.bleDelegate ble:self didReceiveData:peripheral characteristic:charact data:valueData];
                });
            }
        }
        
    }
}




@end
