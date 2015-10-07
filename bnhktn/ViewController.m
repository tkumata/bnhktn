//
//  ViewController.m
//  bnhktn
//
//  Created by KUMATA Tomokatsu on 9/28/15.
//  Copyright © 2015 KUMATA Tomokatsu. All rights reserved.
//

/*
 * Konashi config
 *
 * PIO0 ... LED which role is monster.
 * PIO1 ... Switch as changing role to pac-man.
 * PIO2 ... Touch as changing role to monster.
 * PIO3 ... Vib when pac-man get powerball when role is monster.
 *
 *
 * Variable
 *
 * confPacman ... 0 is pac-man, 1 is monster
 *
 */

#import "ViewController.h"
#import <CoreLocation/CoreLocation.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import "Konashi.h"
#import <CoreMotion/CoreMotion.h>
#import "SRWebSocket.h"
#import <AVFoundation/AVFoundation.h>

@interface ViewController () <CLLocationManagerDelegate, CBCentralManagerDelegate>
{
    int notificationFlag;
    int norepeatFlag;
    
    NSString *rangeMessage;
    UIWebView *webView;
    UIImageView *imgView;
    UIImageView *img2View;
    
    BOOL confPacman;
    float confMyLat, confMyLon, confMyAlt, confMyDir, confTargetLat, confTargetLon, confCookieLat, confCookieLng;
    int contScore, confPower;
    
    SRWebSocket *web_socket;
    BOOL socketOpen;
    
    NSMutableDictionary *_dictPlayers;
}
@property (weak, nonatomic) IBOutlet UILabel *labelRange;
@property (weak, nonatomic) IBOutlet UILabel *labelRSSI;
@property (weak, nonatomic) IBOutlet UILabel *labelLastLocation;
@property (weak, nonatomic) IBOutlet UIButton *roleMonsterButton;

@property (nonatomic) CMMotionManager *motionManager;
@property (nonatomic) CLLocationManager *locationManager;
@property (nonatomic) NSUUID *proximityUUID;
@property (nonatomic) CLBeaconRegion *beaconRegion;
@property (nonatomic) CBCentralManager *bluetoothManager;

@property (strong, nonatomic) AVAudioPlayer *player;

@end

@implementation ViewController
@synthesize segmentRole;

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    // User Defaults
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary *defaults = [NSMutableDictionary dictionary];
    [defaults setObject:@"YES" forKey:@"isPacman"];
    [defaults setObject:@"0" forKey:@"myLat"];
    [defaults setObject:@"0" forKey:@"myLon"];
    [defaults setObject:@"0" forKey:@"myAlt"];
    [defaults setObject:@"0" forKey:@"targetLat"];
    [defaults setObject:@"0" forKey:@"targetLon"];
    [defaults setObject:@"0" forKey:@"score"];
    [defaults setObject:@"0" forKey:@"power"];
    [defaults setObject:@"0" forKey:@"myDir"];
    [defaults setObject:@"0" forKey:@"cookieLat"];
    [defaults setObject:@"0" forKey:@"cookieLng"];
    [ud registerDefaults:defaults];
    
    // Read setting file
    confPacman = [ud boolForKey:@"isPacman"];
    confMyLat = [ud doubleForKey:@"myLat"];
    confMyLon = [ud doubleForKey:@"myLon"];
