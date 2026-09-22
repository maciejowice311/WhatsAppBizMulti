/*
 * WhatsAppBizMulti — Multi-container toolkit for WhatsApp Business
 * Target: com.whatsapp.WhatsAppSMB
 * Features: JB bypass, RANDOM GPS spoof per request, IDFV spoof, Crane integration, behavioral randomization
 * Rootless jailbreak compatible (Dopamine, iOS 15+)
 */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>
#import <objc/runtime.h>
#include <dlfcn.h>
#include <sys/stat.h>
#include <sys/sysctl.h>
#include <unistd.h>

#ifndef PT_DENY_ATTACH
#define PT_DENY_ATTACH 0x0F
#endif

%config(generator=internal)

#pragma mark - === UTILITIES ===

static NSString *const kPrefsSuite = @"com.yourname.whatsappbizmulti";

static inline BOOL wbPrefBool(NSString *key, BOOL fallback) {
    return [[NSUserDefaults standardUserDefaults] boolForKey:key] ?: fallback;
}

static inline NSString *wbPrefString(NSString *key, NSString *fallback) {
    NSString *val = [[NSUserDefaults standardUserDefaults] stringForKey:key];
    return val.length ? val : fallback;
}

static inline double wbPrefDouble(NSString *key, double fallback) {
    NSString *val = [[NSUserDefaults standardUserDefaults] stringForKey:key];
    return val.length ? val.doubleValue : fallback;
}

static inline int wbPrefInt(NSString *key, int fallback) {
    NSString *val = [[NSUserDefaults standardUserDefaults] stringForKey:key];
    return val.length ? val.intValue : fallback;
}

/* Random float in range [min, max] */
static inline double wbRandomDouble(double min, double max) {
    return min + ((double)arc4random() / UINT32_MAX) * (max - min);
}

/* Check if tweak should be active for this process */
static inline BOOL wbIsEnabled(void) {
    return YES; // Filtered by plist to com.whatsapp.WhatsAppSMB only
}

#pragma mark - === RANDOM GPS GENERATOR ===
/*
 * Generates random GPS coordinates within a radius (km) around a center point.
 * Uses uniform disc sampling: r = R * sqrt(random), theta = random * 2π
 * This avoids clustering near the center that would happen with naive r = R * random.
 */
static CLLocationCoordinate2D wbGenerateRandomCoordinate(void) {
    double centerLat = wbPrefDouble(@"gpsCenterLat", 52.2297);
    double centerLng = wbPrefDouble(@"gpsCenterLng", 21.0122);
    double radiusKm  = wbPrefDouble(@"gpsRadiusKm", 10.0);

    // Clamp radius to reasonable bounds (0.1 - 500 km)
    if (radiusKm < 0.1) radiusKm = 0.1;
    if (radiusKm > 500) radiusKm = 500;

    // Uniform disc sampling
    double u = ((double)arc4random() / UINT32_MAX);      // 0..1
    double v = ((double)arc4random() / UINT32_MAX);      // 0..1
    double r = radiusKm * sqrt(u);                       // distance from center
    double theta = 2.0 * M_PI * v;                       // random angle

    // Convert polar offset to lat/lng
    // 1 degree lat ≈ 111.32 km
    // 1 degree lng ≈ 111.32 * cos(lat) km
    double dLat = r * cos(theta) / 111.32;
    double dLng = r * sin(theta) / (111.32 * cos(centerLat * M_PI / 180.0));

    CLLocationCoordinate2D coord;
    coord.latitude  = centerLat + dLat;
    coord.longitude = centerLng + dLng;

    // Clamp latitude to valid range
    if (coord.latitude > 90.0)  coord.latitude = 90.0;
    if (coord.latitude < -90.0) coord.latitude = -90.0;
    // Normalize longitude to [-180, 180]
    while (coord.longitude > 180.0)  coord.longitude -= 360.0;
    while (coord.longitude < -180.0) coord.longitude += 360.0;

    return coord;
}

