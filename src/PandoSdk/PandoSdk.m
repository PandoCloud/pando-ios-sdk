//
//  PandoSdk.m
//  PandoSdk
//
//  Created by liming_llm on 15/3/30.
//  Copyright (c) 2015年 liming_llm. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <ifaddrs.h>
#import <arpa/inet.h>
#import <SystemConfiguration/CaptiveNetwork.h>

#import "PandoSdk.h"
#import "GCDAsyncSocket.h"
#import "ESPTouchTask.h"
#import "ESPTouchResult.h"
#import "ESP_NetUtil.h"
#import "MQTTKit.h"
#import "CHKeychain.h"

#define TCP_PORT    8890

#define PandoErrorDomain @"com.pandocloud.www"
#define TAG_DEVICE_REGISTER @"device_register"
#define TAG_DEVICE_LOGIN @"device_login"

#define DEVICE_PRODUCT_KEY @"f07fd3f2782ff4964b74d51e89ad0aabf0192ec066"
#define HOST_URL @"https://api.pandocloud.com"
#define DEVICE_REGSTER_PATH @"/v1/devices/registration"
#define DEVICE_LOGIN_PATH @"/v1/devices/authentication"

typedef enum {
    
    ConfigFailed = -1,
    DeviceKeyError = -2,
    UnknowError = -100
    
} PandoErrorFailed;

static MQTTClient *client;
static NSMutableDictionary *connSet;
static NSMutableData *recvData;
static NSString *accessHost;
static int accessPort;


NSString * const kKeyUUID = @"com.PandoCloud.iOSSDK.uuid";
NSString * const kKeyPushToken = @"com.PandoCloud.iOSSDK.pushtoken";

@interface PandoSdk () <GCDAsyncSocketDelegate, PandoSdkDelegate> {
    GCDAsyncSocket *_asyncSocket;
    id<PandoSdkDelegate> _delegate;
    NSTimer *_sendTimer;
    NSString *_deviceKey;
    NSString *_ssid;
    NSString *_password;
    NSString *_bssid;
    NSInteger _tryCounts;
    NSString *_host;
    NSString *_mode;
    BOOL _isHidden;
    BOOL _debugOn;
}

@property (atomic, strong) ESPTouchTask *_esptouchTask;

// the state of the confirm/cancel button
@property (nonatomic, assign) BOOL _isConfirmState;

// without the condition, if the user tap confirm/cancel quickly enough,
// the bug will arise. the reason is follows:
// 0. task is starting created, but not finished
// 1. the task is cancel for the task hasn't been created, it do nothing
// 2. task is created
// 3. Oops, the task should be cancelled, but it is running
@property (nonatomic, strong) NSCondition *_condition;

// create a property for the MQTTClient that is used to send and receive the message
@end

@implementation PandoSdk

+ (void)initGateway {
    
    NSUserDefaults *deviceDefaults = [NSUserDefaults standardUserDefaults];
    
    connSet = [NSMutableDictionary dictionary];
    recvData = [NSMutableData data];
    
    if ([deviceDefaults objectForKey:@"devcie_registered"] == nil ||
        [deviceDefaults objectForKey:@"devcie_registered"] == NO) {
        [PandoSdk deviceSignUp];
    }
    else {

        [PandoSdk deviceSignIn];
    }
}

- (instancetype)initWithDelegate:(id<PandoSdkDelegate>)delegate {
    self = [super init];
    
    if (self != nil) {
        _delegate = delegate;
        _asyncSocket = nil;
        _deviceKey = nil;
        _tryCounts = 0;
        _debugOn = NO;
    }
    
    return self;
}

- (void)isDebugOn:(BOOL)isDebugOn {
    _debugOn = isDebugOn;
}

- (void)stopConfig {
    
    if ([_mode isEqualToString:@"smartlink"]) {
        [self._condition lock];
        if (self._esptouchTask != nil) {
            [self._esptouchTask interrupt];
        }
        [self._condition unlock];
    }
    else if ([_mode isEqualToString:@"hotspot"]) {
        if (_sendTimer != nil) {
            [_sendTimer invalidate];
        }
    }
    
    if (_delegate != nil) {
        [_delegate pandoSdk:self didStopConfig:YES error:nil];
    }
}

