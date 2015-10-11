//
//  HttpClient.h
//  PandoSdk
//
//  Created by liming_llm on 15/9/6.
//  Copyright (c) 2015年 liming_llm. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <UIKit/UIKit.h>

@protocol HttpDelegate;

@interface HttpClient : NSObject

@property (readonly, nonatomic) NSData *recvData;

- (instancetype)initWithDelegate:(id<HttpDelegate>)delegate;

@end

@protocol HttpDelegate<NSObject>

@required

@end