//    confMyAlt = [ud doubleForKey:@"myAlt"];
    confMyDir = [ud doubleForKey:@"myDir"];

    // Global
    norepeatFlag = 0;
    socketOpen = NO;
    
    // Konashi init
    [Konashi initialize];

    // Konashi Event Handler
    [[Konashi shared] setReadyHandler:^{
        NSLog(@"Konashi Ready");
        if (segmentRole.selectedSegmentIndex == 0) {
            [Konashi pinMode:KonashiDigitalIO0 mode:KonashiPinModeOutput]; // set PIO0 LED
            [Konashi digitalWrite:KonashiDigitalIO0 value:KonashiLevelHigh];
        }
        [self shortcutBeacon];
    }];
    
    [[Konashi shared] setDigitalInputDidChangeValueHandler:^(KonashiDigitalIOPin pin, int value) {
        if ([Konashi digitalRead:KonashiDigitalIO1] && value == 1) {
            [self readRole];
        }
        
        if ([Konashi digitalRead:KonashiDigitalIO2]) {
            [Konashi pinMode:KonashiDigitalIO3 mode:KonashiPinModeOutput]; // set PIO3 Vib
            [Konashi digitalWrite:KonashiDigitalIO3 value:KonashiLevelLow];
            [self readRole2];
        }
    }];

    // Sound settings
//    NSString *path = [[NSBundle mainBundle] pathForResource:@"win" ofType:@"mp3"];
//    NSURL *url = [NSURL fileURLWithPath:path];
//    AVAudioPlayer *audio = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:nil];
//    [audio play];

    // Apply user defaults setting
    segmentRole.selectedSegmentIndex = confPacman;
    self.labelLastLocation.text = [NSString stringWithFormat:@"@%f, %f, %f", confMyLat, confMyLon, confMyDir];
    
    // Regist notification settings
    if ([UIApplication instancesRespondToSelector:@selector(registerUserNotificationSettings:)]) {
        [[UIApplication sharedApplication] registerUserNotificationSettings:
         [UIUserNotificationSettings settingsForTypes:UIUserNotificationTypeAlert|UIUserNotificationTypeSound
                                           categories:nil]];
    }

    // make webview area
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        webView = [[UIWebView alloc]initWithFrame:CGRectMake(0, 410, 613, 617)]; // for iPad
    } else {
        webView = [[UIWebView alloc]initWithFrame:CGRectMake(0, 164, 320, 400)];
    }
    webView.tag = 123;
    
    // Set background main view
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        imgView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 410, 613, 617)]; // for iPad
    } else {
        imgView = [[UIImageView alloc] initWithFrame:CGRectMake(-70, 300, 200, 200)];
//        img2View = [[UIImageView alloc] initWithFrame:CGRectMake(250, 300, 200, 200)];
    }
    
    // role image
    if (confPacman) {
        UIImage *monsterimg0 = [UIImage imageNamed:@"monster.jpeg"];
        imgView.image = monsterimg0;
        [self.view insertSubview:imgView atIndex:0];
    } else {
        UIImage *pacmanimg0 = [UIImage imageNamed:@"2000px-Pacman.svg.png"];
        imgView.image = pacmanimg0;
        [self.view insertSubview:imgView atIndex:0];
    }
    
    // check bluetooth
    self.bluetoothManager = [[CBCentralManager alloc] initWithDelegate:self
                                                                 queue:dispatch_get_main_queue()
                                                               options:@{CBCentralManagerOptionShowPowerAlertKey:@(YES)}];

    // init location manager (BLE)
    if ([CLLocationManager isMonitoringAvailableForClass:[CLCircularRegion class]]) {
        // set location manager
        self.locationManager = [CLLocationManager new];
        if ([self.locationManager respondsToSelector:@selector(requestAlwaysAuthorization)]) {
            [self.locationManager requestAlwaysAuthorization]; //or requestWhenInUseAuthorization
        }
        self.locationManager.delegate = self;
        self.proximityUUID = [[NSUUID alloc] initWithUUIDString:@"244CFBCC-F801-40D0-A103-72F0488F0C16"];
        self.beaconRegion = [[CLBeaconRegion alloc] initWithProximityUUID:self.proximityUUID
                                                               identifier:@"com.example.kmt.bnhktn"];
        [self.locationManager startMonitoringForRegion:self.beaconRegion];
        
        // set GPS if location manager enable
        if ([CLLocationManager locationServicesEnabled]) {
            [self.locationManager setDelegate:self];
            [self.locationManager setDistanceFilter:kCLDistanceFilterNone];
            [self.locationManager setDesiredAccuracy:kCLLocationAccuracyBest];
        }
    }
    
    // Open Socket.IO
    web_socket = [[SRWebSocket alloc] initWithURLRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"ws://192.168.3.2:8888"]]];
    [web_socket setDelegate:self];
    [web_socket open];
    
    // Motion Manager
