//
//  ViewController.m
//  sdk-example
//
//  Created by liming_llm on 15/7/22.
//  Copyright (c) 2015年 PandoCloud. All rights reserved.
//

#import <ifaddrs.h>
#import <arpa/inet.h>
#import <SystemConfiguration/CaptiveNetwork.h>

#import <PandoSdk/PandoSdk.h>

#import "ViewController.h"
#import "MBProgressHUD.h"

#define DEVICE_SSID @"love-letter"


@interface ViewController ()<UIPickerViewDelegate, UIPickerViewDataSource, UITextFieldDelegate, PandoSdkDelegate> {
    NSArray *_pickerArray;
    UIAlertView *_ssidEmptyAlert;
    PandoSdk *_psdk;
    MBProgressHUD *_HUD;
    NSTimer *checkSSIDTimer;
}

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    _pickerArray = [[NSArray alloc]initWithObjects:@"hotspot", @"smartlink", nil];
    
    _modeText.inputView = _modePicker;
    _modeText.inputAccessoryView = _pickerBar;
    _modeText.delegate = self;
    
    _modePicker.delegate = self;
    _modePicker.dataSource = self;
    
    [_modeText setText:@"hotspot"];
    
    NSString *ssid = [self getCurrentSSID];
    
    if (ssid == nil) {
        [[[UIAlertView alloc]initWithTitle:@""
                                   message:@"当前手机没有连接到任何WiFi网络，请连接到WiFi网络"
                                  delegate:self
                         cancelButtonTitle:@"知道了"
                         otherButtonTitles:nil] show];
    }
    else {
        _ssidText.text = [ssid copy];
    }
}

#pragma mark - pickerView delegate
-(NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView {
    return 1;
}

-(NSInteger) pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    return [_pickerArray count];
}

-(NSString*) pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component {
    return [_pickerArray objectAtIndex:row];
}


#pragma mark - textField delegate
-(void)textFieldDidEndEditing:(UITextField *)textField {
    if (textField == _modeText) {
        NSInteger row = [_modePicker selectedRowInComponent:0];
        _modeText.text = [_pickerArray objectAtIndex:row];
    }
}

#pragma mark - alertView delegate
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    NSString *ssid = [self getCurrentSSID];
    
    if (ssid == nil) {
        [[[UIAlertView alloc]initWithTitle:@""
                                   message:@"当前手机没有连接到任何WiFi网络，请连接到WiFi网络"
                                  delegate:self
                         cancelButtonTitle:@"知道了"
                         otherButtonTitles:nil] show];
    }
    else {
        _ssidText.text = [ssid copy];
    }
}

#pragma maek - pandosdk delegate
- (void)pandoSdk:(PandoSdk *)pandoSdk didConfigDeviceToWiFi:(NSString *)ssid deviceKey:(NSString *)deviceKey error:(NSError *)error {
    
    if (checkSSIDTimer != nil) {
        [checkSSIDTimer invalidate];
    }
    
    [_HUD hide:YES];
    
    if (error != nil) {
        [[[UIAlertView alloc]initWithTitle:@"error"
                                   message:[error localizedDescription]
                                  delegate:nil
                         cancelButtonTitle:@"知道了"
                         otherButtonTitles:nil] show];
    }
    else {
        [[[UIAlertView alloc]initWithTitle:@"success"
                                   message:[NSString stringWithFormat:@"device key = %@", deviceKey]
                                  delegate:nil
                         cancelButtonTitle:@"知道了"
                         otherButtonTitles:nil] show];
    }
}

#pragma mark - IBAction

- (IBAction)pickerDonePressed:(id)sender {
    [_modeText endEditing:YES];
}

- (IBAction)viewTouchDown:(id)sender {
    [[UIApplication sharedApplication] sendAction:@selector(resignFirstResponder) to:nil from:nil forEvent:nil];
}

- (IBAction)configButtonTouchUpInside:(id)sender {
    [[UIApplication sharedApplication] sendAction:@selector(resignFirstResponder) to:nil from:nil forEvent:nil];
    
    _psdk = [[PandoSdk alloc]initWithDelegate:self];
    
    if ([[_modeText text] isEqual:@"hotspot"]) {
        checkSSIDTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                          target:self
                                                        selector:@selector(checkSSID)
                                                        userInfo:nil
                                                         repeats:YES];
    }
    
    [_psdk configDeviceToWiFi:[_ssidText text] password:[_passText text] byMode:[_modeText text]];
    
    _HUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    _HUD.dimBackground = YES;
    
    //_HUD.delegate = self;
}

#pragma mark - local

- (NSString *)getCurrentSSID {
    NSArray *ifs = (__bridge_transfer id)CNCopySupportedInterfaces();
    //NSLog(@"Supported interfaces: %@", ifs);
    id info = nil;
    NSString *ssid = nil;
    for (NSString *ifname in ifs) {
        info = (__bridge_transfer id)CNCopyCurrentNetworkInfo((__bridge CFStringRef)ifname);
        //NSLog(@"%@ => %@", ifnam, info);
        
        if (info == nil) {
            continue;
        }
        
        if (info[@"SSID"]) {
            ssid = info[@"SSID"];
        }
        
        if (info && [info count]) {
            break;
        }
    }
    return ssid;
}

- (void)checkSSID {
    if (![[self getCurrentSSID] isEqualToString:DEVICE_SSID]) {
        //dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, 0.01 * NSEC_PER_SEC);
        //dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        
            [[[UIAlertView alloc]initWithTitle:@""
                                       message:@"当前手机没有连接到"DEVICE_SSID"，请连接，否则无法配置成功"
                                      delegate:nil
                             cancelButtonTitle:@"知道了"
                             otherButtonTitles:nil] show];
        //});
    }
}

@end
