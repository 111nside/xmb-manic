# Manic XMB frontend - first pass

This fork keeps Manic's emulation/backend code intact and adds an XMB-inspired startup UI.

## Changed
- `ApplicationSceneDelegate.swift`: starts `XMBHomeViewController` after Manic finishes resource/database setup.
- `HomeViewController.swift`: retains the original `HomeViewController` and adds `XMBHomeViewController` + `XMBGameCell`.

## XMB categories
- Recent: games with a previous play date, newest first.
- Games: full Manic Realm library, alphabetized.
- Import: opens Manic's existing import controller.
- Settings: opens Manic's existing settings controller.
- Manic: opens the original Manic home UI as a full-screen fallback.

## Launch behavior
Selecting a game calls `game.handleTapAction(forceQuick: true)`. This deliberately reuses Manic's existing `PlayViewController.startGame` path, including BIOS checks, platform/core behavior, ROM availability/iCloud handling, special emulator integrations and alerts.

## Build
Open `ManicEmu/ManicEmu.xcodeproj` in Xcode on macOS and use the same dependency/signing setup required by upstream Manic. This environment cannot perform an iOS/Xcode build, so the first Xcode compile may expose upstream-version-specific warnings/errors that need a small follow-up patch.

## Revert startup
In `ApplicationSceneDelegate.swift`, change:
`self.window?.rootViewController = XMBHomeViewController()`
back to:
`self.window?.rootViewController = HomeViewController()`
