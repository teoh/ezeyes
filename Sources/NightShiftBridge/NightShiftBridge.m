#import "NightShiftBridge.h"

#import <dlfcn.h>
#import <objc/runtime.h>

typedef struct {
    int hour;
    int minute;
} EZTime;

typedef struct {
    EZTime from;
    EZTime to;
} EZSchedule;

// Layout used by CBBlueLightClient's getBlueLightStatus: on macOS.
typedef struct {
    BOOL active;
    BOOL enabled;
    BOOL sunSchedulePermitted;
    int mode;
    EZSchedule schedule;
    unsigned long long disableFlags;
    BOOL available;
} EZBlueLightStatus;

_Static_assert(sizeof(EZBlueLightStatus) == 40, "Unexpected Night Shift status layout");

@implementation NightShiftBridge {
    id _client;
    void *_framework;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _framework = dlopen("/System/Library/PrivateFrameworks/CoreBrightness.framework/CoreBrightness",
                            RTLD_LAZY | RTLD_LOCAL);
        Class clientClass = NSClassFromString(@"CBBlueLightClient");
        if (clientClass) {
            _client = [[clientClass alloc] init];
        }
    }
    return self;
}

- (void)dealloc {
    _client = nil;
    if (_framework) {
        dlclose(_framework);
    }
}

- (BOOL)isSupported {
    return _client != nil
        && [_client respondsToSelector:NSSelectorFromString(@"getBlueLightStatus:")]
        && [_client respondsToSelector:NSSelectorFromString(@"getStrength:")]
        && [_client respondsToSelector:NSSelectorFromString(@"setEnabled:")]
        && [_client respondsToSelector:NSSelectorFromString(@"setStrength:commit:")];
}

- (BOOL)readEnabled:(BOOL *)enabled
          strength:(float *)strength
         available:(BOOL *)available {
    if (!self.isSupported) {
        return NO;
    }

    EZBlueLightStatus status = {0};
    SEL statusSelector = NSSelectorFromString(@"getBlueLightStatus:");
    BOOL (*getStatus)(id, SEL, EZBlueLightStatus *) =
        (BOOL (*)(id, SEL, EZBlueLightStatus *))[_client methodForSelector:statusSelector];
    if (!getStatus(_client, statusSelector, &status)) {
        return NO;
    }

    float currentStrength = 0;
    SEL strengthSelector = NSSelectorFromString(@"getStrength:");
    BOOL (*getStrength)(id, SEL, float *) =
        (BOOL (*)(id, SEL, float *))[_client methodForSelector:strengthSelector];
    if (!getStrength(_client, strengthSelector, &currentStrength)) {
        return NO;
    }

    if (enabled) *enabled = status.enabled;
    if (strength) *strength = currentStrength;
    if (available) *available = status.available;
    return YES;
}

- (BOOL)setEnabled:(BOOL)enabled {
    if (!self.isSupported) {
        return NO;
    }
    SEL selector = NSSelectorFromString(@"setEnabled:");
    BOOL (*call)(id, SEL, BOOL) =
        (BOOL (*)(id, SEL, BOOL))[_client methodForSelector:selector];
    return call(_client, selector, enabled);
}

- (BOOL)setStrength:(float)strength {
    if (!self.isSupported || !isfinite(strength) || strength < 0 || strength > 1) {
        return NO;
    }
    SEL selector = NSSelectorFromString(@"setStrength:commit:");
    BOOL (*call)(id, SEL, float, BOOL) =
        (BOOL (*)(id, SEL, float, BOOL))[_client methodForSelector:selector];
    return call(_client, selector, strength, YES);
}

- (NSString *)diagnosticReport {
    if (!self.isSupported) {
        return [NSString stringWithFormat:@"framework=%@ client=%@ methods=missing",
                _framework ? @"loaded" : @"not loaded", _client ? @"found" : @"not found"];
    }
    EZBlueLightStatus status = {0};
    float strength = -1;
    SEL statusSelector = NSSelectorFromString(@"getBlueLightStatus:");
    SEL strengthSelector = NSSelectorFromString(@"getStrength:");
    BOOL (*getStatus)(id, SEL, EZBlueLightStatus *) =
        (BOOL (*)(id, SEL, EZBlueLightStatus *))[_client methodForSelector:statusSelector];
    BOOL (*getStrength)(id, SEL, float *) =
        (BOOL (*)(id, SEL, float *))[_client methodForSelector:strengthSelector];
    BOOL statusResult = getStatus(_client, statusSelector, &status);
    BOOL strengthResult = getStrength(_client, strengthSelector, &strength);
    Method statusMethod = class_getInstanceMethod([_client class], statusSelector);
    Method strengthMethod = class_getInstanceMethod([_client class], strengthSelector);
    return [NSString stringWithFormat:@"framework=loaded client=found statusCall=%d statusType=%s active=%d enabled=%d available=%d strengthCall=%d strengthType=%s strength=%g",
            statusResult, method_getTypeEncoding(statusMethod), status.active, status.enabled,
            status.available, strengthResult, method_getTypeEncoding(strengthMethod), strength];
}

@end
