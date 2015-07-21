### 目录
1. [sdk介绍](#sdk介绍)
2. [准备工作](#准备工作)
3. [wifi设备配置](#wifi设备配置)
4. [工具方法](#工具方法)

### sdk介绍
pando手机sdk是pandocloud物联网云平台针对手机终端提供的物联网开发工具。拥有以下功能：

* **设备配置**：配置设备上网，目前该功能主要针对wifi设备
* **设备发现**：发现周围的设备并获取其信息
* **设备代理**：将连接在手机上的设备（如蓝牙设备）通过sdk和连接上互联网，和其他设备或用户进行交互

### 准备工作
sdk使用步骤如下：

1.下载最新的sdk的framework文件，将其拖入工程目录，并在 “Targets->General->Embedded Binaries” 中添加;        
2.在需要使用sdk的代码中引入头文件即可。
``` objc
#include <PandoSdk/PandoSdk.h>
```


### wifi设备配置
在wifi环境下，app可以利用sdk将当前wifi的ssid和密码发送给wifi设备，如果ssid和密码正确，wifi设备就能成功联网。目前根据设备类型不同，支持两种配置模式：

* **热点模式**(hotspot)：该方法基本原理是设备启动配置模式后，会开启一个wifi热点，用户将手机连接上该wifi（无密码）后，将ssid和密码发送给设备。
* **智能模式**(smartlink):该方法基本原理是app直接将ssid名和密码广播到当前局域网，wifi设备通过抓取探测路由器的包长变化解码出密码信息。该方法不需要用户有额外的操作，体验较好，如果设备支持的情况下，推荐采用该模式。

##### 接口说明：
wifi设备配置由接口PandoSdk提供，相关接口：

###### 1. 初始化
初始化PandoSdk实例
``` objc
/*!
*  @method initWithDelegate:
*
*  @param  delegate    The delegate that will receive PandoSdk events.
*
*  @discussion         The initialization call.
*/
- (instancetype)initWithDelegate:(id<PandoSdkDelegate>)delegate;
```

###### 2. 开始配置
app调用PandoSdk的configDeviceToWiFi方法启动配置：

``` objc
/*!
*  @method configDeviceToWiFi:password:byMode:
*  
*  @param  ssid        The WiFi ssid you want you device to connect to.
*  @param  password    The password of the specified WiFi.
*  @param  mode        The different config method.
*
*  @discussion         Configure device with the specified WiFi ssid & password by different mode.
*/
- (void)configDeviceToWiFi:(NSString *)ssid password:(NSString *)password byMode:(NSString *)mode;
```
> 注意：
参数mode在目前版本的sdk中可以使用的值为“hotspot”或者“smartlink”字符串；如果是hotspot模式，app需保证用户在过程中始终连接设备发出的wifi热点，直至委托方法被调用，app可以提示用户连接或者采用程序自动连接wifi热点。

委托方法：
配置成功或者失败后会调用此方法，配置成功后，会获取到devicekey，devicekey是设备操作的唯一凭证。若error不为nil，则表示失败
``` objc
/*!
*  @method pandoSdk:didConfigDeviceToWiFi:deviceKey:error:
*
*  @param  pandoSdk    The pandoSdk object providing configDeviceToWiFi method.
*  @param  ssid        The WiFi ssid the method configure to.
*  @param  deviceKey   The device key returned from device.
*  @param  error       If an error occurred, the cause of the failure.
*
*  @discussion         This method is invoked when a pandoSdk object ended configDeviceToWifi method.
*/
- (void)pandoSdk:(PandoSdk *)pandoSdk didConfigDeviceToWiFi:(NSString *)ssid deviceKey:(NSString *)deviceKey error:(NSError *)error;
```

###### 3. 结束配置
当用户主动取消配置或者配置出错时，app可以调用stopConfig方法结束配置：

``` objc
/*!
*  @method stopConfig
*
*  @discussion     Stop to configure device while configuring.
*/
- (void)stopConfig;
```
> 注意：如果是hotspot模式，wifi配置成功后app如果需要获取设备信息（devicekey），则需要继续保持手机连接在设备ap上，等获取设备信息成功后，再调用stopConfig结束配置并断开和热点的连接

委托方法：
``` objc
/*!
*  @method pandoSdk:didStopConfig:error:
*
*  @param  pandoSdk    The pandoSdk object providing stopConfig method.
*  @param  isStoped
*  @param  error       If an error occurred, the cause of the failure.
*
*  @discussion         This method is invoked when a pandoSdk object ended stopConfig method.
*/
- (void)pandoSdk:(PandoSdk *)pandoSdk didStopConfig:(BOOL)isStoped error:(NSError *)error;
```

### 工具方法
TODO
