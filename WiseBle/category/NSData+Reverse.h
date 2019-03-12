//
//  NSData+Reverse.h
//  HealthDevice
//
//  Created by 吴睿智 on 2018/12/21.
//  Copyright © 2018年 wuruizhi. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSData (Reverse)



/**
 数据翻转

 @return 返回翻转的数据
 */
- (NSData *)reverseData;

@end

NS_ASSUME_NONNULL_END
