//
//  WWBluetoothLE.m
//  WiseBleDemo
//
//  Created by wuruizhi on 2017/4/21.
//  Copyright © 2017年 wuruizhi. All rights reserved.
//

#import "WWBluetoothLE.h"
#import "WWWaitEvent.h"

static void *WWBLEQueueSpecificKey = &WWBLEQueueSpecificKey;

@interface WWBLEOperationContext : NSObject
@property (nonatomic, strong) CBPeripheral *peripheral;
@property (nonatomic, strong) WWCharacteristic *characteristic;
@property (nonatomic, strong) WWWaitEvent *event;
@property (nonatomic, assign) BOOL synchronous;
@property (nonatomic, assign) BOOL enable;
@property (nonatomic, assign) BOOL abandoned;
@property (nonatomic, strong) NSData *data;
@property (nonatomic, strong) NSMutableSet<NSValue *> *pendingServices;
@end

@implementation WWBLEOperationContext
@end

@interface WWBLEWriteContext : NSObject
@property (nonatomic, strong) CBPeripheral *peripheral;
@property (nonatomic, strong) CBCharacteristic *nativeCharacteristic;
@property (nonatomic, strong) WWCharacteristic *characteristic;
@property (nonatomic, copy) NSArray<NSData *> *packets;
@property (nonatomic, assign) NSUInteger nextPacketIndex;
@property (nonatomic, assign) CBCharacteristicWriteType type;
@property (nonatomic, assign) BOOL notifyDelegate;
@property (nonatomic, strong) WWBLEOperationContext *responseContext;
@property (nonatomic, assign) BOOL abandoned;
@end

@implementation WWBLEWriteContext
@end


//是否打印日志
BOOL ble_isOpenLog = false;

#define BLELog(fmt, ...) if(ble_isOpenLog) NSLog((@"WWBLE: " fmt), ##__VA_ARGS__);

@interface WWBluetoothLE()<CBCentralManagerDelegate,CBPeripheralDelegate>
{
    //蓝牙管理类
    CBCentralManager *_centeralManager;

    //CoreBluetooth代理回调队列
    dispatch_queue_t _bleQueue;

    BOOL _isScanning;
    WWBleLocalState _loaclState;
    
    //每台设备的连接流程
    NSMutableDictionary<NSString *, WWBLEOperationContext *> *_connectionContexts;

    NSMutableDictionary<NSString *, WWBLEOperationContext *> *_receiveContexts;

    NSMutableDictionary<NSString *, WWBLEOperationContext *> *_readContexts;

    NSMutableDictionary<NSString *, WWBLEOperationContext *> *_notifyContexts;

    NSMutableDictionary<NSString *, WWBLEWriteContext *> *_writeContexts;

    NSMutableSet<NSString *> *_silentDisconnects;
    NSMutableSet<NSString *> *_pendingDisconnects;
}
@end


@implementation WWBluetoothLE

-(instancetype)init
{
    dispatch_queue_t queue = dispatch_queue_create("com.wise.WiseBle", DISPATCH_QUEUE_SERIAL);
    CBCentralManager *centralManager = [[CBCentralManager alloc] initWithDelegate:nil queue:queue];
    return [self initWithCentralManager:centralManager queue:queue];
}

- (instancetype)initWithCentralManager:(CBCentralManager *)centralManager queue:(dispatch_queue_t)queue
{
    self = [super init];
    if (self != nil) {
        _bleQueue = queue;
        dispatch_queue_set_specific(_bleQueue, WWBLEQueueSpecificKey, (__bridge void *)self, NULL);
        _managerDelegate = nil;
        _centeralManager = centralManager;
        _centeralManager.delegate = self;
        
        _connectionContexts = [NSMutableDictionary dictionary];
        _receiveContexts = [NSMutableDictionary dictionary];
        _readContexts = [NSMutableDictionary dictionary];
        _notifyContexts = [NSMutableDictionary dictionary];
        _writeContexts = [NSMutableDictionary dictionary];
        _silentDisconnects = [NSMutableSet set];
        _pendingDisconnects = [NSMutableSet set];
        
        _bAutoGroupSendData = true;
        
        _nGroupSendDataLen = 20;
    }
    
    return self;
}

- (BOOL)isOnBLEQueue
{
    return dispatch_get_specific(WWBLEQueueSpecificKey) == (__bridge void *)self;
}

- (void)performOnBLEQueueSync:(dispatch_block_t)block
{
    if ([self isOnBLEQueue]) {
        block();
    }
    else {
        dispatch_sync(_bleQueue, block);
    }
}

- (void)performOnBLEQueueAsync:(dispatch_block_t)block
{
    if ([self isOnBLEQueue]) {
        block();
    }
    else {
        dispatch_async(_bleQueue, block);
    }
}

- (NSString *)peripheralKey:(CBPeripheral *)peripheral
{
    return peripheral.identifier.UUIDString ?: [NSString stringWithFormat:@"%p", peripheral];
}

- (NSString *)operationKeyForPeripheral:(CBPeripheral *)peripheral characteristic:(WWCharacteristic *)characteristic
{
    return [NSString stringWithFormat:@"%@|%@|%@",
            [self peripheralKey:peripheral],
            characteristic.serviceID,
            characteristic.characteristicID];
}

- (WWCharacteristic *)snapshotOfCharacteristic:(WWCharacteristic *)characteristic
{
    return [[WWCharacteristic alloc] initWithServiceID:characteristic.serviceID
                                      characteristicID:characteristic.characteristicID];
}

