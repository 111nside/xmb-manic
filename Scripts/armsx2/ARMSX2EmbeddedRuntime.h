#pragma once

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Minimal bootstrap used when ARMSX2 is embedded inside ManicEMU.
/// It initializes the PCSX2 iOS runtime without replacing ManicEMU's UIWindow.
@interface ARMSX2EmbeddedRuntime : NSObject

/// Prepares folders, resources, SDL and the hidden ARMSX2 host window.
/// Safe to call repeatedly. Must succeed before asking for the render view.
+ (BOOL)prepare;

/// Boots a local PS2 image through the already-prepared PCSX2 runtime.
+ (BOOL)bootISOAtPath:(NSString *)path NS_SWIFT_NAME(bootISO(atPath:));

/// Requests that the currently running VM stop.
+ (void)stop;

@end

NS_ASSUME_NONNULL_END