- (void)configDeviceToWiFi:(NSString *)ssid password:(NSString *)password byMode:(NSString *)mode {
    
    _ssid = [ssid copy];
    _password = [password copy];
    _bssid = [[self getCurrentBSSID] copy];
    _mode = [mode copy];
    _isHidden = YES;
    
    if ([mode isEqualToString:@"smartlink"]) {
        [self configForResaults];
    }
    else if ([mode isEqualToString:@"hotspot"]) {
        
        _host = [[self getGatewayIpAddr] copy];
        
        NSDictionary *inputData = [NSDictionary dictionaryWithObjectsAndKeys:
                                   _password,
                                   @"password",
                                   @"config",
                                   @"action",
                                   _ssid,
                                   @"ssid", nil];
        
        NSData *jsonInputData = [NSJSONSerialization dataWithJSONObject:inputData options:NSJSONWritingPrettyPrinted error:nil];
        
        
        [self sendData:jsonInputData toHost:_host tag:0];
        
        _sendTimer = [NSTimer scheduledTimerWithTimeInterval:3.0 target:self selector:@selector(checkConfig) userInfo:nil repeats:YES];
    }
    else {
        
    }
    
}

- (void)doRequestToken
{
    _tryCounts++;
    
    if (_tryCounts >= 10)
    {
        [_sendTimer invalidate];
        
        _tryCounts = 0;
        
        NSDictionary *userInfo = [NSDictionary dictionaryWithObject:@"DeviceKey Error" forKey:NSLocalizedDescriptionKey];
        
        NSError *aError = [NSError errorWithDomain:PandoErrorDomain code:DeviceKeyError userInfo:userInfo];
        
        [_delegate pandoSdk:self didConfigDeviceToWiFi:nil deviceKey:nil error:aError];
        
        return;
    }
    
    NSDictionary *data = [NSDictionary dictionaryWithObjectsAndKeys:@"token", @"action", nil];
    
    NSData *jsonInputData = [NSJSONSerialization dataWithJSONObject:data options:NSJSONWritingPrettyPrinted error:nil];
    
    [self sendData:jsonInputData toHost:_host tag:2];
}

- (void)exitConfig
{
    NSDictionary *data = [NSDictionary dictionaryWithObjectsAndKeys:@"exit_config", @"action", nil];
    
    NSData *jsonInputData = [NSJSONSerialization dataWithJSONObject:data options:NSJSONWritingPrettyPrinted error:nil];
    
    [self sendData:jsonInputData toHost:_host tag:3];
    
    [_sendTimer invalidate];
    //sendTimer = [NSTimer scheduledTimerWithTimeInterval:5.0 target:self selector:@selector(waitChangeSSID) userInfo:nil repeats:NO];
    
    if (_delegate != nil)
    {
        [_delegate pandoSdk:self didConfigDeviceToWiFi:_ssid deviceKey:_deviceKey error:nil];
    }
}

- (void)sendData:(NSData *)data toHost:(NSString *)host tag:(long)tag {
    NSError *error = nil;
    
    if (_asyncSocket == nil)
    {
        _asyncSocket = [[GCDAsyncSocket alloc]initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
        _asyncSocket.delegate = self;
    }
    
    if (_asyncSocket.isConnected == NO)
    {
        if ([_asyncSocket connectToHost:host onPort:TCP_PORT withTimeout:-1 error:&error] == YES)
        {
            if (_debugOn == YES) {
                NSLog(@"connectToHost return ok");
            }
        }
    }
    
    UInt32 dataLen = htonl((UInt32)[data length]);
    UInt16 magic = htons(0x7064);
    UInt16 type = htons(0x0001);
    
    NSMutableData *writeData = [NSMutableData dataWithBytes:&magic length:sizeof(magic)];
    [writeData appendData:[NSData dataWithBytes:&type length:sizeof(type)]];
    [writeData appendData:[NSData dataWithBytes:&dataLen length:sizeof(dataLen)]];
    [writeData appendData:data];
    
    //NSString *jsonInputString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    
    if (_debugOn == YES) {
        NSLog(@"write = %@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
    }
    
    [_asyncSocket writeData:writeData withTimeout:-1 tag:tag];
    
    if (tag != 0)
    {
        [_asyncSocket readDataWithTimeout:-1 tag:tag];
    }
}

- (NSString *)getGatewayIpAddr
{
    NSString *address = @"error";
    struct ifaddrs *interfaces = NULL;
    struct ifaddrs *temp_addr = NULL;
    int success = 0;
    
    // retrieve the current interfaces - returns 0 on success
    success = getifaddrs(&interfaces);
    if (success == 0)
    {
        // Loop through linked list of interfaces
        temp_addr = interfaces;
        while (temp_addr != NULL)
        {
            if( temp_addr->ifa_addr->sa_family == AF_INET)
            {
                // Check if interface is en0 which is the wifi connection on the iPhone
                if ([[NSString stringWithUTF8String:temp_addr->ifa_name] isEqualToString:@"en0"])
                {
                    // Get NSString from C String
                    address = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)temp_addr->ifa_addr)->sin_addr)];
                }
            }
            
            temp_addr = temp_addr->ifa_next;
        }
    }
    
    // Free memory
    freeifaddrs(interfaces);
    
    NSString *gatewayIp = nil;
    
    for (int i = (int)[address length] - 1; i > 0; i--)
    {
        if ([address characterAtIndex:i] == '.')
        {
            gatewayIp = [NSString stringWithFormat:@"%@.1", [address substringToIndex:i]];
            break;
        }
        
    }
    
    return gatewayIp;
}

