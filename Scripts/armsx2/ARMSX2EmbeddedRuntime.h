#pragma once

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Minimal bootstrap used when ARMSX2 is embedded inside ManicEMU.
/// It initializes the PCSX2 iOS runtime without replacing ManicEMU's UIWindow.
@interface ARMSX2EmbeddedRuntime : NSObject

/// Prepares folders, resources, SDL and the hidden ARMSX2 host window.
/// Safe to call repeatedly. Must succeed before asking for the render view.
+ (BOOL)prepare;

/// Makes ARMSX2's SDL-created host window visible and key for gameplay.
/// The Metal render view remains attached to this window for its entire lifetime.
+ (void)showGameWindow;

/// Hides ARMSX2's host window after gameplay. The host app should then make its
/// own UIWindow key again.
+ (void)hideGameWindow;

/// Boots a local PS2 image through the already-prepared PCSX2 runtime.
+ (BOOL)bootISOAtPath:(NSString *)path NS_SWIFT_NAME(bootISO(atPath:));

/// Boots the PS2 BIOS with no disc inserted so the original Browser / Memory Card
/// screen is available inside the embedded renderer.
+ (BOOL)bootBIOSBrowser;

/// Requests that the currently running VM stop.
+ (void)stop;

@end

NS_ASSUME_NONNULL_END
