//
//  NSString+Hex.m
//  bleDemo
//
//  Created by wurz on 15/4/14.
//  Copyright (c) 2015年 wurz. All rights reserved.
//

#import "NSString+Hex.h"

@implementation NSString (Hex)

//字符串转hex
+(NSString *)hexToString:(NSData *)data space:(BOOL)bSpace
{
    Byte *by = (Byte *)data.bytes;
    
    NSString *strResult = @"";
    for (NSUInteger i=0; i<data.length; i++) {
        if (bSpace) {
            strResult = [NSString stringWithFormat:@"%@%0.2x ",strResult,by[i]];
        }
        else{
            strResult = [NSString stringWithFormat:@"%@%0.2x",strResult,by[i]];
        }
    }
    
    return strResult;
}

//utf-8转字符串的编码
+(NSString*)utf8ToUnicode:(NSData*)data
{
    NSString *result = [[NSString alloc] initWithData:data  encoding:NSUTF8StringEncoding];
    return result;
}

//utf-8转字符串的编码
+(NSString*)utf8ToUnicode:(unsigned char *)data length:(unsigned int)len
{
    NSData *temp = [NSData dataWithBytes:data length:len];
    NSString *result = [[NSString alloc] initWithData:temp  encoding:NSUTF8StringEncoding];
    return result;
}

@end
