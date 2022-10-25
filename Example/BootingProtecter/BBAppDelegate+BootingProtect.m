//
//  BBAppDelegate+BootingProtect.m
//  BootingProtecter
//
//  Created by cocomanbar on 08/13/2022.
//  Copyright (c) 2022 cocomanbar. All rights reserved.
//

#import "BBAppDelegate+BootingProtect.h"
#import <objc/runtime.h>

static NSString *const kBootingProtectionBackFlag = @"kBootingProtectionBackFlag";
static NSString *const kBootingProtectionCounterKey = @"kBootingProtectionCounterKey";

// 连续3次启动异常，执行fix流程
static NSInteger const kBootingProtectNeedToFix = 3;
// 启动15s后默认重置记录
static CFTimeInterval const kBootingProtectThreshold = 15;

typedef BOOL (^PrivateBoolBlock)(void);
typedef BOOL (^PrivateFixBoolBlock)(BOOL);
typedef void (^PrivateRepairBlock)(PrivateBoolBlock);

@interface BBAppDelegate ()

@property (nonatomic, strong) UIWindow *fixProtectWindow;

@end

@interface NSError (BootingProtect)

+ (instancetype)bootingErrorCode:(NSInteger)code descriptionKey:(NSString *)descriptionKey;

@end

@implementation BBAppDelegate (BootingProtect)

#pragma mark - Setter

/**
 *  执行修复数据前的上报闭包
 */
ReportBlock reportBlock;
- (void)bootingProtectReportBlock:(ReportBlock)block{
    reportBlock = block;
}

/**
 *  执行修复数据的闭包
 */
RepairBlock repairBlock;
- (void)bootingProtectFixBlock:(RepairBlock)block{
    repairBlock = block;
}

/**
 *  业务核心启动检查
 */
WoodpeckerBlock woodpeckerBlock;
- (void)bootingProtectWoodpeckerBlock:(WoodpeckerBlock)block {
    woodpeckerBlock = block;
}

#pragma mark - Load

+ (void)load {
    
    /// 开关状态，下一次生效
    if (![[NSUserDefaults standardUserDefaults] boolForKey:kBootingProtectStateKey]) {
        return;
    }
    
    /// 启动组件计数
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        SEL originalSelector = @selector(application:didFinishLaunchingWithOptions:);
        SEL swizzledSelector = @selector(bootingProtection_application:didFinishLaunchingWithOptions:);
        
        Method originalMethod = class_getInstanceMethod(self, originalSelector);
        Method swizzledMethod = class_getInstanceMethod(self, swizzledSelector);
        
        if (!originalMethod || !swizzledMethod) {
            return;
        }
        
        BOOL addMethod = class_addMethod(self, originalSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod));
        if (addMethod) {
            class_replaceMethod(self, swizzledSelector, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod));
        } else {
            method_exchangeImplementations(originalMethod, swizzledMethod);
        }
        
        /// 统计用户关闭app行为
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(appWillEnterBackground) name:UIApplicationWillResignActiveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(appDidEnterBackground) name:UIApplicationDidEnterBackgroundNotification object:nil];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(appWillEnterForeground) name:UIApplicationWillEnterForegroundNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(appDidBecomeActive) name:UIApplicationDidBecomeActiveNotification object:nil];
        
    });
}

#pragma mark - Notification

+ (void)appWillEnterBackground{
    [self setupFlag:YES];
}

+ (void)appDidEnterBackground{
    [self setupFlag:YES];
}

+ (void)appWillEnterForeground{
    [self setupFlag:NO];
}

+ (void)appDidBecomeActive{
    [self setupFlag:NO];
}

+ (void)setupFlag:(BOOL)backFlag{
    
    [[NSUserDefaults standardUserDefaults] setBool:backFlag forKey:kBootingProtectionBackFlag];
    [[NSUserDefaults standardUserDefaults] synchronize];
}


#pragma mark - Hook

