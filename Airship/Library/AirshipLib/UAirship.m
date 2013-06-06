/*
Copyright 2009-2012 Urban Airship Inc. All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
list of conditions and the following disclaimer.

2. Redistributions in binaryform must reproduce the above copyright notice,
this list of conditions and the following disclaimer in the documentation
and/or other materials provided withthe distribution.

THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC``AS IS'' AND ANY EXPRESS OR
IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
EVENT SHALL URBAN AIRSHIP INC OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

#import <CoreLocation/CoreLocation.h>
#import "UAirship.h"
#import "UAirship+Internal.h"

#import "UAUser.h"
#import "UAAnalytics+Internal.h"
#import "UAEvent.h"
#import "UAUtils.h"
#import "UAKeychainUtils.h"
#import "UALocationService.h"
#import "UAGlobal.h"
#import "UAPush.h"
#import "UAConfig.h"
#import "UAInboxPushHandler.h"

#import "UABaseAppDelegateSurrogate.h"
#import "UAAutoAppDelegate.h"

UA_VERSION_IMPLEMENTATION(UAirshipVersion, UA_VERSION)

//Exceptions
NSString * const UAirshipTakeOffBackgroundThreadException = @"UAirshipTakeOffBackgroundThreadException";

static UAirship *_sharedAirship;

// Logging info
// Default to ON and DEBUG - options/plist will override
BOOL uaLoggingEnabled = YES;
UALogLevel uaLogLevel = UALogLevelUndefined;

@implementation UAirship

#pragma mark -
#pragma mark Logging
+ (void)setLogging:(BOOL)value {
    uaLoggingEnabled = value;
}

+ (void)setLogLevel:(UALogLevel)level {
    uaLogLevel = level;
}

+ (void)load {
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:[UAirship class] selector:@selector(recordAppLaunchWithNotification:) name:UIApplicationDidFinishLaunchingNotification object:nil];
    [center addObserver:[UAirship class] selector:@selector(handleAppTerminationNotification:) name:UIApplicationWillTerminateNotification object:nil];

}

#pragma mark -
#pragma mark Location Get/Set Methods

- (UALocationService *)locationService {
    if (!_locationService) {
        _locationService = [[UALocationService alloc] init];
    }

    return _locationService;
}

#pragma mark -
#pragma mark Object Lifecycle
- (void)dealloc {
    self.appId = nil;
    self.appSecret = nil;
    self.server = nil;
    self.config = nil;
    
    // Analytics contains an NSTimer, and the invalidate method is required
    // before dealloc
    [self.analytics invalidate];
    self.analytics = nil;
    self.locationService = nil;
    
    [super dealloc];
}

- (id)initWithId:(NSString *)appkey identifiedBy:(NSString *)secret {
    if (self = [super init]) {
        self.appId = appkey;
        self.appSecret = secret;
    }
    return self;
}

+ (void)takeOff {
    [UAirship takeOff:[UAConfig defaultConfig]];
}

+ (void)takeOff:(UAConfig *)config {

    // takeOff needs to be run on the main thread
    if (![[NSThread currentThread] isMainThread]) {
        NSException *mainThreadException = [NSException exceptionWithName:UAirshipTakeOffBackgroundThreadException
                                                                   reason:@"UAirship takeOff must be called on the main thread."
                                                                 userInfo:nil];
        [mainThreadException raise];
    }

    dispatch_once(&takeOffPred_, ^{
        [UAirship executeUnsafeTakeOff:config];
    });
}

/*
 * This is an unsafe version of takeOff - use takeOff: instead for dispatch_once
 */