#pragma mark - GCDAsyncSocket

#if 1
- (void)socket:(GCDAsyncSocket *)sock willDisconnectWithError:(NSError *)err
{
    //NSLog(@"willDisconnectWithError");
    //[self logInfo:FORMAT(@"Client Disconnected: %@:%hu", [sock connectedHost], [sock connectedPort])];
    if (err) {
        //NSLog(@"错误报告：%@",err);
    }else{
        //NSLog(@"连接工作正常");
    }
    _asyncSocket = nil;
}

- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(UInt16)port
{
    //NSLog(@"didConnectToHost");
    
    
    
    //[sock readDataWithTimeout:0.5 tag:0];
    
    //[sock readDataWithTimeout:-1 tag:0];
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
    //NSLog(@"didReadData");
    
    if (tag != 0)
    {
        if ([data length] > 8)
        {
            NSData *content = [data subdataWithRange:NSMakeRange(8, [data length] - 8)];
            //NSString *msg = [[NSString alloc] initWithData:strData encoding:NSUTF8StringEncoding];
            
            NSDictionary * respDic = [NSJSONSerialization JSONObjectWithData:content options:NSJSONReadingMutableLeaves error:nil];
            
            if (tag == 1)
            {
                
                if ([[respDic objectForKey:@"code"] isEqualToNumber:[NSNumber numberWithInt:0]]) {
                    [_sendTimer invalidate];
                    _sendTimer = [NSTimer scheduledTimerWithTimeInterval:3.0 target:self selector:@selector(doRequestToken) userInfo:nil repeats:YES];
                }
                else {
                    [_sendTimer invalidate];
                    
                    if (_delegate != nil) {
                        
                        NSDictionary *userInfo = [NSDictionary dictionaryWithObject:@"Config Failed, maybe wrong password" forKey:NSLocalizedDescriptionKey];
                        
                        NSError *aError = [NSError errorWithDomain:PandoErrorDomain code:ConfigFailed userInfo:userInfo];
                        
                        [_delegate pandoSdk:self didConfigDeviceToWiFi:nil deviceKey:nil error:aError];
                    }
                }
            }
            else if (tag == 2)
            {
                _deviceKey = [respDic objectForKey:@"token"];
                
                if (_debugOn == YES) {
                    NSLog(@"token = %@", _deviceKey);
                }
                
                if (_deviceKey != nil)
                {
                    [_sendTimer invalidate];
                    
                    _tryCounts = 0;
                    
                    _sendTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(exitConfig) userInfo:nil repeats:NO];
                }
            }
            
        }
    }
    
    [sock disconnect];
    //[sock readDataWithTimeout:-1 tag:0]; //一直监听网络
}

- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag
{
    //NSLog(@"didWriteDataWithTag %ld", tag);
    if (tag == 3)
    {
        [sock disconnectAfterWriting];
    }
}