- (BOOL)bootingProtection_application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions{
    
    // 执行修复
    void(^TryFix)(void) = ^(void) {
        PrivateFixBoolBlock fixBlock = ^BOOL(BOOL fixed){
            
            self.fixProtectWindow.windowLevel = UIWindowLevelNormal - 1000;
            
            BootingAt fixStep = fixed ? BootingAtDidFixed : BootingAtCancelFix;
            NSString *reason = fixed ? @"用户选择修复行为" : @"用户取消修复行为";
            if (reportBlock) {
                reportBlock([NSError bootingErrorCode:fixStep descriptionKey:reason]);
            }
            return YES;
        };
        
        [self showAlertForFixContinuousCrashOnCompletion:fixBlock];
    };
    
    // 检查核心业务
    if (woodpeckerBlock) {
        NSArray *results = woodpeckerBlock();
        if ([results.firstObject boolValue] == false) {
            /// 上报异常原因
            if (reportBlock) {
                reportBlock([NSError bootingErrorCode:BootingAtBusiness descriptionKey:@"核心数据检测异常"]);
            }
            TryFix();
            return YES;
        }
    }
    
    // 正常启动流程
    PrivateBoolBlock normalBlock = ^BOOL(void) {
        BOOL result = YES;
        __block NSException *exception_;
        @try {
            result = [self bootingProtection_application:application didFinishLaunchingWithOptions:launchOptions];
        } @catch (NSException *exception) {
            exception_ = exception;
            /// 上报异常原因
            if (reportBlock) {
                reportBlock([NSError bootingErrorCode:BootingAtTryCatch descriptionKey:exception.reason]);
            }
        } @finally {
            if (exception_) {
                /// 试图修复异常
                TryFix();
            }
        }
        return result;
    };
    
    /* ---------- only protect tapping icon launch ---------- */
    if (launchOptions != nil) {
        return normalBlock();
    }
    
    /* ---------- 启动连续闪退保护 ----------*/
    
    // APP活过了阈值时间自动重置启动计数
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kBootingProtectThreshold * NSEC_PER_SEC)), dispatch_get_main_queue(), ^(void){
        
        [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:kBootingProtectionCounterKey];
        [[NSUserDefaults standardUserDefaults] synchronize];
    });
    
    // 统计启动计数
    NSInteger applicationSetupCount = [[NSUserDefaults standardUserDefaults] integerForKey:kBootingProtectionCounterKey];
    [[NSUserDefaults standardUserDefaults] setInteger:(applicationSetupCount + 1) forKey:kBootingProtectionCounterKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    // 执行修复行为
    BOOL backFlag = [[NSUserDefaults standardUserDefaults] boolForKey:kBootingProtectionBackFlag];
    if (applicationSetupCount >= kBootingProtectNeedToFix && !backFlag) {
        
        if (reportBlock) {
            reportBlock([NSError bootingErrorCode:BootingAtWillFix descriptionKey:@"次数达到修复限制，准备执行修复程序"]);
        }
        
        PrivateBoolBlock boolBlock = ^BOOL(void) {
            BOOL result = YES;
            @try {
                result = [self bootingProtection_application:application didFinishLaunchingWithOptions:launchOptions];
            } @catch (NSException *exception) {
                /// 修复过后，执行又出现异常，上报异常原因
                if (reportBlock) {
                    reportBlock([NSError bootingErrorCode:BootingAtUnknow descriptionKey:exception.reason]);
                }
            } @finally {
            }
            
            return result;
        };
        
        PrivateFixBoolBlock fixBlock = ^BOOL(BOOL fixed){
            
            [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:kBootingProtectionCounterKey];
            [[NSUserDefaults standardUserDefaults] synchronize];
            
            self.fixProtectWindow.windowLevel = UIWindowLevelNormal - 1000;
            
            BootingAt fixStep = fixed ? BootingAtDidFixed : BootingAtCancelFix;
            NSString *reason = fixed ? @"用户选择修复行为" : @"用户取消修复行为";
            if (reportBlock) {
                reportBlock([NSError bootingErrorCode:fixStep descriptionKey:reason]);
            }
            
            return boolBlock();
        };
        
        [self showAlertForFixContinuousCrashOnCompletion:fixBlock];
    }
    
    // 正常流程，无需修复
    else{
        return normalBlock();
    }
    
    // 为了整洁，其实不会走到这
    return [self bootingProtection_application:application didFinishLaunchingWithOptions:launchOptions];
}

#pragma mark - Fix Steps

/**
 * 弹Tip询问用户是否修复连续 Crash
 * @param completion 无论用户是否修复，最后执行该 block 一次
 */
- (void)showAlertForFixContinuousCrashOnCompletion:(PrivateFixBoolBlock)completion {
    
    NSString *message = @"检测到数据可能异常，是否尝试修复？";
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"提示" message:message preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        if (completion) {
            completion(NO);
        }
    }];
    UIAlertAction *confirmAction = [UIAlertAction actionWithTitle:@"修复" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        PrivateBoolBlock block = ^BOOL {
            if (completion) {
                return completion(YES);
            }
            return YES;
        };
        [self tryToFixContinuousCrashWithCompletion:block];
    }];
    [alertController addAction:cancelAction];
    [alertController addAction:confirmAction];
    [self presentAlertViewController:alertController];
}

- (void)tryToFixContinuousCrashWithCompletion:(PrivateBoolBlock)completion {
    
    if (repairBlock) {
        RepairCompletionBlock block = ^void{
            if (completion) {
                completion();
            }
        };
        repairBlock(block);
    }else{
        // 正常启动流程
        if (completion) {
            completion();
        }
    }
}

/**
 * 对于代码构建 UI 的项目一般在 didFinishLaunch 方法中初始化 window，
 * 想在 swizzling 方法中 present alertController 需要自己先初始化 window 并提供一个 rootViewController
 */
- (void)presentAlertViewController:(UIAlertController *)alertController {
    
    [self.fixProtectWindow setWindowLevel:(UIWindowLevelNormal + 1000)];
    [self.fixProtectWindow makeKeyAndVisible];
    [self.fixProtectWindow.rootViewController presentViewController:alertController animated:YES completion:nil];
}

/**
 *  fixProtectWindow
 */
- (UIWindow *)fixProtectWindow{
    
    UIWindow *window = objc_getAssociatedObject(self, @selector(fixProtectWindow));
    if (![window isKindOfClass:UIWindow.class]) {
        window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        window.windowLevel = UIWindowLevelNormal - 1000;
        window.backgroundColor = UIColor.whiteColor;
        
        // 自定义fix动画视图，类似tb
        UIViewController *controller = [[UIViewController alloc] init];
        window.rootViewController = controller;
        UILabel *label = [[UILabel alloc] init];
        label.text = @"修复中...";
        [controller.view addSubview:label];
        label.frame = CGRectMake(20, 100, 200, 50);
        
        [self setFixProtectWindow:window];
    }
    return window;
}

- (void)setFixProtectWindow:(UIWindow *)fixProtectWindow{
    
    objc_setAssociatedObject(self, @selector(fixProtectWindow), fixProtectWindow, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

@implementation NSError (BootingProtect)

+ (instancetype)bootingErrorCode:(NSInteger)code descriptionKey:(NSString *)descriptionKey {
    
    NSDictionary *dict;
    if (descriptionKey) {
        dict = @{NSLocalizedDescriptionKey: descriptionKey};
    }
    return [NSError errorWithDomain:@"bootingProtect.init.crash.collect" code:code userInfo:dict];
}

@end
