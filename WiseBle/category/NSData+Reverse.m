//
//  NSData+Reverse.m
//  HealthDevice
//
//  Created by 吴睿智 on 2018/12/21.
//  Copyright © 2018年 wuruizhi. All rights reserved.
//

#import "NSData+Reverse.h"

@implementation NSData (Reverse)

/**
 数据翻转
 
 @return 返回翻转的数据
 */
- (NSData *)reverseData
{
    NSMutableData *reversedData = [NSMutableData dataWithLength:self.length];
    Byte *destination = reversedData.mutableBytes;
    const Byte *source = self.bytes;
    for (NSUInteger i=0; i<self.length; i++) {
        destination[i] = source[self.length-1-i];
    }

    return reversedData;
}

@end