- (BOOL)startNotificationForPeripheral:(CBPeripheral *)peripheral
                         characteristic:(WWCharacteristic *)characteristic
                                 enable:(BOOL)enable
                            synchronous:(BOOL)synchronous
                                context:(WWBLEOperationContext **)contextOut
{
    if (peripheral == nil || characteristic == nil || !characteristic.isHaveValue) {
        return NO;
    }
    WWCharacteristic *characteristicSnapshot = [self snapshotOfCharacteristic:characteristic];

    __block BOOL started = NO;
    __block WWBLEOperationContext *context = nil;
    [self performOnBLEQueueSync:^{
        if (peripheral.state != CBPeripheralStateConnected ||
            [self->_pendingDisconnects containsObject:[self peripheralKey:peripheral]]) {
            return;
        }

        CBService *service = [self getService:characteristicSnapshot.serviceID fromPeripheral:peripheral];
        CBCharacteristic *nativeCharacteristic = [self getCharacteristic:characteristicSnapshot.characteristicID fromService:service];
        CBCharacteristicProperties properties = nativeCharacteristic.properties;
        if (nativeCharacteristic == nil ||
            ((properties & CBCharacteristicPropertyNotify) == 0 &&
             (properties & CBCharacteristicPropertyIndicate) == 0)) {
            return;
        }

        NSString *key = [self operationKeyForPeripheral:peripheral characteristic:characteristicSnapshot];
        if (self->_notifyContexts[key] != nil) {
            return;
        }

        context = [[WWBLEOperationContext alloc] init];
        context.peripheral = peripheral;
        context.characteristic = characteristicSnapshot;
        context.enable = enable;
        context.synchronous = synchronous;
        if (synchronous) {
            context.event = [[WWWaitEvent alloc] init];
            [context.event prepareWait];
        }
        self->_notifyContexts[key] = context;
        [peripheral setNotifyValue:enable forCharacteristic:nativeCharacteristic];
        started = YES;
    }];

    if (contextOut != NULL) {
        *contextOut = context;
    }
    return started;
}

- (BOOL)waitForNotificationContext:(WWBLEOperationContext *)context timeout:(NSUInteger)timeOut
{
    WWWaitResult result = [context.event waitPrepared:timeOut];
    if (result == WWWaitResultWaiting) {
        return NO;
    }
    if (result == WWWaitResultTimeOut) {
        [self performOnBLEQueueSync:^{
            NSString *key = [self operationKeyForPeripheral:context.peripheral characteristic:context.characteristic];
            if (self->_notifyContexts[key] == context) {
                context.abandoned = YES;
            }
        }];
    }
    return result == WWWaitResultSuccess;
}

- (void)finishWriteContext:(WWBLEWriteContext *)context success:(BOOL)success
{
    NSString *key = [self peripheralKey:context.peripheral];
    if (_writeContexts[key] != context) {
        return;
    }
    [_writeContexts removeObjectForKey:key];

    if (!success && context.responseContext != nil) {
        context.responseContext.abandoned = YES;
        [context.responseContext.event waitOver:WWWaitResultFailed];
    }
    id<WWBluetoothLEDelegate> delegate = self.bleDelegate;
    if (context.notifyDelegate &&
        [delegate respondsToSelector:@selector(ble:didSendData:characteristic:result:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [delegate ble:self
              didSendData:context.peripheral
           characteristic:context.characteristic
                   result:success];
        });
    }
}

- (void)pumpWriteContext:(WWBLEWriteContext *)context
{
    if (_writeContexts[[self peripheralKey:context.peripheral]] != context) {
        return;
    }

    if (context.type == CBCharacteristicWriteWithResponse) {
        if (context.nextPacketIndex >= context.packets.count) {
            [self finishWriteContext:context success:YES];
            return;
        }

        NSData *packet = context.packets[context.nextPacketIndex++];
        [context.peripheral writeValue:packet
                     forCharacteristic:context.nativeCharacteristic
                                  type:context.type];
        return;
    }

    while (context.nextPacketIndex < context.packets.count &&
           context.peripheral.canSendWriteWithoutResponse) {
        NSData *packet = context.packets[context.nextPacketIndex++];
        [context.peripheral writeValue:packet
                     forCharacteristic:context.nativeCharacteristic
                                  type:context.type];
    }
    if (context.nextPacketIndex == context.packets.count) {
        [self finishWriteContext:context success:YES];
    }
}

- (BOOL)startSend:(CBPeripheral *)peripheral
    characteristic:(WWCharacteristic *)characteristic
             value:(NSData *)data
              type:(NSNumber *)requestedType
    notifyDelegate:(BOOL)notifyDelegate
   responseContext:(WWBLEOperationContext *)responseContext
{
    if (peripheral == nil || characteristic == nil || !characteristic.isHaveValue || data.length == 0) {
        return NO;
    }
    WWCharacteristic *characteristicSnapshot = [self snapshotOfCharacteristic:characteristic];

    NSData *sendData = data;
    id<WWBluetoothLEManagerData> managerData = self.managerData;
    if ([managerData respondsToSelector:@selector(ble:didPreSend:characteristic:data:)]) {
        sendData = [managerData ble:self
                         didPreSend:peripheral
                     characteristic:characteristicSnapshot
                               data:data];
    }
    if (sendData.length == 0) {
        return NO;
    }

    __block BOOL started = NO;
    [self performOnBLEQueueSync:^{
        NSString *key = [self peripheralKey:peripheral];
        WWBLEOperationContext *receiveContext = self->_receiveContexts[key];
        if (peripheral.state != CBPeripheralStateConnected ||
            [self->_pendingDisconnects containsObject:key] ||
            self->_writeContexts[key] != nil ||
            (receiveContext != nil && receiveContext != responseContext)) {
            return;
        }

        CBService *service = [self getService:characteristicSnapshot.serviceID fromPeripheral:peripheral];
        CBCharacteristic *nativeCharacteristic = [self getCharacteristic:characteristicSnapshot.characteristicID fromService:service];
        if (nativeCharacteristic == nil) {
            return;
        }

        CBCharacteristicWriteType type;
        if (requestedType != nil) {
            type = requestedType.integerValue;
            if (type != CBCharacteristicWriteWithResponse &&
                type != CBCharacteristicWriteWithoutResponse) {
                return;
            }
        }
        else if ((nativeCharacteristic.properties & CBCharacteristicPropertyWrite) != 0) {
            type = CBCharacteristicWriteWithResponse;
        }
        else if ((nativeCharacteristic.properties & CBCharacteristicPropertyWriteWithoutResponse) != 0) {
            type = CBCharacteristicWriteWithoutResponse;
        }
        else {
            return;
        }

        CBCharacteristicProperties requiredProperty = type == CBCharacteristicWriteWithResponse
            ? CBCharacteristicPropertyWrite
            : CBCharacteristicPropertyWriteWithoutResponse;
        if ((nativeCharacteristic.properties & requiredProperty) == 0) {
            return;
        }

        NSUInteger maximumLength = [peripheral maximumWriteValueLengthForType:type];
        if (maximumLength == 0) {
            return;
        }

        NSUInteger packetLength;
        if (self->_bAutoGroupSendData) {
            if (self->_nGroupSendDataLen <= 0) {
                return;
            }
            packetLength = MIN((NSUInteger)self->_nGroupSendDataLen, maximumLength);
        }
        else {
            if (sendData.length > maximumLength) {
                return;
            }
            packetLength = sendData.length;
        }

        NSMutableArray<NSData *> *packets = [NSMutableArray array];
        for (NSUInteger offset = 0; offset < sendData.length; offset += packetLength) {
            NSUInteger length = MIN(packetLength, sendData.length - offset);
            [packets addObject:[sendData subdataWithRange:NSMakeRange(offset, length)]];
        }

        WWBLEWriteContext *context = [[WWBLEWriteContext alloc] init];
        context.peripheral = peripheral;
        context.nativeCharacteristic = nativeCharacteristic;
        context.characteristic = characteristicSnapshot;
        context.packets = packets;
        context.type = type;
        context.notifyDelegate = notifyDelegate;
        context.responseContext = responseContext;
        self->_writeContexts[key] = context;
        started = YES;
        [self pumpWriteContext:context];
    }];
    return started;
}