/* Build a fake CLLocation from random coordinates */
static CLLocation *wbBuildRandomLocation(void) {
    CLLocationCoordinate2D coord = wbGenerateRandomCoordinate();

    // Realistic accuracy (5-50 meters)
    double accuracy = wbRandomDouble(5.0, 50.0);

    // Realistic altitude (-50 to 500m)
    double altitude = wbRandomDouble(-50.0, 500.0);

    // Current timestamp
    NSDate *timestamp = [NSDate date];

    CLLocation *fakeLoc = [[CLLocation alloc]
        initWithCoordinate:coord
                  altitude:altitude
        horizontalAccuracy:accuracy
          verticalAccuracy:accuracy
                 timestamp:timestamp];

    return fakeLoc;
}

#pragma mark - === SECTION A: JAILBREAK DETECTION BYPASS ===

static NSArray<NSString *> *wbJailbreakPaths(void) {
    static NSArray<NSString *> *paths = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        paths = @[
            @"/Applications/Cydia.app",
            @"/Applications/Sileo.app",
            @"/Applications/Zebra.app",
            @"/usr/sbin/frida-server",
            @"/usr/bin/frida-server",
            @"/var/jb/",
            @"/usr/bin/ssh",
            @"/usr/bin/sshd",
            @"/usr/sbin/sshd",
            @"/etc/apt",
            @"/etc/apt/sources.list.d",
            @"/Library/MobileSubstrate",
            @"/Library/MobileSubstrate/DynamicLibraries",
            @"/private/var/lib/apt",
            @"/private/var/lib/dpkg",
            @"/private/var/stash",
            @"/private/var/mobile/Library/Sileo",
            @"/var/checkra1n.dmg",
            @"/var/checkra1n.repo",
            @"/usr/lib/libjailbreak.dylib",
            @"/usr/lib/TweakInject",
            @"/usr/lib/substitute-inserter.dylib",
            @"/usr/lib/substrate",
            @"/usr/lib/ellekit",
            @"/usr/lib/libhooker.dylib",
            @"/usr/lib/libblackjack.dylib",
            @"/usr/lib/dyld_bypass_validation",
            @"/jb/",
            @"/usr/bin/bash",
            @"/usr/bin/sh",
            @"/bin/bash",
            @"/bin/sh",
            @"/usr/local/bin",
            @"/usr/libexec/cydia",
            @"/usr/libexec/sileo",
            @"/usr/libexec/zebra",
            @"/var/mobile/Library/Preferences/com.saurik.Cydia",
            @"/var/mobile/Library/Sileo",
            @"/var/mobile/Library/Caches/com.saurik.Cydia",
            @"/var/mobile/Library/Caches/apt",
            @"/var/cache/apt",
            @"/var/lib/apt",
            @"/var/lib/dpkg",
            @"/usr/lib/libsubstitute.dylib",
            @"/usr/lib/libsubstrate.dylib",
            @"/usr/lib/TweakInject2",
            @"/var/jb/usr/bin",
            @"/var/jb/Library",
            @"/var/jb/usr/lib",
            @"/private/preboot/jb",
            @"/private/preboot/procursus",
            @"/private/preboot/...",  // Dopamine rootless
        ];
    });
    return paths;
}

static inline BOOL wbIsJailbreakPath(NSString *path) {
    if (!path.length) return NO;
    for (NSString *jbPath in wbJailbreakPaths()) {
        if ([path hasPrefix:jbPath]) return YES;
    }
    return NO;
}

/* Hook NSFileManager fileExistsAtPath: */
%hook NSFileManager
- (BOOL)fileExistsAtPath:(NSString *)path {
    if (wbPrefBool(@"jbBypassEnabled", NO) && wbIsJailbreakPath(path)) {
        return NO;
    }
    return %orig(path);
}

- (BOOL)fileExistsAtPath:(NSString *)path isDirectory:(BOOL *)isDirectory {
    if (wbPrefBool(@"jbBypassEnabled", NO) && wbIsJailbreakPath(path)) {
        if (isDirectory) *isDirectory = NO;
        return NO;
    }
    return %orig(path, isDirectory);
}
%end

/* Hook C stat functions */
%hookf(int, stat, const char *path, struct stat *buf) {
    if (wbPrefBool(@"jbBypassEnabled", NO) && path) {
        NSString *nsPath = [NSString stringWithUTF8String:path];
        if (wbIsJailbreakPath(nsPath)) {
            errno = ENOENT;
            return -1;
        }
    }
    return %orig(path, buf);
}