//    self.motionManager = [[CMMotionManager alloc] init];
//    // DeviceMotion
//    if ([self.motionManager isDeviceMotionAvailable]) {
//        if([self.motionManager isDeviceMotionActive] == NO) {
//            /* Update us 2 times a second */
//            [self.motionManager setDeviceMotionUpdateInterval:1.0f / 2.0f];
//            /* Add on a handler block object */
//            /* Receive the gyroscope data on this block */
//            [self.motionManager startDeviceMotionUpdatesToQueue:[NSOperationQueue mainQueue]
//                                                    withHandler:^(CMDeviceMotion *deviceMotion, NSError *error)
//             {
//                 float z = deviceMotion.rotationRate.z*(180/M_PI);
//                 NSLog(@"%f", z);
//             }];
//        }
//    }
//    else
//    {
//        NSLog(@"Gyroscope not Available!");
//    }

}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
//    if (central.state != CBCentralManagerStatePoweredOn) {
//        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"bnhktn"
//                                                                       message:@"Please turn Bluetooth on."
//                                                                preferredStyle:UIAlertControllerStyleAlert];
//        [alert addAction:[UIAlertAction actionWithTitle:@"OK"
//                                                  style:UIAlertActionStyleDefault
//                                                handler:nil]];
//        [self presentViewController:alert animated:YES completion:nil];
//    }
}

// Background Central Manager
- (void)locationManager:(CLLocationManager *)manager didStartMonitoringForRegion:(CLRegion *)region {
    [self runBackgroundTask];
}
// Exec Background Task
-(void)runBackgroundTask {
    UIApplication *application = [UIApplication sharedApplication];
    __block UIBackgroundTaskIdentifier bgTask = [application beginBackgroundTaskWithExpirationHandler:^{
        dispatch_async(dispatch_get_main_queue(),^{
            // already exec, to stop background task process
            if (bgTask != UIBackgroundTaskInvalid) {
                [application endBackgroundTask:bgTask];
                bgTask = UIBackgroundTaskInvalid;
            }
        });
    }];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),^{
        // Start getting location
        [self.locationManager requestStateForRegion:self.beaconRegion];
    });
}

- (void)locationManager:(CLLocationManager *)manager didDetermineState:(CLRegionState)state forRegion:(CLRegion *)region
{
    switch (state) {
        case CLRegionStateInside: // in region
            NSLog(@"Enter Region and start rasing.(status)");
            if ([region isMemberOfClass:[CLBeaconRegion class]] && [CLLocationManager isRangingAvailable]) {
                [self.locationManager startRangingBeaconsInRegion:self.beaconRegion];
            }
            break;
        case CLRegionStateOutside:
        case CLRegionStateUnknown:
        default:
            NSLog(@"Exit Region and stop raging.(status)");
            if ([region isMemberOfClass:[CLBeaconRegion class]] && [CLLocationManager isRangingAvailable]) {
                [self.locationManager stopRangingBeaconsInRegion:(CLBeaconRegion *)region];
            }
            break;
    }
}

- (void)locationManager:(CLLocationManager *)manager didEnterRegion:(CLRegion *)region {
    NSLog(@"Enter Region and start rasing.(CLLocation)");
    if ([region isMemberOfClass:[CLBeaconRegion class]] && [CLLocationManager isRangingAvailable]) {
        [self.locationManager startRangingBeaconsInRegion:(CLBeaconRegion *)region];
    }
}