- (NSData *)sendReceiveInternal:(CBPeripheral *)peripheral
                  characteristic:(WWCharacteristic *)characteristic
                           value:(NSData *)data
                            type:(NSNumber *)requestedType
                         timeout:(NSUInteger)timeOut
{
    WWCharacteristic *responseCharacteristic = self.commonResponeNotifyCharacteristic;
    if ([NSThread isMainThread] || [self isOnBLEQueue] ||
        peripheral == nil || !responseCharacteristic.isHaveValue) {
        return nil;
    }

    WWBLEOperationContext *context = [[WWBLEOperationContext alloc] init];
    context.peripheral = peripheral;
    context.characteristic = [self snapshotOfCharacteristic:responseCharacteristic];
    context.synchronous = YES;
    context.event = [[WWWaitEvent alloc] init];
    [context.event prepareWait];

    __block BOOL started = NO;
    [self performOnBLEQueueSync:^{
        NSString *key = [self peripheralKey:peripheral];
        NSString *readKey = [self operationKeyForPeripheral:peripheral characteristic:context.characteristic];
        if (self->_receiveContexts[key] != nil || self->_readContexts[readKey] != nil) {
            return;
        }
        self->_receiveContexts[key] = context;
        started = [self startSend:peripheral
                   characteristic:characteristic
                            value:data
                             type:requestedType
                   notifyDelegate:NO
                  responseContext:context];
        if (!started) {
            [self->_receiveContexts removeObjectForKey:key];
        }
    }];
    if (!started) {
        return nil;
    }

    WWWaitResult result = [context.event waitPrepared:timeOut];
    [self performOnBLEQueueSync:^{
        NSString *key = [self peripheralKey:peripheral];
        if (self->_receiveContexts[key] == context) {
            if (result == WWWaitResultTimeOut || context.abandoned) {
                context.abandoned = YES;
                WWBLEWriteContext *writeContext = self->_writeContexts[key];
                if (writeContext.responseContext == context) {
                    writeContext.abandoned = YES;
                    if (writeContext.type == CBCharacteristicWriteWithoutResponse) {
                        [self finishWriteContext:writeContext success:NO];
                    }
                }
            }
            else {
                [self->_receiveContexts removeObjectForKey:key];
            }
        }
    }];
    return result == WWWaitResultSuccess ? context.data : nil;
}

- (void)finishConnectionContext:(WWBLEOperationContext *)context success:(BOOL)success
{
    NSString *key = [self peripheralKey:context.peripheral];
    if (_connectionContexts[key] != context) {
        return;
    }
    [_connectionContexts removeObjectForKey:key];

    if (context.synchronous) {
        [context.event waitOver:success ? WWWaitResultSuccess : WWWaitResultFailed];
    }
    else {
        id<WWBluetoothLEConnectDelegate> delegate = self.connectDelegate;
        if (![delegate respondsToSelector:@selector(ble:didConnect:result:)]) {
            return;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [delegate ble:self didConnect:context.peripheral result:success];
        });
    }
}

- (void)failConnectionContextAndDisconnect:(WWBLEOperationContext *)context
{
    NSString *key = [self peripheralKey:context.peripheral];
    if (_connectionContexts[key] != context) {
        return;
    }
    [_silentDisconnects addObject:key];
    [_pendingDisconnects addObject:key];
    [self finishConnectionContext:context success:NO];
    [_centeralManager cancelPeripheralConnection:context.peripheral];
}

