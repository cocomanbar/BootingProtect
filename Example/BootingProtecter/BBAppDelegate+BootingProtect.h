//
//  BBAppDelegate+BootingProtect.h
//  BootingProtecter
//
//  Created by cocomanbar on 08/13/2022.
//  Copyright (c) 2022 cocomanbar. All rights reserved.
//

#import "BBAppDelegate.h"

/**
 *  记录连续闪退的整治方案：
 *  通过下发配置是否启动该记录组件
 *
 *  a.通过记录启动次数，用定时器的重置计数的方式来初步判断是否连续闪退
 *  b.屏蔽用户或产品运营主动连续多次滑掉app的误判行为
 *  c.屏蔽后台有可能是被系统主动封掉的行为
 *  d.增加@try捕获异常数据处理错误（解决a.方法找不到、b.集合空值、c.字符串越界等，野指针try不到）
 *  e.增加对核心数据的规范检查判断
 */
NS_ASSUME_NONNULL_BEGIN

/// fix版本上线后勿改对应的数值
typedef NS_ENUM(NSInteger, BootingAt){
    BootingAtUnknow     = 0,
    BootingAtBusiness   = 100,
    BootingAtTryCatch   = 200,
    BootingAtWillFix    = 300,
    BootingAtCancelFix  = 400,
    BootingAtDidFixed   = 500,
};

typedef void (^ReportBlock)(NSError *);
typedef void (^RepairCompletionBlock)(void);
typedef void (^RepairBlock)(RepairCompletionBlock);
typedef NSArray* _Nullable(^WoodpeckerBlock)(void);

/// 组件开关KEY
/// 接口下发组件开启任务
static NSString *const kBootingProtectStateKey = @"kBootingProtectStateKey";

@interface BBAppDelegate (BootingProtect)

/**
 *  执行修复数据前的上报闭包
 */
- (void)bootingProtectReportBlock:(ReportBlock)repairBlock;

/**
 *  执行修复数据的闭包
 */
- (void)bootingProtectFixBlock:(RepairBlock)repairBlock;

/**
 *  业务核心启动检查，返回数据组装
 *      NSArray = @[
 *                  @required 1/0   1通过0不通过
 *                  @optional json  描述信息
 *                  ]
 */
- (void)bootingProtectWoodpeckerBlock:(WoodpeckerBlock)woodpeckerBlock;

@end

NS_ASSUME_NONNULL_END
