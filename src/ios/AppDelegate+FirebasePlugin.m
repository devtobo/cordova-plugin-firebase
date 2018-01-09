#import "AppDelegate+FirebasePlugin.h"
#import "FirebasePlugin.h"
#import "Firebase.h"
#import <objc/runtime.h>
#import <BatchBridge/Batch.h>

#if defined(__IPHONE_10_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
@import UserNotifications;
#endif

// Implement UNUserNotificationCenterDelegate to receive display notification via APNS for devices
// running iOS 10 and above. Implement FIRMessagingDelegate to receive data message via FCM for
// devices running iOS 10 and above.
#if defined(__IPHONE_10_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
@interface AppDelegate () <UNUserNotificationCenterDelegate, FIRMessagingDelegate>
@end
#endif

#define kApplicationInBackgroundKey @"applicationInBackground"

// --- Begin Batch Firebase cold start workaround ---
@interface BAPushCenter : NSObject
+ (BAPushCenter*)instance;
@property NSDictionary* startPushUserInfo;
@end
// --- End Batch Firebase cold start workaround ---


@implementation AppDelegate (FirebasePlugin)

+ (void)load {
    method_exchangeImplementations(
        class_getInstanceMethod(self, @selector(application:didFinishLaunchingWithOptions:)),
        class_getInstanceMethod(self, @selector(firebase_plugin_application:didFinishLaunchingWithOptions:))
    );
    method_exchangeImplementations(
        class_getInstanceMethod(self, @selector(application:continueUserActivity:restorationHandler:)),
        class_getInstanceMethod(self, @selector(firebase_plugin_application:continueUserActivity:restorationHandler:))
    );
}


- (BOOL)firebase_plugin_application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [self firebase_plugin_application:application didFinishLaunchingWithOptions:launchOptions];
    
    if(![FIRApp defaultApp]) {
        [FIRApp configure];
    }
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(tokenRefreshNotification:)
                                                 name:kFIRInstanceIDTokenRefreshNotification object:nil];
    
    self.applicationInBackground = @(YES);
    
    return YES;
}

- (BOOL)firebase_plugin_application:(UIApplication *)application
        continueUserActivity:(NSUserActivity *)userActivity
          restorationHandler:(void (^)(NSArray *))restorationHandler {
   FirebasePlugin* firPlugin = [self.viewController getCommandInstance:@"FirebasePlugin"];
    
    BOOL handled = [[FIRDynamicLinks dynamicLinks]
                    handleUniversalLink:userActivity.webpageURL
                    completion:^(FIRDynamicLink * _Nullable dynamicLink, NSError * _Nullable error) {
                        NSLog(@"FIR Dynamic Link: %@", dynamicLink);
                        if (dynamicLink) {
                            [firPlugin postDynamicLink:dynamicLink];
                        }
                    }];
    
    if (handled) {
        return YES;
    }
    
    return [self firebase_plugin_application:application
                 continueUserActivity:userActivity
                   restorationHandler:restorationHandler];
}

- (void)setApplicationInBackground:(NSNumber *)applicationInBackground {
    objc_setAssociatedObject(self, kApplicationInBackgroundKey, applicationInBackground, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSNumber *)applicationInBackground {
    return objc_getAssociatedObject(self, kApplicationInBackgroundKey);
}


- (void)applicationDidBecomeActive:(UIApplication *)application {
    [self connectToFcm];
    self.applicationInBackground = @(NO);
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    [[FIRMessaging messaging] disconnect];
    self.applicationInBackground = @(YES);
    NSLog(@"Disconnected from FCM");
}

- (void)tokenRefreshNotification:(NSNotification *)notification {
    // Note that this callback will be fired everytime a new token is generated, including the first
    // time. So if you need to retrieve the token as soon as it is available this is where that
    // should be done.
    NSString *refreshedToken = [[FIRInstanceID instanceID] token];
    NSLog(@"InstanceID token: %@", refreshedToken);
    
    // Connect to FCM since connection may have failed when attempted before having a token.
    [self connectToFcm];

    [FirebasePlugin.firebasePlugin sendToken:refreshedToken];
}

- (void)connectToFcm {
    [[FIRMessaging messaging] connectWithCompletion:^(NSError * _Nullable error) {
        if (error != nil) {
            NSLog(@"Unable to connect to FCM. %@", error);
        } else {
            NSLog(@"Connected to FCM.");
            NSString *refreshedToken = [[FIRInstanceID instanceID] token];
            NSLog(@"InstanceID token: %@", refreshedToken);
        }
    }];
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo {
    NSDictionary *mutableUserInfo = [userInfo mutableCopy];
    
    [mutableUserInfo setValue:self.applicationInBackground forKey:@"tap"];
    
    // Pring full message.
    NSLog(@"%@", mutableUserInfo);
    
    [FirebasePlugin.firebasePlugin sendNotification:mutableUserInfo];
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo
    fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {

    NSDictionary *mutableUserInfo = [userInfo mutableCopy];
    
    [mutableUserInfo setValue:self.applicationInBackground forKey:@"tap"];
    
    // Pring full message.
    NSLog(@"%@", mutableUserInfo);
    
    [FirebasePlugin.firebasePlugin sendNotification:mutableUserInfo];
        
    // --- Begin Batch Firebase cold start workaround ---
    if ([BAPushCenter class]) {
        [BAPushCenter instance].startPushUserInfo = userInfo;
    }
    // --- End Batch Firebase cold start workaround ---
}

#if defined(__IPHONE_10_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
- (void)userNotificationCenter:(UNUserNotificationCenter *)center
       willPresentNotification:(UNNotification *)notification
         withCompletionHandler:(void (^)(UNNotificationPresentationOptions))completionHandler {
    NSDictionary *mutableUserInfo = [notification.request.content.userInfo mutableCopy];
    
    [mutableUserInfo setValue:self.applicationInBackground forKey:@"tap"];
    
    // Pring full message.
    NSLog(@"%@", mutableUserInfo);
    
    [FirebasePlugin.firebasePlugin sendNotification:mutableUserInfo];
    [BatchPush handleUserNotificationCenter:center willPresentNotification:notification willShowSystemForegroundAlert:NO];
}

// Receive data message on iOS 10 devices.
- (void)applicationReceivedRemoteMessage:(FIRMessagingRemoteMessage *)remoteMessage {
    // Print full message
    NSLog(@"%@", [remoteMessage appData]);
}
#endif

@end