- (BOOL)startReadForPeripheral:(CBPeripheral *)peripheral
                characteristic:(WWCharacteristic *)characteristic
                   synchronous:(BOOL)synchronous
                       context:(WWBLEOperationContext **)contextOut
{
    if (peripheral == nil || characteristic == nil || !characteristic.isHaveValue) {
        return NO;
    }
    WWCharacteristic *characteristicSnapshot = [self snapshotOfCharacteristic:characteristic];

    __block BOOL started = NO;
    __block WWBLEOperationContext *context = nil;
    [self performOnBLEQueueSync:^{
        if (peripheral.state != CBPeripheralStateConnected ||
            [self->_pendingDisconnects containsObject:[self peripheralKey:peripheral]]) {
            return;
        }

        CBService *service = [self getService:characteristicSnapshot.serviceID fromPeripheral:peripheral];
        CBCharacteristic *nativeCharacteristic = [self getCharacteristic:characteristicSnapshot.characteristicID fromService:service];
        if (nativeCharacteristic == nil ||
            (nativeCharacteristic.properties & CBCharacteristicPropertyRead) == 0) {
            return;
        }

        NSString *key = [self operationKeyForPeripheral:peripheral characteristic:characteristicSnapshot];
        WWBLEOperationContext *receiveContext = self->_receiveContexts[[self peripheralKey:peripheral]];
        if (self->_readContexts[key] != nil ||
            (receiveContext != nil && [receiveContext.characteristic isEqual:characteristicSnapshot])) {
            return;
        }

        context = [[WWBLEOperationContext alloc] init];
        context.peripheral = peripheral;
        context.characteristic = characteristicSnapshot;
        context.synchronous = synchronous;
        if (synchronous) {
            context.event = [[WWWaitEvent alloc] init];
            [context.event prepareWait];
        }
        self->_readContexts[key] = context;
        [peripheral readValueForCharacteristic:nativeCharacteristic];
        started = YES;
    }];

    if (contextOut != NULL) {
        *contextOut = context;
    }
    return started;
}

- (void)finishReadContext:(WWBLEOperationContext *)context data:(NSData *)data success:(BOOL)success
{
    NSString *key = [self operationKeyForPeripheral:context.peripheral characteristic:context.characteristic];
    if (_readContexts[key] != context) {
        return;
    }
    [_readContexts removeObjectForKey:key];

    if (context.abandoned) {
        return;
    }

    if (context.synchronous) {
        context.data = data;
        [context.event waitOver:success ? WWWaitResultSuccess : WWWaitResultFailed];
    }
    else {
        id<WWBluetoothLEDelegate> delegate = self.bleDelegate;
        if (!success || ![delegate respondsToSelector:@selector(ble:didReceiveData:characteristic:data:)]) {
            return;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [delegate ble:self
           didReceiveData:context.peripheral
           characteristic:context.characteristic
                     data:data];
        });
    }
}

- (void)cancelOperationsForPeripheral:(CBPeripheral *)peripheral
{
    NSString *peripheralKey = [self peripheralKey:peripheral];
    WWBLEOperationContext *connectionContext = _connectionContexts[peripheralKey];
    if (connectionContext != nil) {
        [self finishConnectionContext:connectionContext success:NO];
    }

    WWBLEOperationContext *receiveContext = _receiveContexts[peripheralKey];
    if (receiveContext != nil) {
        [_receiveContexts removeObjectForKey:peripheralKey];
        [receiveContext.event waitOver:WWWaitResultFailed];
    }

    for (NSString *key in [_notifyContexts.allKeys copy]) {
        WWBLEOperationContext *context = _notifyContexts[key];
        if ([[self peripheralKey:context.peripheral] isEqualToString:peripheralKey]) {
            [_notifyContexts removeObjectForKey:key];
            [context.event waitOver:WWWaitResultFailed];
        }
    }

    for (NSString *key in [_readContexts.allKeys copy]) {
        WWBLEOperationContext *context = _readContexts[key];
        if ([[self peripheralKey:context.peripheral] isEqualToString:peripheralKey]) {
            [_readContexts removeObjectForKey:key];
            [context.event waitOver:WWWaitResultFailed];
        }
    }

    WWBLEWriteContext *writeContext = _writeContexts[peripheralKey];
    if (writeContext != nil) {
        [self finishWriteContext:writeContext success:NO];
    }
}

- (void)cancelAllOperations
{
    NSMutableDictionary<NSString *, CBPeripheral *> *peripherals = [NSMutableDictionary dictionary];
    for (WWBLEOperationContext *context in _connectionContexts.allValues) {
        peripherals[[self peripheralKey:context.peripheral]] = context.peripheral;
    }
    for (WWBLEOperationContext *context in _receiveContexts.allValues) {
        peripherals[[self peripheralKey:context.peripheral]] = context.peripheral;
    }
    for (WWBLEOperationContext *context in _notifyContexts.allValues) {
        peripherals[[self peripheralKey:context.peripheral]] = context.peripheral;
    }
    for (WWBLEOperationContext *context in _readContexts.allValues) {
        peripherals[[self peripheralKey:context.peripheral]] = context.peripheral;
    }
    for (WWBLEWriteContext *context in _writeContexts.allValues) {
        peripherals[[self peripheralKey:context.peripheral]] = context.peripheral;
    }
    for (CBPeripheral *peripheral in peripherals.allValues) {
        [self cancelOperationsForPeripheral:peripheral];
    }
    [_silentDisconnects removeAllObjects];
    [_pendingDisconnects removeAllObjects];
}

- (BOOL)isScanning
{
    __block BOOL scanning;
    [self performOnBLEQueueSync:^{
        scanning = self->_isScanning;
    }];
    return scanning;
}

- (WWBleLocalState)loaclState
{
    __block WWBleLocalState state;
    [self performOnBLEQueueSync:^{
        state = self->_loaclState;
    }];
    return state;
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
    NSMutableArray<CBUUID *> * uuids = nil;
    
    if (serviceUUIDs.count > 0) {
        uuids = [NSMutableArray arrayWithCapacity:serviceUUIDs.count];
        
        for (NSString *str in serviceUUIDs) {
            CBUUID *temp = nil;
            @try {
                temp = [CBUUID UUIDWithString:str];
            }
            @catch (__unused NSException *exception) {
                temp = nil;
            }
            
            if (temp == nil) {
                BLELog(@"无效uuid");
                return false;
            }
            else {
                [uuids addObject:temp];
            }
        }
    }
    
    __block BOOL started = NO;
    [self performOnBLEQueueSync:^{
        if (self->_centeralManager.state != CBManagerStatePoweredOn) {
            return;
        }

        NSDictionary *options = isPowerSaving ? nil : @{CBCentralManagerScanOptionAllowDuplicatesKey:@YES};
        [self->_centeralManager scanForPeripheralsWithServices:uuids options:options];
        self->_isScanning = YES;
        started = YES;
    }];
    return started;
}


