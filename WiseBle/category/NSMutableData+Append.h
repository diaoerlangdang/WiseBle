//
//  NSMutableData+Append.h
//  HealthDevice
//
//  Created by 吴睿智 on 2018/10/15.
//  Copyright © 2018年 wuruizhi. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSMutableData (Append)


/**
 添加1字节数据

 @param byte 数据
 */
- (void)appendByte:(Byte)byte;

@end

NS_ASSUME_NONNULL_END