- (void)socket:(GCDAsyncSocket *)sock didReadPartialDataOfLength:(NSUInteger)partialLength tag:(long)tag
{
    
    
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err {
    //NSLog(@"socketDidDisconnect:%p withError: %@", sock, err);
}
#endif

#pragma mark - esp

- (void) configForResaults
{
    // do confirm
    //if (self._isConfirmState)
    {
        //[self._spinner startAnimating];
        //[self enableCancelBtn];
        //NSLog(@"ESPViewController do confirm action...");
        dispatch_queue_t  queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        dispatch_async(queue, ^{
            //NSLog(@"ESPViewController do the execute work...");
            // execute the task
            NSArray *esptouchResultArray = [self executeForResults];
            // show the result to the user in UI Main Thread
            dispatch_async(dispatch_get_main_queue(), ^{
                
                //[self._spinner stopAnimating];
                //[self enableConfirmBtn];
                
                ESPTouchResult *firstResult = [esptouchResultArray objectAtIndex:0];
                // check whether the task is cancelled and no results received
                if (!firstResult.isCancelled)
                {
                    NSMutableString *mutableStr = [[NSMutableString alloc]init];
                    NSUInteger count = 0;
                    // max results to be displayed, if it is more than maxDisplayCount,
                    // just show the count of redundant ones
                    const int maxDisplayCount = 5;
                    if ([firstResult isSuc])
                    {
                        
                        for (int i = 0; i < [esptouchResultArray count]; ++i)
                        {
                            ESPTouchResult *resultInArray = [esptouchResultArray objectAtIndex:i];
                            [mutableStr appendString:[resultInArray description]];
                            [mutableStr appendString:@"\n"];
                            count++;
                            if (count >= maxDisplayCount)
                            {
                                break;
                            }
                        }
                        
                        if (count < [esptouchResultArray count])
                        {
                            [mutableStr appendString:[NSString stringWithFormat:@"\nthere's %lu more result(s) without showing\n",(unsigned long)([esptouchResultArray count] - count)]];
                        }
                        
                        NSRange range = [mutableStr rangeOfString:@"inetAddress: "];
                        NSString *ip = [mutableStr substringWithRange:NSMakeRange(range.location + 13, mutableStr.length - range.location - 13 - 2)];
                        
                        _host = [ip copy];
                        
                        _sendTimer = [NSTimer scheduledTimerWithTimeInterval:3.0 target:self selector:@selector(doRequestToken) userInfo:nil repeats:YES];
                    }
                    
                    else
                    {
                        NSDictionary *userInfo = [NSDictionary dictionaryWithObject:@"Config Failed"                                                                      forKey:NSLocalizedDescriptionKey];
                        
                        NSError *aError = [NSError errorWithDomain:PandoErrorDomain code:ConfigFailed userInfo:userInfo];
                        
                        [_delegate pandoSdk:self didConfigDeviceToWiFi:nil deviceKey:nil error:aError];
                        
                    }
                }
                
            });
        });
    }
    
}


- (NSArray *) executeForResults
{
    [self._condition lock];
    NSString *apSsid = _ssid;
    NSString *apPwd = _password;
    NSString *apBssid = _bssid;
    BOOL isSsidHidden = _isHidden;
    int taskCount = 1;
    self._esptouchTask =
    [[ESPTouchTask alloc]initWithApSsid:apSsid andApBssid:apBssid andApPwd:apPwd andIsSsidHiden:isSsidHidden];
    [self._condition unlock];
    NSArray * esptouchResults = [self._esptouchTask executeForResults:taskCount];
    if (_debugOn == YES) {
        NSLog(@"ESPViewController executeForResult() result is: %@",esptouchResults);
    }
    return esptouchResults;
}

- (NSString *)getCurrentBSSID {
    NSArray *ifs = (__bridge_transfer id)CNCopySupportedInterfaces();
    //NSLog(@"Supported interfaces: %@", ifs);
    id info = nil;
    NSString *bssid = nil;
    for (NSString *ifnam in ifs) {
        info = (__bridge_transfer id)CNCopyCurrentNetworkInfo((__bridge CFStringRef)ifnam);
        //NSLog(@"%@ => %@", ifnam, info);
        
        if (info[@"BSSID"]) {
            bssid = info[@"BSSID"];
        }
        
        if (info && [info count]) {
            break;
        }
    }
    return bssid;
}


- (void)checkConfig
{
    NSDictionary *data = [NSDictionary dictionaryWithObjectsAndKeys:@"check_config", @"action", nil];
    
    NSData *jsonInputData = [NSJSONSerialization dataWithJSONObject:data options:NSJSONWritingPrettyPrinted error:nil];
    
    [self sendData:jsonInputData toHost:_host tag:1];
    
    _tryCounts++;
    
    if (_tryCounts >= 200)
    {
        [_sendTimer invalidate];
        
        _tryCounts = 0;
    }
}

+ (void)deviceSignUp {
    
    NSMutableDictionary *UUIDDic = (NSMutableDictionary *)[CHKeychain load:kKeyUUID];
    
    if (UUIDDic == nil) {
        UUIDDic = [NSMutableDictionary dictionary];
        [UUIDDic setObject:[[UIDevice currentDevice].identifierForVendor UUIDString] forKey:kKeyUUID];
        [CHKeychain save:kKeyUUID data:UUIDDic];
        
        
        NSLog(@"no uuid found %@", [[UIDevice currentDevice].identifierForVendor UUIDString]);
    }
    
#if 0
    NSUserDefaults *deviceDefault = [NSUserDefaults standardUserDefaults];
    NSString *pushToken = [deviceDefault objectForKey:@"push_token"];
    
    //将 push token 保存到 keychain 中
    NSMutableDictionary *pushTokenDic = [NSMutableDictionary dictionary];
    if (pushToken != nil) {
        [pushTokenDic setObject:pushToken forKey:@"push_token"];
        [CHKeychain save:kKeyPushToken data:pushTokenDic];
    }
    else {
        pushToken = @"";
    }
#endif
    
    NSDictionary *inputData = [NSDictionary dictionaryWithObjectsAndKeys:DEVICE_PRODUCT_KEY,
                               @"product_key",
                               [UUIDDic objectForKey:kKeyUUID],
                               @"device_code",
                               [NSNumber numberWithInt:2],
                               @"device_type",
                               @"iOS",
                               @"device_module",
                               @"",//pushToken,
                               @"ios_device_token",
                               @"0.1.0",
                               @"version", nil];
    
    NSData *jsonInputData = [NSJSONSerialization dataWithJSONObject:inputData options:NSJSONWritingPrettyPrinted error:nil];
    NSString *jsonInputString = [[NSString alloc] initWithData:jsonInputData encoding:NSUTF8StringEncoding];
    
    NSString *req = [NSString stringWithFormat:@"%@%@", HOST_URL, DEVICE_REGSTER_PATH];
    
    //NSLog(@"req = %@\n%@", req, jsonInputString);
    
    [PandoSdk doRequest:req withContent:jsonInputString tag:TAG_DEVICE_REGISTER];
}

+ (void)deviceSignIn {
    NSUserDefaults *deviceDefault = [NSUserDefaults standardUserDefaults];
    
    NSDictionary *inputData = [NSDictionary dictionaryWithObjectsAndKeys:
                               [deviceDefault objectForKey:@"device_id"],
                               @"device_id",
                               [deviceDefault objectForKey:@"device_secret"],
                               @"device_secret",
                               @"mqtt",
                               @"protocol",nil];
    
    NSData *jsonInputData = [NSJSONSerialization dataWithJSONObject:inputData options:NSJSONWritingPrettyPrinted error:nil];
    NSString *jsonInputString = [[NSString alloc] initWithData:jsonInputData encoding:NSUTF8StringEncoding];
    
    NSString *req = [NSString stringWithFormat:@"%@%@", HOST_URL, DEVICE_LOGIN_PATH];
    
    //NSLog(@"req = %@\n%@", req, jsonInputString);
    
    [PandoSdk doRequest:req withContent:jsonInputString tag:TAG_DEVICE_LOGIN];
}

+ (void) doRequest:(NSString *)reqUrl withContent:(NSString *)content tag:(id)tag {
    NSURL *url = [NSURL URLWithString:[PandoSdk URLEncodedString:reqUrl]];
    NSString *method = @"GET";
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    
    [request addValue:@"application/json; charset=utf-8" forHTTPHeaderField:@"Content-Type"];
    [request addValue:DEVICE_PRODUCT_KEY forHTTPHeaderField:@"Product-Key"];
    
    if (content != nil) {
        [request setHTTPBody: [content dataUsingEncoding:NSUTF8StringEncoding]];
        method = @"POST";
    }
    
    [request setHTTPMethod:method];
    
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    
    NSURLConnection *conn = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:NO];
    [conn setDelegateQueue:queue];
    [conn start];
    
    [connSet setObject:conn forKey:tag];
}