/**
 *  停止扫描
 *
 */
-(void)stopScan
{
    [self performOnBLEQueueSync:^{
        [self->_centeralManager stopScan];
        self->_isScanning = NO;
    }];
}

/**
 获取已配对的系统连接的设备
 
 @param serviceUUIDs 设备服务
 @return 设备列表
 */
- (NSArray<CBPeripheral *> *)getSystemConnectDevices:(NSArray<NSString *> *)serviceUUIDs
{
    NSMutableArray<CBUUID *> *uuids = @[].mutableCopy;
    
    if (serviceUUIDs != nil) {
        
        for (NSString *str in serviceUUIDs) {
            
            CBUUID *temp = nil;
            @try {
                temp = [CBUUID UUIDWithString:str];
            }
            @catch (__unused NSException *exception) {
                temp = nil;
            }
            
            if (temp == nil) {
                BLELog(@"无效uuid");
                return nil;
            }
            else {
                [uuids addObject:temp];
            }
        }
    }
    
    if (uuids.count == 0) {
        return @[];
    }

    __block NSArray<CBPeripheral *> *devices = nil;
    [self performOnBLEQueueSync:^{
        if (self->_centeralManager.state == CBManagerStatePoweredOn) {
            devices = [self->_centeralManager retrieveConnectedPeripheralsWithServices:uuids];
        }
    }];
    return devices;
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
    NSUUID *identifier = [[NSUUID alloc] initWithUUIDString:identifyUUID];
    if (identifier == nil) {
        return nil;
    }

    __block NSArray *peris = nil;
    [self performOnBLEQueueSync:^{
        if (self->_centeralManager.state == CBManagerStatePoweredOn) {
            peris = [self->_centeralManager retrievePeripheralsWithIdentifiers:@[identifier]];
        }
    }];
    if (peris.count > 0) {
        return peris[0];
    }
    else {
        return nil;
    }
    
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
    if ([NSThread isMainThread] || [self isOnBLEQueue]) {
        BLELog(@"同步连接不能在主线程调用");
        return false;
    }

    if (peripheral == nil) {
        BLELog(@"设备不能为空");
        return false;
    }
    
    WWBLEOperationContext *context = [[WWBLEOperationContext alloc] init];
    context.peripheral = peripheral;
    context.synchronous = YES;
    context.event = [[WWWaitEvent alloc] init];
    [context.event prepareWait];

    __block BOOL started = NO;
    [self performOnBLEQueueSync:^{
        NSString *key = [self peripheralKey:peripheral];
        if (self->_centeralManager.state == CBManagerStatePoweredOn &&
            self->_connectionContexts[key] == nil &&
            ![self->_pendingDisconnects containsObject:key]) {
            self->_connectionContexts[key] = context;
            [self->_centeralManager connectPeripheral:peripheral options:nil];
            started = YES;
        }
    }];
    if (!started) {
        return false;
    }

    WWWaitResult result = [context.event waitPrepared:timeOut];
    
    if (result == WWWaitResultSuccess) {
        return true;
    }
    else{
        [self performOnBLEQueueSync:^{
            NSString *key = [self peripheralKey:peripheral];
            if (self->_connectionContexts[key] == context) {
                context.abandoned = YES;
                [self->_silentDisconnects addObject:key];
                [self->_pendingDisconnects addObject:key];
                [self->_centeralManager cancelPeripheralConnection:peripheral];
            }
        }];
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
        id<WWBluetoothLEConnectDelegate> delegate = self.connectDelegate;
        if ([delegate respondsToSelector:@selector(ble:didConnect:result:)]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [delegate ble:self didConnect:nil result:false];
            });
        }
        return ;
    }

    
    [self performOnBLEQueueAsync:^{
        NSString *key = [self peripheralKey:peripheral];
        if (self->_centeralManager.state != CBManagerStatePoweredOn ||
            self->_connectionContexts[key] != nil ||
            [self->_pendingDisconnects containsObject:key]) {
            id<WWBluetoothLEConnectDelegate> delegate = self.connectDelegate;
            if ([delegate respondsToSelector:@selector(ble:didConnect:result:)]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [delegate ble:self didConnect:peripheral result:NO];
                });
            }
            return;
        }

        WWBLEOperationContext *context = [[WWBLEOperationContext alloc] init];
        context.peripheral = peripheral;
        self->_connectionContexts[key] = context;
        [self->_centeralManager connectPeripheral:peripheral options:nil];
    }];
}


/**
 *  断开连接
 *
 *  @param peripheral           蓝牙设备
 *
 */
-(void)disconnect:(CBPeripheral *)peripheral
{
    [self disconnect:peripheral callBack:NO];
}

/**
 *  断开连接
 *
 *  @param peripheral           蓝牙设备
 *  @param isCallBack           是否进入回调  ble:didDisconnect:
 */