- (void)locationManager:(CLLocationManager *)manager didExitRegion:(CLRegion *)region {
    NSLog(@"Exit Region and stop raging.(CLLocation)");
    if ([region isMemberOfClass:[CLBeaconRegion class]] && [CLLocationManager isRangingAvailable]) {
        [self.locationManager stopRangingBeaconsInRegion:(CLBeaconRegion *)region];
    }
}

- (void)locationManager:(CLLocationManager *)manager didRangeBeacons:(NSArray *)beacons inRegion:(CLBeaconRegion *)region
{
    if (beacons.count > 0) {
        CLBeacon *nearestBeacon = beacons.firstObject;
        
        /*
         * isBeforePosition is ...
         * 1...immediate
         * 2...near
         * 3...far
         * 4...out
         */
        
        switch (nearestBeacon.proximity) {
            case CLProximityImmediate:
                rangeMessage = @"Immediate";
                if (norepeatFlag == 0) {
                    [self sendNotificationFunc];
                    
                    // HTTP GET Method
                    [self shortcutBeacon];

                    // No repeat
                    norepeatFlag = 1;
                }
                break;
                
            case CLProximityNear:
            case CLProximityFar:
                rangeMessage = @"Near or Far";
                norepeatFlag = 0;
                break;
                
            default:
                rangeMessage = @"Unknown";
                norepeatFlag = 0;
                break;
        }
        self.labelRSSI.text = [NSString stringWithFormat:@"%ld", (long)nearestBeacon.rssi];
    }
    
    self.labelRange.text = [NSString stringWithFormat:@"%@", rangeMessage];

}

- (void)locationManager:(CLLocationManager *)manager monitoringDidFailForRegion:(CLRegion *)region
              withError:(NSError *)error {
    NSLog(@"Location manager failed: %@", error);
}

// Notification
- (void)sendNotificationFunc {
    NSString *mess = [NSString stringWithFormat:@""];
    [self sendLocalNotificationForMessage:[rangeMessage stringByAppendingString:mess]];
}
- (void)sendLocalNotificationForMessage:(NSString *)message {
    UILocalNotification *localNotification = [[UILocalNotification alloc] init];
    [localNotification setTimeZone:[NSTimeZone defaultTimeZone]];
    [localNotification setFireDate:[NSDate date]];
    localNotification.alertBody = message;
    [localNotification setSoundName:(NSString *) UILocalNotificationDefaultSoundName];
    [localNotification setHasAction:NO];
    [[UIApplication sharedApplication] scheduleLocalNotification:localNotification];
}

- (IBAction)findKonashi:(id)sender {
    [[self.view viewWithTag:123] removeFromSuperview];

    // Search and connect to konashi
    [Konashi find];
}

- (IBAction)postGeo:(id)sender {
    // reserve func
}

- (IBAction)getRole:(id)sender {
    // reserve func
}

- (IBAction)pacmanItem:(id)sender {
    // reserve func
}

- (IBAction)accessServer:(id)sender {
    // reserve func
}

- (IBAction)showQuestionAction:(id)sender {
    long buttonTag = [sender tag];
    
    switch (buttonTag) {
        case 1:
            [self getandpostGEO];
            break;
        
        case 2:
            [self readRole];
            break;
        
        case 3:
            [self pacmanGetItem];
            break;
        
        case 4:
            [self shortcutBeacon];
            break;
        
        default:
            break;
    }
}