+ (void)executeUnsafeTakeOff:(UAConfig *)config {
    // Airships only take off once!
    if (_sharedAirship) {
        return;
    }

    [UAirship setLogLevel:config.logLevel];

    // Ensure that app credentials have been passed in
    if (![config validate]) {

        UA_LERR(@"The AirshipConfig.plist file is missing and no application credentials were specified at runtime.");

        //Use blank credentials to prevent app from crashing while error msg
        //is displayed
        _sharedAirship = [[UAirship alloc] initWithId:@"" identifiedBy:@""];
        _sharedAirship.config = config;
        return;
    }

    //TODO: dispatch once for takeoff?

    _sharedAirship = [[UAirship alloc] initWithId:config.appKey identifiedBy:config.appSecret];
    _sharedAirship.config = config;
    _sharedAirship.server = config.deviceAPIURL;

    UA_LINFO(@"App Key: %@", _sharedAirship.appId);
    UA_LINFO(@"App Secret: %@", _sharedAirship.appSecret);
    UA_LINFO(@"Server: %@", _sharedAirship.server);

    if (config.handleNotificationsAutomatically) {

        _sharedAirship.appDelegate = [[[UABaseAppDelegateSurrogate alloc ]init] autorelease];

        //swap pointers with the initial app delegate
        @synchronized ([UIApplication sharedApplication]) {
            _sharedAirship.appDelegate.defaultAppDelegate = [UIApplication sharedApplication].delegate;
            _sharedAirship.appDelegate.surrogateDelegate = [[[UAAutoAppDelegate alloc] init] autorelease];
            [UIApplication sharedApplication].delegate = _sharedAirship.appDelegate;
        }
    }


    // Build a custom user agent with the app key and name
    [_sharedAirship configureUserAgent];

    // Set up analytics
    _sharedAirship.analytics = [[[UAAnalytics alloc] initWithConfig:_sharedAirship.config] autorelease];

    /*
     * Handle Debug Options
     */

    //For testing, set this value in AirshipConfig to clear out
    //the keychain credentials, as they will otherwise be persisted
    //even when the application is uninstalled.
    if (config.clearKeychain) {

        UA_LDEBUG(@"Deleting the keychain credentials");
        [UAKeychainUtils deleteKeychainValue:[[UAirship shared] appId]];

        UA_LDEBUG(@"Deleting the UA device ID");
        [UAKeychainUtils deleteKeychainValue:kUAKeychainDeviceIDKey];
    }


    // The singleton is now ready for use!
    _sharedAirship.ready = true;


    //create/setup user (begin listening for device token changes)
    [[UAUser defaultUser] initializeUser];
}

+ (void)recordAppLaunchWithNotification:(NSNotification *)notification {

    if (!_sharedAirship) {
        UA_LERR(@"[UAirship takeOff] was not called in application:didFinishLaunchingWithOptions:");
    }

    [[NSNotificationCenter defaultCenter] removeObserver:[UAirship class] name:UIApplicationDidFinishLaunchingNotification object:nil];

    NSDictionary *remoteNotification = [notification.userInfo objectForKey:UIApplicationLaunchOptionsRemoteNotificationKey];

    _sharedAirship.analytics.notificationUserInfo = remoteNotification;

    //Send Startup Analytics Info
    //init first event
    [_sharedAirship.analytics addEvent:[UAEventAppInit eventWithContext:nil]];

    
    [UAInboxPushHandler handleNotification:remoteNotification];
    [[UAPush shared] handleNotification:remoteNotification applicationState:[UIApplication sharedApplication].applicationState];

    UALOG(@"Active in nsnotification listener %d", ([UIApplication sharedApplication].applicationState == UIApplicationStateActive));
}

+ (void)handleAppTerminationNotification:(NSNotification *)notification {
    [[NSNotificationCenter defaultCenter] removeObserver:[self class]  name:UIApplicationWillTerminateNotification object:nil];
    [UAirship land];
}

+ (void)land {

    if (!_sharedAirship) {
        return;
    }

	// add app_exit event
    [_sharedAirship.analytics addEvent:[UAEventAppExit eventWithContext:nil]];
	
    //Land common classes
    [UAUser land];
    
    //Land the modular libaries first
    [NSClassFromString(@"UAPush") land];
    [NSClassFromString(@"UAInbox") land];
    
    //Finally, release the airship!
    [_sharedAirship release];
    _sharedAirship = nil;

    takeOffPred_ = 0; // reset the dispatch_once_t flag for testing
}

+ (UAirship *)shared {
    if (_sharedAirship == nil) {
        [NSException raise:@"InstanceNotExists"
                    format:@"Attempted to access UAirship instance before initializaion. Please call [UAirship takeOff:] first."];
    }
    return _sharedAirship;
}

#pragma mark -
#pragma mark DeviceToken get/set/utils

- (NSString *)deviceToken {
    return [[UAPush shared] deviceToken];
}

- (void)configureUserAgent {
    /*
     * [LIB-101] User agent string should be:
     * App 1.0 (iPad; iPhone OS 5.0.1; UALib 1.1.2; <app key>; en_US)
     */
    
    UIDevice *device = [UIDevice currentDevice];
    
    NSBundle *bundle = [NSBundle mainBundle];
    NSDictionary *info = [bundle infoDictionary];
    
    NSString *appName = [info objectForKey:(NSString*)kCFBundleNameKey];
    NSString *appVersion = [info objectForKey:(NSString*)kCFBundleVersionKey];
    
    NSString *deviceModel = [device model];
    NSString *osName = [device systemName];
    NSString *osVersion = [device systemVersion];
    
    NSString *libVersion = [UAirshipVersion get];
    NSString *locale = [[NSLocale currentLocale] localeIdentifier];
    
    NSString *userAgent = [NSString stringWithFormat:@"%@ %@ (%@; %@ %@; UALib %@; %@; %@)",
                           appName, appVersion, deviceModel, osName, osVersion, libVersion, self.appId, locale];
    
    UALOG(@"Setting User-Agent for UA requests to %@", userAgent);
    [UAHTTPConnection setDefaultUserAgentString:userAgent];
}

@end