- (void)disconnect:(CBPeripheral *)peripheral callBack:(BOOL)isCallBack
{
    if (peripheral == nil) {
        return;
    }
    
    [self performOnBLEQueueAsync:^{
        NSString *key = [self peripheralKey:peripheral];
        if (peripheral.state == CBPeripheralStateDisconnected &&
            self->_connectionContexts[key] == nil) {
            if ([self->_pendingDisconnects containsObject:key]) {
                return;
            }
            [self->_silentDisconnects removeObject:key];
            [self->_pendingDisconnects removeObject:key];
            [self cancelOperationsForPeripheral:peripheral];
            return;
        }
        [self->_pendingDisconnects addObject:key];
        if (isCallBack) {
            [self->_silentDisconnects removeObject:key];
        }
        else {
            [self->_silentDisconnects addObject:key];
        }
        [self cancelOperationsForPeripheral:peripheral];
        [self->_centeralManager cancelPeripheralConnection:peripheral];
    }];
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
    
    __block NSDictionary<NSString *, NSArray<WWCharacteristic *> *> *result = nil;
    [self performOnBLEQueueSync:^{
        if (peripheral.state != CBPeripheralStateConnected) {
            return;
        }

        NSMutableDictionary<NSString *, NSArray<WWCharacteristic *> *> *dict = [NSMutableDictionary dictionary];
        for (CBService *service in peripheral.services) {
            NSMutableArray<WWCharacteristic *> *array = [NSMutableArray array];
            for (CBCharacteristic *characteristic in service.characteristics) {
                WWCharacteristic *model = [[WWCharacteristic alloc] initWithServiceID:service.UUID.UUIDString
                                                                      characteristicID:characteristic.UUID.UUIDString];
                [array addObject:model];
            }
            dict[service.UUID.UUIDString] = array;
        }
        result = [dict copy];
    }];
    return result;
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
    
    if (characteristic == nil || !characteristic.isHaveValue) {
        BLELog(@"characteristic 无效")
        return 0;
    }
    
    __block CBCharacteristicProperties properties = 0;
    [self performOnBLEQueueSync:^{
        if (peripheral.state != CBPeripheralStateConnected) {
            return;
        }
        CBService *service = [self getService:characteristic.serviceID fromPeripheral:peripheral];
        CBCharacteristic *nativeCharacteristic = [self getCharacteristic:characteristic.characteristicID fromService:service];
        properties = nativeCharacteristic.properties;
    }];
    return properties;
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
    WWCharacteristic *characteristic = self.commonResponeNotifyCharacteristic;
    return [self openNofity:peripheral characteristic:characteristic];
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
    WWCharacteristic *characteristic = self.commonResponeNotifyCharacteristic;
    return [self synchronizedOpenNofity:peripheral characteristic:characteristic time:timeOut];
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
    WWCharacteristic *characteristic = self.commonResponeNotifyCharacteristic;
    return [self closeNofity:peripheral characteristic:characteristic];
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
    WWCharacteristic *characteristic = self.commonResponeNotifyCharacteristic;
    return [self synchronizedCloseNofity:peripheral characteristic:characteristic time:timeOut];
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
    return [self startNotificationForPeripheral:peripheral
                                  characteristic:characteristic
                                          enable:YES
                                     synchronous:NO
                                         context:NULL];
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
    if ([NSThread isMainThread] || [self isOnBLEQueue]) {
        return NO;
    }

    WWBLEOperationContext *context = nil;
    if (![self startNotificationForPeripheral:peripheral
                               characteristic:characteristic
                                       enable:YES
                                  synchronous:YES
                                      context:&context]) {
        return NO;
    }
    return [self waitForNotificationContext:context timeout:timeOut];
    
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
    return [self startNotificationForPeripheral:peripheral
                                  characteristic:characteristic
                                          enable:NO
                                     synchronous:NO
                                         context:NULL];
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
    if ([NSThread isMainThread] || [self isOnBLEQueue]) {
        return NO;
    }

    WWBLEOperationContext *context = nil;
    if (![self startNotificationForPeripheral:peripheral
                               characteristic:characteristic
                                       enable:NO
                                  synchronous:YES
                                      context:&context]) {
        return NO;
    }
    return [self waitForNotificationContext:context timeout:timeOut];
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
    WWCharacteristic *characteristic = self.commonSendCharacteristic;
    return [self send:peripheral characteristic:characteristic value:data];
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
    WWCharacteristic *characteristic = self.commonSendCharacteristic;
    return [self sendReceive:peripheral characteristic:characteristic value:data time:timeOut];
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
    return [self startSend:peripheral
            characteristic:characteristic
                     value:data
                      type:nil
            notifyDelegate:YES
           responseContext:nil];
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
    return [self sendReceiveInternal:peripheral
                      characteristic:characteristic
                               value:data
                                type:nil
                             timeout:timeOut];
}


/**
 *  发送数据
 *
 *  @param peripheral           蓝牙设备
 *  @param characteristic       发送特征值
 *  @param data                 发送数据
 *  @param type                  发送类型
 *
 *  @return 成功true，否则false
 *
 *  @note 回调函数 ble:didSendData:characteristic:result:
 *        若有返回值，则返回到ble:didReceiveData:characteristic:data:
 */
- (BOOL)send:(CBPeripheral *)peripheral characteristic:(WWCharacteristic *)characteristic value:(NSData *)data type:(CBCharacteristicWriteType)type
{
    return [self startSend:peripheral
            characteristic:characteristic
                     value:data
                      type:@(type)
            notifyDelegate:YES
           responseContext:nil];
}

/**
 *  发送接收数据
 *
 *  @param peripheral           蓝牙设备
 *  @param characteristic       发送特征值
 *  @param data                 发送数据
 *  @param type                  发送类型
 *  @param timeOut              超时时间，单位ms
 *
 *  @return 返回的数据，失败为nil
 *
 *  @note 不走回调函数 ble:didSendData:characteristic:result:
 */
- (NSData *)sendReceive:(CBPeripheral *)peripheral characteristic:(WWCharacteristic *)characteristic value:(NSData *)data type:(CBCharacteristicWriteType)type time:(NSUInteger)timeOut
{
    return [self sendReceiveInternal:peripheral
                      characteristic:characteristic
                               value:data
                                type:@(type)
                             timeout:timeOut];
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
    return [self startReadForPeripheral:peripheral
                         characteristic:characteristic
                            synchronous:NO
                                context:NULL];
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
    if ([NSThread isMainThread] || [self isOnBLEQueue]) {
        return nil;
    }

    WWBLEOperationContext *context = nil;
    if (![self startReadForPeripheral:peripheral
                      characteristic:characteristic
                         synchronous:YES
                             context:&context]) {
        return nil;
    }

    WWWaitResult result = [context.event waitPrepared:timeOut];
    if (result == WWWaitResultTimeOut) {
        [self performOnBLEQueueSync:^{
            NSString *key = [self operationKeyForPeripheral:peripheral characteristic:context.characteristic];
            if (self->_readContexts[key] == context) {
                context.abandoned = YES;
            }
        }];
    }
    return result == WWWaitResultSuccess ? context.data : nil;
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
    if (peripheral == nil) {
        return;
    }
    [self performOnBLEQueueAsync:^{
        NSString *key = [self peripheralKey:peripheral];
        if (self->_centeralManager.state == CBManagerStatePoweredOn &&
            peripheral.state == CBPeripheralStateConnected &&
            ![self->_pendingDisconnects containsObject:key]) {
            [peripheral readRSSI];
        }
    }];
}