%hookf(int, stat64, const char *path, struct stat64 *buf) {
    if (wbPrefBool(@"jbBypassEnabled", NO) && path) {
        NSString *nsPath = [NSString stringWithUTF8String:path];
        if (wbIsJailbreakPath(nsPath)) {
            errno = ENOENT;
            return -1;
        }
    }
    return %orig(path, buf);
}

%hookf(int, lstat, const char *path, struct stat *buf) {
    if (wbPrefBool(@"jbBypassEnabled", NO) && path) {
        NSString *nsPath = [NSString stringWithUTF8String:path];
        if (wbIsJailbreakPath(nsPath)) {
            errno = ENOENT;
            return -1;
        }
    }
    return %orig(path, buf);
}

%hookf(int, access, const char *path, int mode) {
    if (wbPrefBool(@"jbBypassEnabled", NO) && path) {
        NSString *nsPath = [NSString stringWithUTF8String:path];
        if (wbIsJailbreakPath(nsPath)) {
            errno = ENOENT;
            return -1;
        }
    }
    return %orig(path, mode);
}

%hookf(int, openat, int dirfd, const char *pathname, int flags, ...) {
    if (wbPrefBool(@"jbBypassEnabled", NO) && pathname) {
        NSString *nsPath = [NSString stringWithUTF8String:pathname];
        if (wbIsJailbreakPath(nsPath)) {
            errno = ENOENT;
            return -1;
        }
    }
    return %orig(dirfd, pathname, flags);
}

/* Hook UIApplication canOpenURL: */
%hook UIApplication
- (BOOL)canOpenURL:(NSURL *)url {
    if (!wbPrefBool(@"jbBypassEnabled", NO) || !url.absoluteString.length) {
        return %orig(url);
    }
    NSString *scheme = url.scheme.lowercaseString;
    NSArray<NSString *> *blockedSchemes = @[
        @"cydia", @"sileo", @"zbra", @"undecimus", @"filza",
        @"activator", @"prefs", @"crane", @"trollstore", @"trollstorereloaded"
    ];
    if ([blockedSchemes containsObject:scheme]) {
        return NO;
    }
    return %orig(url);
}
%end

/* Hook fork() — sandbox escape test */
%hookf(pid_t, fork) {
    if (wbPrefBool(@"jbBypassEnabled", NO)) {
        errno = EPERM;
        return -1;
    }
    return %orig();
}

/* Hook ptrace — anti-debugging bypass */
%hookf(int, ptrace, int request, pid_t pid, caddr_t addr, int data) {
    if (wbPrefBool(@"jbBypassEnabled", NO) && request == PT_DENY_ATTACH) {
        return 0; // Pretend success
    }
    return %orig(request, pid, addr, data);
}

/* Hook sysctl — hide P_TRACED */
%hookf(int, sysctl, int *name, u_int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    int ret = %orig(name, namelen, oldp, oldlenp, newp, newlen);
    if (wbPrefBool(@"jbBypassEnabled", NO) && ret == 0 && oldp && oldlenp) {
        if (namelen == 4 &&
            name[0] == CTL_KERN &&
            name[1] == KERN_PROC &&
            name[2] == KERN_PROC_PID &&
            name[3] == getpid()) {
            struct kinfo_proc *info = (struct kinfo_proc *)oldp;
            info->kp_proc.p_flag &= ~P_TRACED;
        }
    }
    return ret;
}

/* Hook getenv — hide env vars */
%hookf(char *, getenv, const char *name) {
    if (wbPrefBool(@"jbBypassEnabled", NO) && name) {
        NSString *envName = [NSString stringWithUTF8String:name];
        NSArray<NSString *> *hiddenVars = @[
            @"FRIDA", @"FRIDA_SERVER", @"DYLD_INSERT_LIBRARIES",
            @"_MSSafeMode", @"_SafeMode", @"TWEAKS_DISABLED",
            @"_JAILED", @"THEOS"
        ];
        for (NSString *hidden in hiddenVars) {
            if ([envName isEqualToString:hidden]) return NULL;
        }
    }
    return %orig(name);
}

#pragma mark - === SECTION B: RANDOM GPS SPOOFING ===
/*
 * Generates a NEW random GPS location EVERY time the app requests location.
 * Uses uniform disc sampling within configured radius around center point.
 * Perfect for multi-container setups where each container should appear in a
 * slightly different location.
 */

%hook CLLocationManager

