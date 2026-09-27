//
//  Log.swift
//  ManicEmu
//
//  Created by Max on 2025/1/11.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later
import XCGLogger
import ZipArchive

let Log = XCGLogger(identifier: "XCGLogger", includeDefaultDestinations: false)

func LogSetup() {
#if DEBUG
    // Create a destination for the system console log (via NSLog)
    let systemDestination = AppleSystemLogDestination(identifier: "com.aoshuang.manicemu.log.console")
    
    // Optionally set some configuration options
    systemDestination.outputLevel = .debug
    systemDestination.showLogIdentifier = false
    systemDestination.showFunctionName = true
    systemDestination.showThreadName = true
    systemDestination.showLevel = true
    systemDestination.showFileName = true
    systemDestination.showLineNumber = true
    systemDestination.showDate = true
    
    // Add the destination to the logger
    Log.add(destination: systemDestination)
#endif
}