/**
 取消所有等待
 */
- (void)cancelAllWaitting
{
    [self performOnBLEQueueSync:^{
        for (WWBLEOperationContext *context in self->_connectionContexts.allValues) {
            if (context.synchronous) {
                context.abandoned = YES;
                NSString *key = [self peripheralKey:context.peripheral];
                [self->_silentDisconnects addObject:key];
                [self->_pendingDisconnects addObject:key];
                [context.event waitOver:WWWaitResultFailed];
                [self->_centeralManager cancelPeripheralConnection:context.peripheral];
            }
        }
        for (WWBLEOperationContext *context in self->_receiveContexts.allValues) {
            context.abandoned = YES;
            [context.event waitOver:WWWaitResultFailed];

            NSString *key = [self peripheralKey:context.peripheral];
            WWBLEWriteContext *writeContext = self->_writeContexts[key];
            if (writeContext.responseContext == context) {
                writeContext.abandoned = YES;
                if (writeContext.type == CBCharacteristicWriteWithoutResponse) {
                    [self finishWriteContext:writeContext success:NO];
                }
            }
        }
        for (WWBLEOperationContext *context in self->_notifyContexts.allValues) {
            if (context.synchronous) {
                context.abandoned = YES;
                [context.event waitOver:WWWaitResultFailed];
            }
        }
        for (WWBLEOperationContext *context in self->_readContexts.allValues) {
            if (context.synchronous) {
                context.abandoned = YES;
                [context.event waitOver:WWWaitResultFailed];
            }
        }
    }];
}


//获取服务
-(CBService *)getService:(NSString *)serviceID fromPeripheral:(CBPeripheral *)peripheral
{
    for (CBService *service in peripheral.services) {
        if ([service.UUID.UUIDString caseInsensitiveCompare:serviceID] == NSOrderedSame) {
            return service;
        }
    }
    
    return nil;
}


//获取特征值
-(CBCharacteristic *)getCharacteristic:(NSString *)characteristicID fromService:(CBService *)service
{
    for (CBCharacteristic *charact in service.characteristics) {
        if ([charact.UUID.UUIDString caseInsensitiveCompare:characteristicID] == NSOrderedSame) {
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
        case CBManagerStatePoweredOff:
            _loaclState = WWBleLocalStatePowerOff;
            _isScanning = NO;
            [self cancelAllOperations];
            BLELog(@"power off");
            break;
        case CBManagerStatePoweredOn:
            _loaclState = WWBleLocalStatePowerOn;
            break;
        default:
            _loaclState = WWBleLocalStateUnsupported;
            _isScanning = NO;
            [self cancelAllOperations];
            break;
    }
    WWBleLocalState localState = _loaclState;
    NSNumber *state = @(localState);
    id<WWBluetoothLEManagerDelegate> delegate = self.managerDelegate;
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationChangeLocalState object:state];
        if ([delegate respondsToSelector:@selector(ble:didLocalState:)]) {
            [delegate ble:self didLocalState:localState];
        }
    });
}

//扫描信息代理
-(void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI
{
    id<WWBluetoothLEManagerDelegate> delegate = self.managerDelegate;
    if([delegate respondsToSelector:@selector(ble:didScan:advertisementData:rssi:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [delegate ble:self didScan:peripheral advertisementData:advertisementData rssi:RSSI];
        });
    }
}

//外围蓝牙设备连接代理
-(void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    BLELog(@"WWBluetoothLE  连接ok %@",peripheral);
    NSString *key = [self peripheralKey:peripheral];
    if ([_pendingDisconnects containsObject:key]) {
        [_centeralManager cancelPeripheralConnection:peripheral];
        return;
    }
    WWBLEOperationContext *context = _connectionContexts[key];
    if (context == nil) {
        [_silentDisconnects addObject:key];
        [_pendingDisconnects addObject:key];
        [_centeralManager cancelPeripheralConnection:peripheral];
        return;
    }
    if (context.abandoned) {
        [_centeralManager cancelPeripheralConnection:peripheral];
        return;
    }
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
    
    NSString *key = [self peripheralKey:peripheral];
    BOOL silent = central.state != CBManagerStatePoweredOn ||
        [_silentDisconnects containsObject:key];
    [_silentDisconnects removeObject:key];
    [_pendingDisconnects removeObject:key];

    if (!silent) {
        id<WWBluetoothLEConnectDelegate> delegate = self.connectDelegate;
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationDisconnected object:nil];
            if ([delegate respondsToSelector:@selector(ble:didDisconnect:)]) {
                [delegate ble:self didDisconnect:peripheral];
            }
        });
    }

    [self cancelOperationsForPeripheral:peripheral];
}

//连接外围设备失败代理
-(void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    NSString *key = [self peripheralKey:peripheral];
    [_pendingDisconnects removeObject:key];
    [_silentDisconnects removeObject:key];
    WWBLEOperationContext *context = _connectionContexts[key];
    if (context != nil) {
        [self finishConnectionContext:context success:NO];
    }
}

#pragma mark - CBPeripheral代理函数
//搜索服务
-(void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    WWBLEOperationContext *context = _connectionContexts[[self peripheralKey:peripheral]];
    if (context == nil || context.abandoned) {
        return;
    }

    if (error != nil || peripheral.services.count == 0) {
        BLELog(@"扫描服务异常%@",error)
        [self failConnectionContextAndDisconnect:context];
        return;
    }

    context.pendingServices = [NSMutableSet setWithCapacity:peripheral.services.count];
    for (CBService *service in peripheral.services) {
        [context.pendingServices addObject:[NSValue valueWithNonretainedObject:service]];
        [peripheral discoverCharacteristics:nil forService:service];
    }
}

