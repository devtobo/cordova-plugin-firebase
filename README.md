[![Build Status](https://travis-ci.org/arnesson/cordova-plugin-firebase.svg?branch=master)](https://travis-ci.org/arnesson/cordova-plugin-firebase)

# cordova-plugin-firebase
This plugin brings push notifications, analytics, event tracking, crash reporting and more from Google Firebase to your Cordova project!
Android and iOS supported.

Donations are welcome and will go towards further development of this project. Use the addresses below to donate.

```
BTC: 1JuXhHMCPHXT2fDfSRUTef9TpE2D67sc9f
ETH: 0x74B5eDEce465fDd360b3b03C6984784140ac742e
BCH: qzu5ffphkcgajn7kd7d90etq82maylz34uqg4uj5jf
LTC: LKnFugRfczVH7qfBrmhzZDknhqxCzz6wJB
XMR: 43ZMMEh5x4miZLMZF3W3faAL5Y44fPBXrFWBVXYePBjwXCvxLuo84Cof8ufXgb4sZLEpSDE3eKr5X7jNPfd4kppr8oMX9uM
Paypal: https://paypal.me/arnesson
```

Thank you for your support!

## Installation
See npm package for versions - https://www.npmjs.com/package/cordova-plugin-firebase

Great installation and setup guide by Medium.com - [https://medium.com/@felipepucinelli/how-to-add-push...](https://medium.com/@felipepucinelli/how-to-add-push-notifications-in-your-cordova-application-using-firebase-69fac067e821)

Install the plugin by running:
```
cordova plugin add cordova-plugin-firebase --APP_DOMAIN=123456.app.goo.gl
```

or adding it to your project's package.json:
```
"cordova-plugin-firebase": {
    "APP_DOMAIN": "123456.app.goo.gl",
},
```

Your APP_DOMAIN is used for Firebase Dynamic Links. You can find it when creating a Dynamic Link, or use a dummy one if you don't need to use dynamic links.

You can use the variables GMS_VERSION and FIREBASE_VERSION to change the version of the libraries for Android.

Download your Firebase configuration files, GoogleService-Info.plist for ios and google-services.json for android, and place them in the root folder of your cordova project:

```
- My Project/
    platforms/
    plugins/
    www/
    config.xml
    google-services.json       <--
    GoogleService-Info.plist   <--
    ...
```

See https://support.google.com/firebase/answer/7015592 for details how to download the files from firebase.

This plugin uses a hook (after prepare) that copies the configuration files to the right place, namely platforms/ios/\<My Project\>/Resources for ios and platforms/android for android.

For iOS, the hook also adds a Shell Script build phase to upload your dSYM to Crashlytics automatically.

For Android, the hook changes your build.gradle files to add the necessary build dependencies and gradle plugins needed. It tries as much as possible not to mess with the rest of the build.gradle, but you might run into issues if you are also modifying this file outside of cordova.


**Note that the Firebase SDK requires the configuration files to be present and valid, otherwise your app will crash on boot or Firebase features won't work.**

### Notes about PhoneGap Build

Hooks does not work with PhoneGap Build. This means you will have to manually make sure the configuration files are included. One way to do that is to make a private fork of this plugin and replace the placeholder config files (see src/ios and src/android) with your actual ones, as well as hard coding your app id and api key in plugin.xml.



## Google Tag Manager
### Android
Download your container-config json file from Tag Manager and add a resource-file node in your config.xml.
```
....
<platform name="android">
    <content src="index.html" />
    <resource-file src="GTM-5MFXXXX.json" target="assets/containers/GTM-5MFXXXX.json" />
    ...
```

## Changing Notification Icon
The plugin will use notification_icon from drawable resources if it exists, otherwise the default app icon will is used.
To set a big icon and small icon for notifications, define them through drawable nodes.  
Create the required styles.xml files and add the icons to the  
`<projectroot>/res/native/android/res/<drawable-DPI>` folders.  

The example below uses a png named "ic_silhouette.png", the app Icon (@mipmap/icon) and sets a base theme.  
From android version 21 (Lollipop) notifications were changed, needing a seperate setting.  
If you only target Lollipop and above, you don't need to setup both.  
Thankfully using the version dependant asset selections, we can make one build/apk supporting all target platforms.  
`<projectroot>/res/native/android/res/values/styles.xml`
```
<?xml version="1.0" encoding="utf-8" ?>
<resources>
    <!-- inherit from the holo theme -->
    <style name="AppTheme" parent="android:Theme.Light">
        <item name="android:windowDisablePreview">true</item>
    </style>
    <drawable name="notification_big">@mipmap/icon</drawable>
    <drawable name="notification_icon">@mipmap/icon</drawable>
</resources>
```
and  
`<projectroot>/res/native/android/res/values-v21/styles.xml`
```
<?xml version="1.0" encoding="utf-8" ?>
<resources>
    <!-- inherit from the material theme -->
    <style name="AppTheme" parent="android:Theme.Material">
        <item name="android:windowDisablePreview">true</item>
    </style>
    <drawable name="notification_big">@mipmap/icon</drawable>
    <drawable name="notification_icon">@drawable/ic_silhouette</drawable>
</resources>
```

## Notification Colors

On Android Lollipop and above you can also set the accent color for the notification by adding a color setting.

`<projectroot>/res/native/android/res/values/colors.xml`
```
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="primary">#FFFFFF00</color>
    <color name="primary_dark">#FF220022</color>
    <color name="accent">#FF00FFFF</color>
</resources>
```


## Methods

### getToken

Get the device token (id):
```
window.FirebasePlugin.getToken(function(token) {
    // save this server-side and use it to push notifications to this device
    console.log(token);
}, function(error) {
    console.error(error);
});
```
Note that token will be null if it has not been established yet

### onTokenRefresh

Register for token changes:
```
window.FirebasePlugin.onTokenRefresh(function(token) {
    // save this server-side and use it to push notifications to this device
    console.log(token);
}, function(error) {
    console.error(error);
});
```
This is the best way to get a valid token for the device as soon as the token is established

### onNotificationOpen

Register notification callback:
```
window.FirebasePlugin.onNotificationOpen(function(notification) {
    console.log(notification);
}, function(error) {
    console.error(error);
});
```
Notification flow:

1. App is in foreground:
    1. User receives the notification data in the JavaScript callback without any notification on the device itself (this is the normal behaviour of push notifications, it is up to you, the developer, to notify the user)
2. App is in background:
    1. User receives the notification message in its device notification bar
    2. User taps the notification and the app opens
    3. User receives the notification data in the JavaScript callback

Notification icon on Android:

[Changing notification icon](#changing-notification-icon)

### grantPermission (iOS only)

Grant permission to recieve push notifications (will trigger prompt):
```
window.FirebasePlugin.grantPermission();
```
### hasPermission

Check permission to recieve push notifications:
```
window.FirebasePlugin.hasPermission(function(data){
    console.log(data.isEnabled);
});
```

### setBadgeNumber

Set a number on the icon badge:
```
window.FirebasePlugin.setBadgeNumber(3);
```

Set 0 to clear the badge
```
window.FirebasePlugin.setBadgeNumber(0);
```

### getBadgeNumber

Get icon badge number:
```
window.FirebasePlugin.getBadgeNumber(function(n) {
    console.log(n);
});
```

### subscribe

Subscribe to a topic:
```
window.FirebasePlugin.subscribe("example");
```

### unsubscribe

Unsubscribe from a topic:
```
window.FirebasePlugin.unsubscribe("example");
```

### unregister

Unregister from firebase, used to stop receiving push notifications. Call this when you logout user from your app. :
```
window.FirebasePlugin.unregister();
```

### logEvent

Log an event using Analytics:
```
window.FirebasePlugin.logEvent("select_content", {content_type: "page_view", item_id: "home"});
```

### setScreenName

Set the name of the current screen in Analytics:
```
window.FirebasePlugin.setScreenName("Home");
```

### setUserId

Set a user id for use in Analytics:
```
window.FirebasePlugin.setUserId("user_id");
```

### setUserProperty

Set a user property for use in Analytics:
```
window.FirebasePlugin.setUserProperty("name", "value");
```

### setAnalyticsCollectionEnabled

Enable/disable analytics collection

```
window.FirebasePlugin.setAnalyticsCollectionEnabled(true); // Enables analytics collection

window.FirebasePlugin.setAnalyticsCollectionEnabled(false); // Disables analytics collection
```

### verifyPhoneNumber (Android only)

Request a verificationId and send a SMS with a verificationCode.
Use them to construct a credenial to sign in the user (in your app).
https://firebase.google.com/docs/auth/android/phone-auth
https://firebase.google.com/docs/reference/js/firebase.auth.Auth#signInWithCredential

NOTE: To use this auth you need to configure your app SHA hash in the android app configuration on firebase console.
See https://developers.google.com/android/guides/client-auth to know how to get SHA app hash.

NOTE: This will only works on physical devices.

```
window.FirebasePlugin.verifyPhoneNumber(number, timeOutDuration, function(credential) {
    console.log(credential);

    // ask user to input verificationCode:
    var code = inputField.value.toString();

    var verificationId = credential.verificationId;

    var signInCredential = firebase.auth.PhoneAuthProvider.credential(verificationId, code);
    firebase.auth().signInWithCredential(signInCredential);
}, function(error) {
    console.error(error);
});
```

### fetch

Fetch Remote Config parameter values for your app:
```
window.FirebasePlugin.fetch(function () {
    // success callback
}, function () {
    // error callback
});
// or, specify the cacheExpirationSeconds
window.FirebasePlugin.fetch(600, function () {
    // success callback
}, function () {
    // error callback
});
```

### activateFetched

Activate the Remote Config fetched config:
```
window.FirebasePlugin.activateFetched(function(activated) {
    // activated will be true if there was a fetched config activated,
    // or false if no fetched config was found, or the fetched config was already activated.
    console.log(activated);
}, function(error) {
    console.error(error);
});
```

### getValue

Retrieve a Remote Config value:
```
window.FirebasePlugin.getValue("key", function(value) {
    console.log(value);
}, function(error) {
    console.error(error);
});
// or, specify a namespace for the config value
window.FirebasePlugin.getValue("key", "namespace", function(value) {
    console.log(value);
}, function(error) {
    console.error(error);
});
```

### getByteArray (Android only)
**NOTE: byte array is only available for SDK 19+**
Retrieve a Remote Config byte array:
```
window.FirebasePlugin.getByteArray("key", function(bytes) {
    // a Base64 encoded string that represents the value for "key"
    console.log(bytes.base64);
    // a numeric array containing the values of the byte array (i.e. [0xFF, 0x00])
    console.log(bytes.array);
}, function(error) {
    console.error(error);
});
// or, specify a namespace for the byte array
window.FirebasePlugin.getByteArray("key", "namespace", function(bytes) {
    // a Base64 encoded string that represents the value for "key"
    console.log(bytes.base64);
    // a numeric array containing the values of the byte array (i.e. [0xFF, 0x00])
    console.log(bytes.array);
}, function(error) {
    console.error(error);
});
```

### getInfo (Android only)

Get the current state of the FirebaseRemoteConfig singleton object:
```
window.FirebasePlugin.getInfo(function(info) {
    // the status of the developer mode setting (true/false)
    console.log(info.configSettings.developerModeEnabled);
    // the timestamp (milliseconds since epoch) of the last successful fetch
    console.log(info.fetchTimeMillis);
    // the status of the most recent fetch attempt (int)
    // 0 = Config has never been fetched.
    // 1 = Config fetch succeeded.
    // 2 = Config fetch failed.
    // 3 = Config fetch was throttled.
    console.log(info.lastFetchStatus);
}, function(error) {
    console.error(error);
});
```

### setConfigSettings (Android only)

Change the settings for the FirebaseRemoteConfig object's operations:
```
var settings = {
    developerModeEnabled: true
}
window.FirebasePlugin.setConfigSettings(settings);
```

### setDefaults (Android only)

Set defaults in the Remote Config:
```
// define defaults
var defaults = {
    // map property name to value in Remote Config defaults
    mLong: 1000,
    mString: 'hello world',
    mDouble: 3.14,
    mBoolean: true,
    // map "mBase64" to a Remote Config byte array represented by a Base64 string
    // Note: the Base64 string is in an array in order to differentiate from a string config value
    mBase64: ["SGVsbG8gV29ybGQ="],
    // map "mBytes" to a Remote Config byte array represented by a numeric array
    mBytes: [0xFF, 0x00]
}
// set defaults
window.FirebasePlugin.setDefaults(defaults);
// or, specify a namespace
window.FirebasePlugin.setDefaults(defaults, "namespace");
```

### startTrace

Start a trace.

```
window.FirebasePlugin.startTrace("test trace", success, error);
```

### incrementCounter

To count the performance-related events that occur in your app (such as cache hits or retries), add a line of code similar to the following whenever the event occurs, using a string other than retry to name that event if you are counting a different type of event:

```
window.FirebasePlugin.incrementCounter("test trace", "retry", success, error);
```

### incrementCounterByValue

Same as incrementCounter, but allows incrementing by a value different than 1:

```
window.FirebasePlugin.incrementCounterByValue("test trace", "retry", 42, success, error);
```

### stopTrace

Stop the trace

```
window.FirebasePlugin.stopTrace("test trace");
```

### sendImmediateTraceCounter

This is a shortcut method for starting a trace, setting a counter value, and then immediately stopping the trace. It can be useful if you're only interested in reporting a numeric value and not a duration-based trace.

```
window.FirebasePlugin.sendImmediateTraceCounter("test trace", "retry", 42, success, error);
```



### sendJavascriptError

Sends a non-fatal error, including a stack trace, to Crashlytics.
The StackTrace.JS library can be useful in extracting a stack trace from a JavaScript Exception, see https://github.com/stacktracejs/error-stack-parser

Here is an example on how to set-up an error handler in your app that will report all uncaught exceptions:

```
var errorHandler = function (errorEvent) {
    var error = errorEvent.error;

    // fileName is supported on some platforms but not all
    var fileName = error.fileName

    try {
        // get a stack trace using stacktrace.js (not included in this plugin)
        var stack = ErrorStackParser.parse(error)
        var stackJsonObj = stack.map(function (frame) {
            return {
                functionName: frame.functionName,
                fileName: frame.fileName,
                lineNumber: frame.lineNumber,
                columnNumber: frame.columnNumber,
            };
        })
        window.FirebasePlugin.sendJavascriptError(error.message, fileName, stackJsonObj)
    } catch (error) {
        console.error('Handled error in firebase report error: ', error)
    }
}

window.addEventListener('error', errorHandler);
```

### sendUserError

Sends a non-fatal error with a message and a group of key/values.

```
var error = new Error("Test Error");
window.FirebasePlugin.sendUserError("Network Error", {url: 'http://www.google.com'});
```

### setCrashlyticsValue

Set a key/value for Crashlytics. Those keys are attached to crash reports and can help figuring out what a user was doing before a crash.

```
window.FirebasePlugin.setCrashlyticsValue("my_key", "my_value");
```

### logCrashlytics

Send a log to Crashlytics. These logs are attached to crash reports and can help figuring out what a user was doing before a crash.

```
window.FirebasePlugin.logCrashlytics("log message");
```


### onDynamicLink

Register a callback to be called when your app is opened with a Dynamic Link. Only one callback can be registered at the same time, registering another callback will unset the first.

```
function onSuccess(eventData) {
    // eventData = { deepLink: string, matchType: 'Weak'|'Strong' }
    console.log("Received dynamic link: ", eventData)
}
function onError(error) {
    console.log("Received dynamic link error: ", error)
}

window.FirebasePlugin.onDynamicLink(onSuccess, onError)
```


### Phone Authentication
**BASED ON THE CONTRIBUTIONS OF**
IOS
https://github.com/silverio/cordova-plugin-firebase

ANDROID
https://github.com/apptum/cordova-plugin-firebase

**((((IOS))): SETUP YOUR PUSH NOTIFICATIONS FIRST, AND VERIFY THAT THEY ARE ARRIVING TO YOUR PHYSICAL DEVICE BEFORE YOU TEST THIS METHOD. USE THE APNS AUTH KEY TO GENERATE THE .P8 FILE AND UPLOAD IT TO FIREBASE.
WHEN YOU CALL THIS METHOD, FCM SENDS A SILENT PUSH TO THE DEVICE TO VERIFY IT.**

This method sends an SMS to the user with the SMS_code and gets the verification id you need to continue the sign in process, with the Firebase JS SDK.

```
window.FirebasePlugin.getVerificationID("+573123456789",function(id) {
    console.log("verificationID: "+id);
}, function(error) {             
    console.error(error);
});
```

Using Ionic2?
```
(<any>window).FirebasePlugin.getVerificationID("+573123456789", id => {
    console.log("verificationID: " + id);
    this.verificationId = id;
}, error => {
    console.log("error: " + error);
});
```
Get the intermediate AuthCredential object
```
var credential = firebase.auth.PhoneAuthProvider.credential(verificationId, SMS_code);
```
Then, you can sign in the user with the credential:
```
firebase.auth().signInWithCredential(credential);
```
Or link to an account
```
firebase.auth().currentUser.linkWithCredential(credential)
```
