//
//  BBAppDelegate.m
//  BootingProtecter
//
//  Created by cocomanbar on 08/13/2022.
//  Copyright (c) 2022 cocomanbar. All rights reserved.
//

#import "BBAppDelegate.h"
#import "BBAppDelegate+BootingProtect.h"

@implementation BBAppDelegate

- (BOOL)application:(UIApplication *)application willFinishLaunchingWithOptions:(NSDictionary<UIApplicationLaunchOptionsKey,id> *)launchOptions {
    
    /**
     *  在 ‘willFinishLaunchingWithOptions’中初始化行为
     */
    [self bootingProtectReportBlock:^(NSError * error) {
        /**
         *  附加上报线程堆栈信息，用户态信息等
         */
        NSLog(@"error======> %@", error);
    }];
    
    /**
     *  在 ‘willFinishLaunchingWithOptions’中初始化行为
     */
    [self bootingProtectFixBlock:^(RepairCompletionBlock completionBlock) {
        /**
         *  同步修复
         */
        if (0) {
            NSLog(@"修复好了！");
            if (completionBlock) {
                completionBlock();
            }
        }
        /**
         *  异步修复
         */
        if (1) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                sleep(3); //异步处理逻辑
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSLog(@"修复好了！");
                    if (completionBlock) {
                        completionBlock();
                    }
                });
            });
        }
    }];
    
    /**
     *  在 ‘willFinishLaunchingWithOptions’中初始化行为
     */
    [self bootingProtectWoodpeckerBlock:^NSArray * _Nullable{
        
//        return @[@(0), @"数据库异常~"];
        
        return @[@(1)];
    }];
    
    return YES;
}


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Override point for customization after application launch.
    
    /**
     *  测试开启，下次启动有效，应该交给接口控制下发
     */
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:kBootingProtectStateKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    
    /**
     *  测试一系列异常行为
     */
    
        {
            NSMutableDictionary *dict = [NSMutableDictionary dictionary];
            [dict setObject:nil forKey:@""];
        }
        
    //    {
    //        [[NSObject new] performSelector:@selector(test)];
    //    }
    
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
