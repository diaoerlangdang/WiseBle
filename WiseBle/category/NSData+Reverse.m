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
    Byte *b = malloc(self.length);
    Byte *p = (Byte *)(self.bytes);
    for (int i=0; i<self.length; i++) {
        b[i] = p[self.length-1-i];
    }
    
    NSData *temp = [NSData dataWithBytes:b length:self.length];
    free(b);
    b = NULL;
    
    return temp;
}

@end
