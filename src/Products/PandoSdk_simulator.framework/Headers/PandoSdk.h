//
//  PandoSdk.h
//  PandoSdk version 0.1.0
//
//  Created by liming_llm on 15/3/26.
//  Copyright (c) 2015年 liming_llm. All rights reserved.
//
#import <UIKit/UIKit.h>

@protocol  PandoSdkDelegate;

@interface PandoSdk : NSObject


/*!
 *  @method initWithDelegate:
 *
 *  @param  delegate    The delegate that will receive PandoSdk events.
 *
 *  @discussion         The initialization call.
 */
- (instancetype)initWithDelegate:(id<PandoSdkDelegate>)delegate;

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

/*!
 *  @method stopConfig
 *
 *  @discussion     Stop to configure device while configuring.
 */
- (void)stopConfig;


/*!
 *  @method isDebugOn:
 *
 *  @param  isDebugOn   Set YES to print debug info.
 *
 *  @discussion     Set YES to print debug info.
 */
- (void)isDebugOn:(BOOL)isDebugOn;

@end



/*!
 *  @protocol PandoSdkDelegate
 *
 *  @discussion The delegate of a PandoSdk object must adopt the PandoSdkDelegate protocol. The optional methods provide information about PandoSdk method.
 *
 */
@protocol  PandoSdkDelegate<NSObject>

@optional

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


@end