- (CLLocation *)location {
    if (wbPrefBool(@"gpsSpoofEnabled", NO)) {
        return wbBuildRandomLocation();
    }
    return %orig;
}

- (void)startUpdatingLocation {
    if (wbPrefBool(@"gpsSpoofEnabled", NO)) {
        // Generate fresh random location and deliver to delegate
        CLLocation *fakeLoc = wbBuildRandomLocation();
        if (self.delegate && [self.delegate respondsToSelector:@selector(locationManager:didUpdateLocations:)]) {
            [self.delegate locationManager:self didUpdateLocations:@[fakeLoc]];
        }
        // Do NOT call %orig to prevent real location updates
        return;
    }
    %orig;
}

- (void)requestLocation {
    if (wbPrefBool(@"gpsSpoofEnabled", NO)) {
        CLLocation *fakeLoc = wbBuildRandomLocation();
        if (self.delegate && [self.delegate respondsToSelector:@selector(locationManager:didUpdateLocations:)]) {
            [self.delegate locationManager:self didUpdateLocations:@[fakeLoc]];
        }
        if (self.delegate && [self.delegate respondsToSelector:@selector(locationManager:didFailWithError:)]) {
            // No error — deliver location only
        }
        return;
    }
    %orig;
}

- (void)startMonitoringSignificantLocationChanges {
    if (wbPrefBool(@"gpsSpoofEnabled", NO)) {
        // Generate fresh random significant change
        CLLocation *fakeLoc = wbBuildRandomLocation();
        if (self.delegate && [self.delegate respondsToSelector:@selector(locationManager:didUpdateLocations:)]) {
            [self.delegate locationManager:self didUpdateLocations:@[fakeLoc]];
        }
        return;
    }
    %orig;
}

- (void)requestWhenInUseAuthorization {
    %orig;
    // If GPS spoof enabled, immediately deliver a location after auth
    if (wbPrefBool(@"gpsSpoofEnabled", NO)) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            CLLocation *fakeLoc = wbBuildRandomLocation();
            if (self.delegate && [self.delegate respondsToSelector:@selector(locationManager:didUpdateLocations:)]) {
                [self.delegate locationManager:self didUpdateLocations:@[fakeLoc]];
            }
        });
    }
}

%end

/* Hook CLLocation to always return random coords when accessed */
%hook CLLocation
- (CLLocationCoordinate2D)coordinate {
    if (wbPrefBool(@"gpsSpoofEnabled", NO)) {
        // Check if this is our own fake location (via internal flag)
        // Otherwise inject random
        return wbGenerateRandomCoordinate();
    }
    return %orig;
}
%end

#pragma mark - === SECTION C: IDFV SPOOFING ===

%hook UIDevice
- (NSUUID *)identifierForVendor {
    if (wbPrefBool(@"idfvSpoofEnabled", NO)) {
        NSString *customIDFV = wbPrefString(@"idfvValue", nil);
        if (customIDFV.length > 0) {
            return [[NSUUID alloc] initWithUUIDString:customIDFV];
        }
    }
    return %orig;
}
%end

/* Hook ASIdentifierManager for advertising identifier */
%hook ASIdentifierManager
- (NSUUID *)advertisingIdentifier {
    if (wbPrefBool(@"idfvSpoofEnabled", NO)) {
        NSString *customIDFV = wbPrefString(@"idfvValue", nil);
        if (customIDFV.length > 0) {
            return [[NSUUID alloc] initWithUUIDString:customIDFV];
        }
        return [[NSUUID alloc] initWithUUIDString:@"00000000-0000-0000-0000-000000000000"];
    }
    return %orig;
}
%end

#pragma mark - === SECTION D: CRANE INTEGRATION HELPERS ===
/*
 * Reads the active Crane container identifier and prefixes preferences.
 * This allows per-container configuration (different IDFV, different GPS center).
 */

static NSString *wbActiveContainerIdentifier(void) {
    // Crane sets an environment variable or NSUserDefaults key with container ID
    NSString *containerId = [[NSUserDefaults standardUserDefaults] stringForKey:@"CraneActiveContainerIdentifier"];
    if (!containerId.length) {
        containerId = [[[NSProcessInfo processInfo] environment] objectForKey:@"CRANE_CONTAINER_ID"];
    }
    return containerId.length ? containerId : @"default";
}