+ (NSString *)URLEncodedString:(NSString *)str
{
    NSString *result = (NSString *)
    CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault,
                                                              (CFStringRef)str,
                                                              NULL,
                                                              CFSTR("!*();+$,%#[] "),
                                                              kCFStringEncodingUTF8));
    return result;
}

#pragma mark - NSURLConnection 回调方法
- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [recvData appendData:data];
    
    NSLog(@"connection : didReceiveData");
}

-(void) connection:(NSURLConnection *)connection didFailWithError: (NSError *)error {

}

- (void) connectionDidFinishLoading: (NSURLConnection*) connection {
    
    NSDictionary *respDic = [NSJSONSerialization JSONObjectWithData:recvData options:NSJSONReadingMutableLeaves error:nil];
    
    NSUserDefaults *deviceDefaults = [NSUserDefaults standardUserDefaults];
    
    if (respDic != nil) {
        if (connection == [connSet objectForKey:TAG_DEVICE_REGISTER]) {
            
            //NSLog(@"device register resp %@", respDic);
            
            if ([[respDic objectForKey:@"code"] isEqualToNumber:[NSNumber numberWithInt:0]]) {
                NSDictionary *data = [respDic objectForKey:@"data"];

                [deviceDefaults setBool:YES forKey:@"devcie_registered"];
                
                if (data != nil) {
                    NSLog(@"device register %@", data);
                    
                    [deviceDefaults setObject:[data objectForKey:@"device_id"] forKey:@"device_id"];
                    [deviceDefaults setObject:[data objectForKey:@"device_secret"] forKey:@"device_secret"];
                    [deviceDefaults setObject:[data objectForKey:@"device_key"] forKey:@"device_key"];
                }
                
                [deviceDefaults synchronize];
                
                [PandoSdk deviceSignIn];
            }
            else {
            }
            
        }
        else if (connection == [connSet objectForKey:TAG_DEVICE_LOGIN]) {
            if ([[respDic objectForKey:@"code"] isEqualToNumber:[NSNumber numberWithInt:0]]) {
                NSDictionary *data = [respDic objectForKey:@"data"];
                NSString *accessAddr = [data objectForKey:@"access_addr"];
                
                if (accessAddr != nil) {
                    NSArray *strs = [accessAddr componentsSeparatedByString:@":"];
                
                    accessHost = [strs[0] copy];
                    accessPort = [strs[1] intValue];
                    
                    
                    NSNumber *deviceId = [deviceDefaults objectForKey:@"device_id"];
                    client = [[MQTTClient alloc] initWithClientId:[NSString stringWithFormat:@"%x", [deviceId intValue]]];
                    
                    // define the handler that will be called when MQTT messages are received by the client
                    [client setMessageHandler:^(MQTTMessage *message) {
                        
                        NSLog(@"recv msg : %@", message.payloadString);
                        
#if 0
                        // the MQTTClientDelegate methods are called from a GCD queue.
                        // Any update to the UI must be done on the main queue
                        dispatch_async(dispatch_get_main_queue(), ^{
                            
                        });
#endif
                    }];
                    
                    
                    // connect the MQTT client
                    [client connectToHost:accessHost completionHandler:^(MQTTConnectionReturnCode code) {
                        
                        NSLog(@"code = %lu", (unsigned long)code);
                        
                        if (code == ConnectionAccepted) {
                            // The client is connected when this completion handler is called
                            
                            //NSLog(@"client is connected with id %@", clientID);
                            
                            // Subscribe to the topic
                            [client subscribe:@"" withCompletionHandler:^(NSArray *grantedQos) {
                                // The client is effectively subscribed to the topic when this completion handler is called
                                NSLog(@"subscribed to topic %@", @"");
                            }];
                        }
                    }];
                    
                }
 
            }
            else {

            }
        }

    }
    else {

    }
    
    recvData = [NSMutableData data];

}


@end