- (void)getandpostGEO {
    [self.locationManager startUpdatingLocation];
//    [self.locationManager startUpdatingHeading];
    
    // Location info
    CLLocation *location = self.locationManager.location;
    
    // GPS Date (UTC)
    NSDateFormatter *dfGPSDate = [NSDateFormatter new];
    dfGPSDate.dateFormat = @"yyyy:MM:dd";
    dfGPSDate.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
    
    // GPS Time (UTC)
    NSDateFormatter* dfGPSTime = [NSDateFormatter new];
    dfGPSTime.dateFormat = @"HH:mm:ss.SSSSSS";
    dfGPSTime.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
    
    // Latitude
    CGFloat mylatitude = location.coordinate.latitude;
    NSString *gpsLatitudeRef;
    if (mylatitude < 0) {
        mylatitude = -mylatitude;
        gpsLatitudeRef = @"S";
    } else {
        gpsLatitudeRef = @"N";
    }
    
    // Longitude
    CGFloat mylongitude = location.coordinate.longitude;
    NSString *gpsLongitudeRef;
    if (mylongitude < 0) {
        mylongitude = -mylongitude;
        gpsLongitudeRef = @"W";
    } else {
        gpsLongitudeRef = @"E";
    }
    
    // Altitude
//    CGFloat altitude = location.altitude;
//    if (!isnan(altitude)) {
//        NSString *gpsAltitudeRef;
//        if (altitude < 0) {
//            altitude = -altitude;
//            gpsAltitudeRef = @"1";
//        } else {
//            gpsAltitudeRef = @"0";
//        }
//    }
    
//    [self.locationManager stopUpdatingHeading];
    [self.locationManager stopUpdatingLocation];
    
    // Save location to user defaults
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    float pastMyLat = [ud doubleForKey:@"myLat"];
    float pastMyLon = [ud doubleForKey:@"myLon"];
    float mydirection = CalculateAngle(pastMyLat, pastMyLon, mylatitude, mylongitude);
    [ud setDouble:mylatitude forKey:@"myLat"];
    [ud setDouble:mylongitude forKey:@"myLon"];
//    [ud setDouble:altitude forKey:@"myAlt"];
    [ud setDouble:mydirection forKey:@"myDir"];
    [ud synchronize];
    self.labelLastLocation.text = [NSString stringWithFormat:@"@%f, %f, %f", mylatitude, mylongitude, mydirection];
    
    // Make JSON and send location to node.js server
    if (socketOpen) {
        if (segmentRole.selectedSegmentIndex == 0) {
            // case pac-man
            NSString* json = [NSString stringWithFormat:@"{\"enemyLat\":%f,\"enemyLng\":%f,\"playerLat\":%f,\"playerLng\":%f,\"playerDir\":%f,\"nextCookieLat\":%f,\"nextCookieLng\":%f}", 0.0, 0.0, mylatitude, mylongitude, mydirection, 0.0, 0.0];
            NSData* data = [json dataUsingEncoding:NSUTF8StringEncoding];
            //    NSDictionary* dict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:nil];
            [web_socket send:data];
        } else {
            // case monster
            NSString* json = [NSString stringWithFormat:@"{\"enemyLat\":\"%f\",\"enemyLng\":\"%f\",\"playerLat\":\"%f\",\"playerLng\":\"%f\",\"playerDir\":\"%f\",\"nextCookieLat\":%f,\"nextCookieLng\":%f}", mylatitude, mylongitude, 0.0f, 0.0f, mydirection, 0.0f, 0.0f];
            NSData* data = [json dataUsingEncoding:NSUTF8StringEncoding];
            //    NSDictionary* dict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:nil];
            [web_socket send:data];
        }
    }
    
    /* HTTP POST BEGIN */
    // POST my location
//    NSString *url = @"http://192.168.3.2/~kumata/post.php";
//    NSString *postString;
//    NSMutableURLRequest *request;
    
    // POST param
//    NSString *param = [NSString stringWithFormat:@"lat=%lf&lon=%lf", mylatitude, mylongitude];
//    postString = [NSString stringWithFormat:@"%@", param];
    
    // Request
//    request = [[NSMutableURLRequest alloc] init];
//    [request setHTTPMethod:@"POST"];
//    [request setURL:[NSURL URLWithString:url]];
//    [request setCachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData];
//    [request setTimeoutInterval:20];
//    [request setHTTPShouldHandleCookies:FALSE];
//    [request setHTTPBody:[postString dataUsingEncoding:NSUTF8StringEncoding]];
    
    // Send POST
//    NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
//    if (connection) {
//        [NSMutableData data];
//    }
    /* HTTP POST END */
}

