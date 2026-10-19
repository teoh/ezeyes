#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Small runtime wrapper for the private CoreBrightness Night Shift client.
/// Calls fail gracefully when Apple changes or removes the API.
@interface NightShiftBridge : NSObject

@property (nonatomic, readonly) BOOL isSupported;

- (BOOL)readEnabled:(BOOL *)enabled
          strength:(float *)strength
         available:(BOOL *)available;
- (BOOL)setEnabled:(BOOL)enabled;
- (BOOL)setStrength:(float)strength;
- (NSString *)diagnosticReport;

@end

NS_ASSUME_NONNULL_END
