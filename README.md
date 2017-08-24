# WiseBle
## 蓝牙操作的类库

## 安装

### CocoaPods
要使用CocoaPods安装wiseBle，请将其集成到您现有的Podfile中，或创建一个新的Podfile:

```ruby
target 'MyApp' do
  pod 'wiseBle'
end
```
然后 `pod install`.

### 手动

将WiseBle文件夹添加到项目中


## 使用方法
```objective-c
#import <wiseBle/WiseBle.h>
```

### WWBluetoothLEManagerData 蓝牙管理数据代理；当不需要预处理发送数据与接收数据时可不实现该代理
``` objective-c 
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

```

### WWBluetoothLEManagerDelegate 蓝牙管理代理

``` objective-c 
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

```

### WWBluetoothLEDelegate 蓝牙连接后代理
  
``` objective-c 

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

```

## 其他

### 微信小程序蓝牙例子见 https://github.com/diaoerlangdang/wechat-BleDemo