- (void)readRole {
    // change to role
    if (segmentRole.selectedSegmentIndex == 1) {
        NSLog(@"Change to Pac-man.");
        segmentRole.selectedSegmentIndex = 0;
        
        NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
        [ud setBool:0 forKey:@"isPacman"];
        [ud synchronize];
        
        [Konashi pinMode:KonashiDigitalIO0 mode:KonashiPinModeOutput]; // set PIO0 LED
        [Konashi digitalWrite:KonashiDigitalIO0 value:KonashiLevelLow];
        
        UIImage *pacmanimg0 = [UIImage imageNamed:@"2000px-Pacman.svg.png"];
        imgView.image = pacmanimg0;
        [self.view insertSubview:imgView atIndex:0];
    } else {
        NSLog(@"Change to Monster.");
        segmentRole.selectedSegmentIndex = 1;
        
        NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
        [ud setBool:1 forKey:@"isPacman"];
        [ud synchronize];
        
        [Konashi pinMode:KonashiDigitalIO0 mode:KonashiPinModeOutput]; // set PIO0 LED
        [Konashi digitalWrite:KonashiDigitalIO0 value:KonashiLevelLow];
        
        UIImage *pacmanimg0 = [UIImage imageNamed:@"monster.jpeg"];
        imgView.image = pacmanimg0;
        [self.view insertSubview:imgView atIndex:0];
    }
}

- (void)readRole2 {
    // change to role pac-man
    NSLog(@"I am Pac-man.");
    segmentRole.selectedSegmentIndex = 0;
    
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    [ud setBool:segmentRole.selectedSegmentIndex forKey:@"isPacman"];
    [ud synchronize];
    
    [Konashi pinMode:KonashiDigitalIO0 mode:KonashiPinModeOutput]; // set PIO0 LED
    [Konashi digitalWrite:KonashiDigitalIO0 value:KonashiLevelHigh];
//    [NSThread sleepForTimeInterval:0.1];
//    [Konashi digitalWrite:KonashiDigitalIO0 value:KonashiLevelLow];
    
    UIImage *pacmanimg0 = [UIImage imageNamed:@"2000px-Pacman.svg.png"];
    imgView.image = pacmanimg0;
    [self.view insertSubview:imgView atIndex:0];
}

- (void)pacmanGetItem {
    if (segmentRole.selectedSegmentIndex == 0) {
        // role is pac-man
        [Konashi pinMode:KonashiDigitalIO3 mode:KonashiPinModeOutput]; // set PIO3 Vib
        [Konashi digitalWrite:KonashiDigitalIO3 value:KonashiLevelLow];
    } else if (segmentRole.selectedSegmentIndex == 1) {
        // role is monster
        [Konashi pinMode:KonashiDigitalIO3 mode:KonashiPinModeOutput]; // set PIO3 Vib
        [Konashi digitalWrite:KonashiDigitalIO3 value:KonashiLevelHigh];
        [self playSound:@"lose.mp3"];
    }
}

- (void)shortcutBeacon {
    // HTTP GET Method
//    NSURL *url = [NSURL URLWithString:@"https://www.google.co.jp/"];
//    NSData *data = [NSData dataWithContentsOfURL:url];
//    NSString *ret = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
//    NSLog(@"ret=%@", ret);
//    
//    NSURLRequest *nsrequest = [NSURLRequest requestWithURL:url];
//    
//    [webView loadRequest:nsrequest];
//    [self.view addSubview:webView];
}

- (void)webSocketDidOpen:(SRWebSocket *)webSocket {
//    [webSocket send:@"{\"id\":\"1\",\"item\":\"hogehoge\"}"];
    socketOpen = YES;
}

- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)message {
//    NSLog(@"didReceiveMessage: %@", [message description]);
    NSData *data = [message dataUsingEncoding:NSUTF8StringEncoding];
    // JSON parse
    NSDictionary *array = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];;
    
    //
    if (segmentRole.selectedSegmentIndex == 0) {
        // case Pac-man
        confTargetLat = [[array objectForKey:@"enemyLat"] floatValue];
        confTargetLon = [[array objectForKey:@"enemyLng"] floatValue];
        confCookieLat = [[array objectForKey:@"nextCookieLat"] floatValue];
        confCookieLng = [[array objectForKey:@"nextCookieLng"] floatValue];
    } else {
        // case Monster
        confTargetLat = [[array objectForKey:@"playerLat"] floatValue];
        confTargetLon = [[array objectForKey:@"playerLng"] floatValue];
        confCookieLat = [[array objectForKey:@"nextCookieLat"] floatValue];
        confCookieLng = [[array objectForKey:@"nextCookieLng"] floatValue];
    }
    
    // Save location to user defaults
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    [ud setDouble:confTargetLat forKey:@"targetLat"];
    [ud setDouble:confTargetLon forKey:@"targetLon"];
    [ud setDouble:confCookieLat forKey:@"cookieLat"];
    [ud setDouble:confCookieLng forKey:@"cookieLon"];
    [ud synchronize];
}

- (void)webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code
           reason:(NSString *)reason
         wasClean:(BOOL)wasClean; {
    socketOpen = NO;
}

- (void)playSound:(NSString *)soundName {
    NSString *soundPath = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:soundName];
    NSURL *urlOfSound = [NSURL fileURLWithPath:soundPath];
    AVAudioPlayer *player = [[AVAudioPlayer alloc] initWithContentsOfURL:urlOfSound error:nil];
    [player setNumberOfLoops:0];
    player.delegate = (id)self;
    [player prepareToPlay];
    if (_dictPlayers == nil)
        _dictPlayers = [NSMutableDictionary dictionary];
    [_dictPlayers setObject:player forKey:[[player.url path] lastPathComponent]];
    [player play];
}

-(void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag {
    [_dictPlayers removeObjectForKey:[[player.url path] lastPathComponent]];
}

//- (void)locationManager:(CLLocationManager *)manager didUpdateHeading:(CLHeading *)newHeading {
//    if (newHeading.headingAccuracy < 0)
//        return;
//    CLLocationDirection heading = newHeading.magneticHeading;
//    confMyDir = heading;
//    NSLog(@"%f", heading);
//}

// CalculateAngle(start, start, target, target)
float CalculateAngle(float nLat1, float nLon1, float nLat2, float nLon2) {
    float Y = cos(nLon2 * M_PI / 180) * sin(nLat2 * M_PI / 180 - nLat1 * M_PI / 180);
    float X = cos(nLon1 * M_PI / 180) * sin(nLon2 * M_PI / 180) - sin(nLon1 * M_PI / 180) * cos(nLon2 * M_PI / 180) * cos(nLat2 * M_PI / 180 - nLat1 * M_PI / 180);
    float dirE0 = 180 * atan2(Y, X) / M_PI;
    
    if (dirE0 < 0) {
        dirE0 = dirE0 + 360;
    }
    
    float dirN0 = fmod((dirE0+90), 360);
    
    return dirN0;
}



// Appendix
- (IBAction)LED2ON:(id)sender {
//    NSLog(@"konashi connected = %d", [Konashi isConnected]);
//    NSLog(@"konashi ready = %d", [Konashi isReady]);
//    NSLog(@"connected module = %@", [Konashi peripheralName]);
//    [Konashi pinMode:KonashiLED2 mode:KonashiPinModeOutput]; // set PIN LED
//    [Konashi digitalWrite:KonashiLED2 value:KonashiLevelHigh];
//    NSLog(@"write = %@", writePinResult == KonashiResultSuccess ? @"Success" : @"Failure");
}

@end
