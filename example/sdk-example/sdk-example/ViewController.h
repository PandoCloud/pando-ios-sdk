//
//  ViewController.h
//  sdk-example
//
//  Created by liming_llm on 15/7/22.
//  Copyright (c) 2015年 PandoCloud. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ViewController : UIViewController


@property (weak, nonatomic) IBOutlet UIPickerView   *modePicker;
@property (weak, nonatomic) IBOutlet UIToolbar  *pickerBar;
@property (weak, nonatomic) IBOutlet UITextField    *ssidText;
@property (weak, nonatomic) IBOutlet UITextField    *passText;
@property (weak, nonatomic) IBOutlet UITextField    *modeText;
@property (weak, nonatomic) IBOutlet UIButton   *configButton;


@end

