/**
 * Copyright (c) 2015-present, Facebook, Inc.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#import "AppDelegate.h"
#import "LYJNavigationController.h"
#import "LYJTabBarController.h"
#import "GpsManager.h"


@interface AppDelegate ()

@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
  
  [Networking startCheckNetworkStatus]; // 开启监控网络
  
  [self getLocationLatitudeAndLongitude]; // 获取经纬度
  
  [RCIMDataSource initRongCloud]; // 初始化融云
  
  [LYJUMengHelper startWithLaunchOptions:launchOptions delegate:self]; // 开启友盟推送
  
  [application setStatusBarHidden:NO withAnimation:UIStatusBarAnimationFade];
  
  [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleLightContent];
  
  self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
  
  if ([Tools comperStingIsEmpty:LYJTicket]) {
    LYJNavigationController *nav = [[LYJNavigationController alloc] initWithRootViewController:[[NSClassFromString(@"LoginViewController") alloc] init]];
    self.window.rootViewController = nav;
  } else {
    [UserCache sharedManager].isLogged = YES;
    [LYJHttpTools getCurrentVersionInfo];
    self.window.rootViewController = self.tabBarController;
  }
  [self.window makeKeyAndVisible];

  return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {
  DLog(@"---- 将要失去焦点，从前台进入后台")
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
  DLog(@"---- 已经进入后台")
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
  DLog(@"---- 将要从后台进入前台，但未获取焦点")
//  // 进行 ticketlogin、getcurrversion 校验
//  if (![Tools comperStingIsEmpty:LYJTicket]) {
//    [LYJHttpTools verifyTicketLogin];
//    [LYJHttpTools getCurrentVersionInfo];
//  }
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
  DLog(@"---- 已经获取焦点")
}

- (void)applicationWillTerminate:(UIApplication *)application {
  DLog(@"---- 将要结束时需要执行的操作")
}

#pragma mark --
#pragma mark -- 推送相关
- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
  DLog(@"---- 注册推送 deviceToken")
  NSString *deviceTokenStr = [[[[deviceToken description] stringByReplacingOccurrencesOfString: @"<" withString: @""] stringByReplacingOccurrencesOfString: @">" withString: @""] stringByReplacingOccurrencesOfString: @" " withString: @""];
  DLog(@"---- 注册推送 deviceToken = %@", deviceTokenStr)
  [LYJUMengHelper registerDeviceToken:deviceToken];
  [[RCIMClient sharedRCIMClient] setDeviceToken:deviceTokenStr];
  [LYJUserDefaults setObject:deviceTokenStr forKey:@"LYJPushDeviceToken"];
  [LYJUserDefaults synchronize];
}
// iOS10之前接收消息，前后台接收到推送消息
- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
  if([[[UIDevice currentDevice] systemVersion] intValue] < 10) {
    [LYJUMengHelper setAutoAlert:NO];
    [LYJUMengHelper didReceiveRemoteNotification:userInfo];
    if ([UIApplication sharedApplication].applicationState == UIApplicationStateActive) {
      // 处于前台时-远程推送，直接进行展示操作
      [LYJUMengHelper showCustomAlertViewWithUserInfo:userInfo clickNotification:NO];
    } else {
      // 处于后台时-远程推送，点击方法处理
      [LYJUMengHelper showCustomAlertViewWithUserInfo:userInfo clickNotification:YES];
    }
    completionHandler(UIBackgroundFetchResultNewData);
  }
}

//iOS10新增：处理前台收到通知的代理方法
- (void)userNotificationCenter:(UNUserNotificationCenter *)center willPresentNotification:(UNNotification *)notification withCompletionHandler:(void (^)(UNNotificationPresentationOptions))completionHandler {
  NSDictionary * userInfo = notification.request.content.userInfo;
//  if([notification.request.trigger isKindOfClass:[UNPushNotificationTrigger class]]) {
//    //应用处于前台时的远程推送接受
//  } else {
//    //应用处于前台时的本地推送接受
//  }
  // 处于前台时-远程推送，直接进行展示操作
  [LYJUMengHelper setAutoAlert:NO];
  [LYJUMengHelper didReceiveRemoteNotification:userInfo];
  [LYJUMengHelper showCustomAlertViewWithUserInfo:userInfo clickNotification:NO];
  completionHandler(UNNotificationPresentationOptionAlert);

}
//iOS10新增：处理前后台点击通知的代理方法
- (void)userNotificationCenter:(UNUserNotificationCenter *)center didReceiveNotificationResponse:(UNNotificationResponse *)response withCompletionHandler:(void (^)(void))completionHandler {
  NSDictionary * userInfo = response.notification.request.content.userInfo;
//  if([response.notification.request.trigger isKindOfClass:[UNPushNotificationTrigger class]]) {
//    //应用处于后台时的远程推送接受
//  } else {
//    //应用处于后台时的本地推送接受
//  }
  // 处于前后台时-远程推送，点击方法处理
  [LYJUMengHelper setAutoAlert:NO];
  [LYJUMengHelper didReceiveRemoteNotification:userInfo];
  [LYJUMengHelper showCustomAlertViewWithUserInfo:userInfo clickNotification:YES];
}

#pragma mark --
#pragma mark -- 获取经纬度
- (void)getLocationLatitudeAndLongitude {
  // 首先对经纬度进行空值设置，防止崩溃
  [LYJUserDefaults setObject:@"" forKey:@"LYJLatitude"]; // 纬度
  [LYJUserDefaults setObject:@"" forKey:@"LYJLongitude"]; // 经度
  [LYJUserDefaults setObject:@"" forKey:@"LYJProvince"];
  [LYJUserDefaults setObject:@"" forKey:@"LYJCity"];
  [LYJUserDefaults synchronize];
  
  [GpsManager getCurrentLocation:^(NSString * _Nonnull pName, NSString * _Nonnull cName, NSString * _Nonnull latitude, NSString * _Nonnull longitude, ErrType errType) {
    // 手机登录、票据登录、院内登录、注册
    if ([pName isEqualToString:@"全国"]) {
      pName = @"";
    }
    if ([cName isEqualToString:@"全国"]) {
      cName = @"";
    }
    // 更新经纬度坐标
    [LYJUserDefaults setObject:LYJEmptStr(latitude) forKey:@"LYJLatitude"]; // 纬度
    [LYJUserDefaults setObject:LYJEmptStr(longitude) forKey:@"LYJLongitude"]; // 经度
    [LYJUserDefaults setObject:LYJEmptStr(pName) forKey:@"LYJProvince"];
    [LYJUserDefaults setObject:LYJEmptStr(cName) forKey:@"LYJCity"];
    [LYJUserDefaults synchronize];
  }];
}

#pragma mark --
#pragma mark -- 懒加载创建 tabbarController
- (LYJTabBarController *)tabBarController {
  if (!_tabBarController) {
    _tabBarController = [[LYJTabBarController alloc] init];
    _tabBarController.selectedIndex = 0;
  }
  return _tabBarController;
}

@end
