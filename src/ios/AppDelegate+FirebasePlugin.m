#import "AppDelegate+FirebasePlugin.h"
#import "FirebasePlugin.h"
#import "Firebase.h"
#import <objc/runtime.h>

#if __has_include(<BatchBridge/Batch.h>)
#define NEEDS_BATCH_PATCH 1
#import <BatchBridge/Batch.h>
#else
#define NEEDS_BATCH_PATCH 0
#endif


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

#if NEEDS_BATCH_PATCH
// --- Begin Batch Firebase cold start workaround ---
@interface BAPushCenter : NSObject
+ (BAPushCenter*)instance;
@property NSDictionary* startPushUserInfo;
@end
// --- End Batch Firebase cold start workaround ---
#endif


@implementation AppDelegate (FirebasePlugin)

@dynamic delegate;

+ (void)load {
    method_exchangeImplementations(
        class_getInstanceMethod(self, @selector(application:didFinishLaunchingWithOptions:)),
        class_getInstanceMethod(self, @selector(firebase_plugin_application:didFinishLaunchingWithOptions:))
    );
    
    /**
     * We want to implement application:continueUserActivity:restorationHandler: while calling other plugins
     * implementations if there are any.
     * The easiest way is to setup a dummy implememtation if there are none, the swizzle it as normal
     */
    SEL cuaSel = @selector(application:continueUserActivity:restorationHandler:);
    SEL szCuaSel = @selector(firebase_plugin_application:continueUserActivity:restorationHandler:);
    
    Method cuaMethod = class_getInstanceMethod(self, cuaSel);
    Method szCuaMethod = class_getInstanceMethod(self, szCuaSel);
    
    if (!cuaMethod) {
        // Create method that always returns NO if application:continueUserActivity:restorationHandler: is not implemented
        IMP newImplementation = imp_implementationWithBlock(^(__unsafe_unretained id self, va_list argp) {
            return NO;
        });
        class_addMethod(self, cuaSel, newImplementation, method_getTypeEncoding(szCuaMethod));
        cuaMethod = class_getInstanceMethod(self, cuaSel);
    }
    
    // Now exchange implementation with the original method or the dummy method
    method_exchangeImplementations(cuaMethod, szCuaMethod);
}

- (void)setApplicationInBackground:(NSNumber *)applicationInBackground {
    objc_setAssociatedObject(self, kApplicationInBackgroundKey, applicationInBackground, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSNumber *)applicationInBackground {
    return objc_getAssociatedObject(self, kApplicationInBackgroundKey);
}

- (BOOL)firebase_plugin_application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [self firebase_plugin_application:application didFinishLaunchingWithOptions:launchOptions];

    if(![FIRApp defaultApp]) {

        /**
         * Uncomment this to enable RemoteConfig developer mode
         */
        // FIRRemoteConfig *remoteConfig = [FIRRemoteConfig remoteConfig];
        // remoteConfig.configSettings = [[FIRRemoteConfigSettings alloc] initWithDeveloperModeEnabled:YES];

        [FIRApp configure];
    }


    [FIRMessaging messaging].delegate = self;
    
    
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
        
#if NEEDS_BATCH_PATCH
    // --- Begin Batch Firebase cold start workaround ---
    if ([BAPushCenter class]) {
        [BAPushCenter instance].startPushUserInfo = userInfo;
    }
    // --- End Batch Firebase cold start workaround ---
#endif
}


// [START ios_10_data_message]
// Receive data messages on iOS 10+ directly from FCM (bypassing APNs) when the app is in the foreground.
// To enable direct data messages, you can set [Messaging messaging].shouldEstablishDirectChannel to YES.
- (void)messaging:(FIRMessaging *)messaging didReceiveMessage:(FIRMessagingRemoteMessage *)remoteMessage {
    NSLog(@"Received data message: %@", remoteMessage.appData);
}

// [END ios_10_data_message]
#if defined(__IPHONE_10_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
- (void)userNotificationCenter:(UNUserNotificationCenter *)center
       willPresentNotification:(UNNotification *)notification
         withCompletionHandler:(void (^)(UNNotificationPresentationOptions))completionHandler {
    NSDictionary *mutableUserInfo = [notification.request.content.userInfo mutableCopy];

    [mutableUserInfo setValue:self.applicationInBackground forKey:@"tap"];

    // Print full message.
    NSLog(@"%@", mutableUserInfo);

    [FirebasePlugin.firebasePlugin sendNotification:mutableUserInfo];
     
#if NEEDS_BATCH_PATCH
    [BatchPush handleUserNotificationCenter:center willPresentNotification:notification willShowSystemForegroundAlert:NO];
#endif
}

// Receive data message on iOS 10 devices.
- (void)applicationReceivedRemoteMessage:(FIRMessagingRemoteMessage *)remoteMessage {
    // Print full message
    NSLog(@"%@", [remoteMessage appData]);
}
#endif

@end
