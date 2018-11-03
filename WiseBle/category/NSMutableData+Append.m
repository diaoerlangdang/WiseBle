//
//  NSMutableData+Append.m
//  HealthDevice
//
//  Created by 吴睿智 on 2018/10/15.
//  Copyright © 2018年 wuruizhi. All rights reserved.
//

#import "NSMutableData+Append.h"

@implementation NSMutableData (Append)

/**
 添加1字节数据
 
 @param byte 数据
 */
- (void)appendByte:(Byte)byte
{
    [self appendBytes:&byte length:1];
}

@end