//扫描特征值
-(void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    WWBLEOperationContext *context = _connectionContexts[[self peripheralKey:peripheral]];
    if (context == nil || context.abandoned) {
        return;
    }

    if (error != nil) {
        [self failConnectionContextAndDisconnect:context];
        return;
    }

    [context.pendingServices removeObject:[NSValue valueWithNonretainedObject:service]];
    if (context.pendingServices.count == 0) {
        [self finishConnectionContext:context success:YES];
    }
}


//通知状态更改
-(void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    WWCharacteristic *model = [[WWCharacteristic alloc] initWithServiceID:characteristic.service.UUID.UUIDString
                                                         characteristicID:characteristic.UUID.UUIDString];
    NSString *key = [self operationKeyForPeripheral:peripheral characteristic:model];
    WWBLEOperationContext *context = _notifyContexts[key];
    if (context == nil) {
        return;
    }

    [_notifyContexts removeObjectForKey:key];
    if (context.abandoned) {
        return;
    }
    BOOL isNotifying = characteristic.isNotifying;
    BOOL success = error == nil && isNotifying == context.enable;
    if (context.synchronous) {
        [context.event waitOver:success ? WWWaitResultSuccess : WWWaitResultFailed];
    }
    else {
        id<WWBluetoothLEDelegate> delegate = self.bleDelegate;
        if (![delegate respondsToSelector:@selector(ble:didNotify:characteristic:enable:result:)]) {
            return;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [delegate ble:self
                didNotify:peripheral
           characteristic:model
                   enable:isNotifying
                   result:success];
        });
    }
}

-(void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    WWCharacteristic *model = [[WWCharacteristic alloc] initWithServiceID:characteristic.service.UUID.UUIDString
                                                         characteristicID:characteristic.UUID.UUIDString];
    NSString *key = [self operationKeyForPeripheral:peripheral characteristic:model];
    WWBLEOperationContext *readContext = _readContexts[key];
    if (readContext != nil) {
        [self finishReadContext:readContext data:characteristic.value success:error == nil];
        return;
    }

    if (error != nil) {
        NSString *peripheralKey = [self peripheralKey:peripheral];
        WWBLEOperationContext *responseContext = _receiveContexts[peripheralKey];
        if (responseContext != nil && [responseContext.characteristic isEqual:model]) {
            BOOL wasAbandoned = responseContext.abandoned;
            responseContext.abandoned = YES;
            if (wasAbandoned) {
                [_receiveContexts removeObjectForKey:peripheralKey];
            }
            WWBLEWriteContext *writeContext = _writeContexts[peripheralKey];
            if (writeContext.responseContext == responseContext) {
                writeContext.abandoned = YES;
                if (writeContext.type == CBCharacteristicWriteWithoutResponse) {
                    [self finishWriteContext:writeContext success:NO];
                }
                else {
                    [responseContext.event waitOver:WWWaitResultFailed];
                }
            }
            else {
                [responseContext.event waitOver:WWWaitResultFailed];
            }
            return;
        }
        BLELog(@"接收数据出错：%@", error);
        return;
    }

    [self receiveData:peripheral updateValueForCharacteristic:characteristic];
}

-(void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    WWBLEWriteContext *context = _writeContexts[[self peripheralKey:peripheral]];
    if (context == nil || context.nativeCharacteristic != characteristic) {
        return;
    }

    if (context.abandoned) {
        [self finishWriteContext:context success:NO];
        return;
    }

    if (error != nil) {
        BLELog(@"下发数据失败：%@",error);
        [self finishWriteContext:context success:NO];
        return;
    }

    [self pumpWriteContext:context];
}

- (void)peripheralIsReadyToSendWriteWithoutResponse:(CBPeripheral *)peripheral
{
    WWBLEWriteContext *context = _writeContexts[[self peripheralKey:peripheral]];
    if (context != nil && context.type == CBCharacteristicWriteWithoutResponse) {
        [self pumpWriteContext:context];
    }
}

-(void)peripheral:(CBPeripheral *)peripheral didReadRSSI:(NSNumber *)RSSI error:(NSError *)error
{
    id<WWBluetoothLEDelegate> delegate = self.bleDelegate;
    if ([delegate respondsToSelector:@selector(ble:didUpdateRssi:rssi:result:)]) {
        BOOL success = error == nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            [delegate ble:self didUpdateRssi:peripheral rssi:RSSI result:success];
        });
    }
}


/**
 通知接收数据返回
 
 @param peripheral 蓝牙设备
 @param characteristic 特征
 */
- (void)receiveData:(CBPeripheral *)peripheral updateValueForCharacteristic:(CBCharacteristic *)characteristic
{
    WWCharacteristic *model = [[WWCharacteristic alloc] initWithServiceID:characteristic.service.UUID.UUIDString
                                                         characteristicID:characteristic.UUID.UUIDString];
    NSData *valueData = characteristic.value;
    id<WWBluetoothLEManagerData> managerData = self.managerData;
    if ([managerData respondsToSelector:@selector(ble:didPreReceive:characteristic:data:)]) {
        valueData = [managerData ble:self
                       didPreReceive:peripheral
                      characteristic:model
                                data:valueData];
    }
    if (valueData == nil) {
        return;
    }

    NSString *key = [self peripheralKey:peripheral];
    WWBLEOperationContext *context = _receiveContexts[key];
    if (context != nil && [context.characteristic isEqual:model]) {
        [_receiveContexts removeObjectForKey:key];
        if (context.abandoned) {
            return;
        }
        context.data = valueData;
        [context.event waitOver:WWWaitResultSuccess];
        return;
    }

    id<WWBluetoothLEDelegate> delegate = self.bleDelegate;
    if ([delegate respondsToSelector:@selector(ble:didReceiveData:characteristic:data:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [delegate ble:self didReceiveData:peripheral characteristic:model data:valueData];
        });
    }
}




@end
