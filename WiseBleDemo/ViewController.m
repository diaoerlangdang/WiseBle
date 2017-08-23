//
//  ViewController.m
//  WiseBleDemo
//
//  Created by wuruizhi on 2017/4/21.
//  Copyright © 2017年 wuruizhi. All rights reserved.
//

#import "ViewController.h"
#import "WWBluetoothLE.h"
#import "WiseBleData.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    [[WWBluetoothLE shareBLE] openBleLog:true];
    [[WWBluetoothLE shareBLE] openBleLog:false];
    
    [WWBluetoothLE shareBLE].managerData = [WiseBleData shareBLEData];
    
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
