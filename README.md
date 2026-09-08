# WiseBle

## 蓝牙操作的类库

当前版本：`1.3.0`

## 1.3.0 更新

- 最低支持版本提高到 iOS 12.0，并补充当前系统所需的蓝牙权限说明。
- 隔离不同设备及不同代操作的状态，修复超时、取消和迟到回调导致的串请求问题。
- 修复连接与服务发现、读写、通知、主动断开、自动分包和 Without Response 背压流程。
- 加强 UUID、特征与十六进制数据校验；通过 58 项回归测试，并增加 CI 构建验证。

## 安装

### CocoaPods
要使用CocoaPods安装wiseBle，请将其集成到您现有的Podfile中，或创建一个新的Podfile:

```ruby
platform :ios, '12.0'

target 'MyApp' do
  pod 'wiseBle', '~> 1.3.0'
end
```
然后 `pod install`.

### 手动

将WiseBle文件夹添加到项目中

## 系统要求与权限

- 最低支持 iOS 12.0。
- 宿主应用必须在 `Info.plist` 中配置 `NSBluetoothAlwaysUsageDescription` 和 `NSBluetoothPeripheralUsageDescription`。
- `synchronizedConnect:time:`、`synchronizedOpenNofity:...`、`synchronizedCloseNofity:...`、`synchronizedReadData:...` 和 `sendReceive:...` 会等待结果，只能在后台线程调用；在主线程或 WiseBle 的 BLE 队列调用会立即失败。

## 操作语义

- 同一台设备一次只执行一个发送操作。`sendReceive` 等待响应期间，同设备的其他发送以及响应特征读取会返回失败；不同设备的操作彼此隔离。
- 同步操作超时、被 `cancelAllWaitting` 取消，或 `sendReceive` 发送/响应失败后，在旧 CoreBluetooth 回调到达或设备断开前，可能与旧回调混淆的重试会返回失败，避免旧结果污染新请求。
- With Response 写入在外设逐包确认后报告结果。Without Response 的成功仅表示全部数据已交给 CoreBluetooth，不表示外设已经收到或处理。
- 自动分包长度必须大于 0，并且实际包长不会超过 CoreBluetooth 为当前写入类型报告的上限。


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
