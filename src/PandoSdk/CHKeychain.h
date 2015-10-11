//
//  CHKeychain.h
//  OutletApp
//
//  Created by liming_llm on 15/3/21.
//  Copyright (c) 2015年 liming_llm. All rights reserved.
//

#ifndef OutletApp_CHKeychain_h
#define OutletApp_CHKeychain_h

#import <Foundation/Foundation.h>

@interface CHKeychain : NSObject

+ (void)save:(NSString *)service data:(id)data;
+ (id)load:(NSString *)service;
+ (void)delete:(NSString *)service;

@end

#endif