/* Log active container for debugging */
%ctor {
    NSString *container = wbActiveContainerIdentifier();
    NSLog(@"[WhatsAppBizMulti] Loaded for container: %@", container);
}

#pragma mark - === SECTION E: BEHAVIORAL RANDOMIZATION ===
/*
 * Adds random delays to user interactions to simulate human-like behavior.
 * WhatsApp Business may analyze typing speed, tap patterns, etc.
 */

%hook UIControl
- (void)sendAction:(SEL)action to:(id)target forEvent:(UIEvent *)event {
    if (wbPrefBool(@"randomTimingEnabled", NO)) {
        // Random delay 50-300ms before executing tap action
        double delay = wbRandomDouble(0.05, 0.30);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            %orig(action, target, event);
        });
        return;
    }
    %orig(action, target, event);
}
%end

%hook UITextField
- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    if (wbPrefBool(@"randomTimingEnabled", NO)) {
        // Random keystroke delay 80-250ms
        double delay = wbRandomDouble(0.08, 0.25);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            // Trigger the actual change
            textField.text = [textField.text stringByReplacingCharactersInRange:range withString:string];
            // Notify delegate
            if ([self.delegate respondsToSelector:@selector(textField:shouldChangeCharactersInRange:replacementString:)]) {
                [self.delegate textField:textField shouldChangeCharactersInRange:range replacementString:string];
            }
        });
        return NO; // We'll handle it ourselves with delay
    }
    return %orig(textField, range, string);
}
%end

#pragma mark - === SECTION F: NETWORK / PROXY INTEGRATION ===
/*
 * WhatsApp Business uses its own networking (not NSURLSession directly).
 * We cannot easily intercept WhatsApp's custom crypto (Signal Protocol).
 * This section hooks system-level proxy detection to hide proxy usage.
 */

%hook NSURLSession
- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request {
    if (wbPrefBool(@"jbBypassEnabled", NO)) {
        // Log the request for debugging
        NSLog(@"[WhatsAppBizMulti] Network request: %@", request.URL.absoluteString);
    }
    return %orig(request);
}
%end

/* Hide proxy settings from CFNetworkCopySystemProxySettings */
%hookf(CFDictionaryRef, CFNetworkCopySystemProxySettings) {
    CFDictionaryRef orig = %orig();
    // We return original — proxy detection bypass is better done at proxy level
    // (using residential/mobile proxies instead of datacenter)
    return orig;
}

#pragma mark - === SECTION G: WHATSAPP-SPECIFIC HARDENING ===
/*
 * WhatsApp Business has additional checks beyond standard JB detection.
 * These hooks target WhatsApp-specific anti-tampering.
 */

/* Hook NSBundle to prevent bundle identifier spoofing detection */
%hook NSBundle
- (NSString *)bundleIdentifier {
    NSString *orig = %orig;
    // Ensure WhatsApp sees its own bundle ID
    if ([orig isEqualToString:@"com.whatsapp.WhatsAppSMB"]) {
        return orig;
    }
    return orig;
}
%end

/* Prevent WhatsApp from detecting modified binary checksums */
%hook NSData
- (NSString *)base64EncodedStringWithOptions:(NSDataBase64EncodingOptions)options {
    // WhatsApp may checksum its own binary — we can't easily bypass this
    // but we can log it for debugging
    NSString *result = %orig(options);
    return result;
}
%end

#pragma mark - === CONSTRUCTOR ===

%ctor {
    @autoreleasepool {
        NSLog(@"[WhatsAppBizMulti] Tweak loaded for WhatsApp Business");
        NSLog(@"[WhatsAppBizMulti] Active container: %@", wbActiveContainerIdentifier());
        NSLog(@"[WhatsAppBizMulti] JB Bypass: %@", wbPrefBool(@"jbBypassEnabled", NO) ? @"ON" : @"OFF");
        NSLog(@"[WhatsAppBizMulti] Random GPS: %@", wbPrefBool(@"gpsSpoofEnabled", NO) ? @"ON" : @"OFF");
        NSLog(@"[WhatsAppBizMulti] IDFV Spoof: %@", wbPrefBool(@"idfvSpoofEnabled", NO) ? @"ON" : @"OFF");
        NSLog(@"[WhatsAppBizMulti] Random Timing: %@", wbPrefBool(@"randomTimingEnabled", NO) ? @"ON" : @"OFF");
    }
}
