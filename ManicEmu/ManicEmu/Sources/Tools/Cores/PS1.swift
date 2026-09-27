//
//  PS1.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/7/31.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later


import AVFoundation

extension GameType
{
    static let ps1 = GameType("public.aoshuang.game.ps1")
}

@objc enum PS1GameInput: Int, Input, CaseIterable {
    case a
    case b
    case x
    case y
    case up
    case down
    case left
    case right
    case l1
    case l2
    case l3
    case r1
    case r2
    case r3
    case leftThumbstickUp
    case leftThumbstickDown
    case leftThumbstickLeft
    case leftThumbstickRight
    case rightThumbstickUp
    case rightThumbstickDown
    case rightThumbstickLeft
    case rightThumbstickRight
    case start
    case select
    case flex
    case menu

    var type: InputType {
        return .game(.ps1)
    }
    
    var isContinuous: Bool {
        switch self
        {
        case .leftThumbstickUp, .leftThumbstickDown, .leftThumbstickLeft, .leftThumbstickRight: return true
        case .rightThumbstickUp, .rightThumbstickDown, .rightThumbstickLeft, .rightThumbstickRight: return true
        default: return false
        }
    }
    
    init?(stringValue: String) {
        if stringValue == "a" { self = .a }
        else if stringValue == "b" { self = .b }
        else if stringValue == "x" { self = .x }
        else if stringValue == "y" { self = .y }
        else if stringValue == "up" { self = .up }
        else if stringValue == "down" { self = .down }
        else if stringValue == "left" { self = .left }
        else if stringValue == "right" { self = .right }
        else if stringValue == "l1" { self = .l1 }
        else if stringValue == "l2" { self = .l2 }
        else if stringValue == "l3" { self = .l3 }
        else if stringValue == "r1" { self = .r1 }
        else if stringValue == "r2" { self = .r2 }
        else if stringValue == "r3" { self = .r3 }
        else if stringValue == "leftThumbstickUp" { self = .leftThumbstickUp }
        else if stringValue == "leftThumbstickDown" { self = .leftThumbstickDown }
        else if stringValue == "leftThumbstickLeft" { self = .leftThumbstickLeft }
        else if stringValue == "leftThumbstickRight" { self = .leftThumbstickRight }
        else if stringValue == "rightThumbstickUp" { self = .rightThumbstickUp }
        else if stringValue == "rightThumbstickDown" { self = .rightThumbstickDown }
        else if stringValue == "rightThumbstickLeft" { self = .rightThumbstickLeft }
        else if stringValue == "rightThumbstickRight" { self = .rightThumbstickRight }
        else if stringValue == "menu" { self = .menu }
        else if stringValue == "flex" { self = .flex }
        else if stringValue == "start" { self = .start }
        else if stringValue == "select" { self = .select }
        else { return nil }
    }
}

struct PS1: DeltaCoreProtocol {
    static let core = PS1()
    
    var name: String { "PS1" }
    var identifier: String { "com.aoshuang.PS1Core" }
    var version: String? { "1.0.0" }
    
    var gameType: GameType { GameType.ps1 }
    var gameInputType: Input.Type { PS1GameInput.self }
    var allInputs: [Input] { PS1GameInput.allCases }
    var gameSaveFileExtension: String { "srm" }
    
    
    let videoFormat = VideoFormat(format: .bitmap(.bgra8), dimensions: CGSize(width: 256, height: 224))
    
    var supportedCheatFormats: Set<CheatFormat> {
        let cheatFormat = CheatFormat(name: NSLocalizedString("Pro Action Replay", comment: ""), format: "XXXXXXXX YYYY", type: .actionReplay16)
        return [cheatFormat]
    }
    
    var emulatorBridge: EmulatorBridging { PS1EmulatorBridge.shared }
    
    private init() {}
}


class PS1EmulatorBridge : EmulatorBridgeBase {
    static let shared = PS1EmulatorBridge()
    
    private var leftThumbstickPosition: CGPoint = .zero
    private var rightThumbstickPosition: CGPoint = .zero
    
    override func activateInput(_ input: Int, value: Double, playerIndex: Int) {
        guard playerIndex >= 0 else { return }
        if input == PS1GameInput.leftThumbstickUp || input == PS1GameInput.leftThumbstickDown {
            leftThumbstickPosition.y = input == PS1GameInput.leftThumbstickUp ? value : -value
            LibretroCore.sharedInstance().moveStick(true, x: leftThumbstickPosition.x, y: leftThumbstickPosition.y, playerIndex: UInt32(playerIndex))
        } else if input == PS1GameInput.leftThumbstickLeft || input == PS1GameInput.leftThumbstickRight {
            leftThumbstickPosition.x = input == PS1GameInput.leftThumbstickRight ? value : -value
            LibretroCore.sharedInstance().moveStick(true, x: leftThumbstickPosition.x, y: leftThumbstickPosition.y, playerIndex: UInt32(playerIndex))
        } else if input == PS1GameInput.rightThumbstickUp || input == PS1GameInput.rightThumbstickDown {
            rightThumbstickPosition.y = input == PS1GameInput.rightThumbstickUp ? value : -value
            LibretroCore.sharedInstance().moveStick(false, x: rightThumbstickPosition.x, y: rightThumbstickPosition.y, playerIndex: UInt32(playerIndex))
        } else if input == PS1GameInput.rightThumbstickLeft || input == PS1GameInput.rightThumbstickRight {
            rightThumbstickPosition.x = input == PS1GameInput.rightThumbstickRight ? value : -value
            LibretroCore.sharedInstance().moveStick(false, x: rightThumbstickPosition.x, y: rightThumbstickPosition.y, playerIndex: UInt32(playerIndex))
        }  else {
            if let gameInput = PS1GameInput(rawValue: input),
                let libretroButton = gameInputToCoreInput(gameInput: gameInput) {
#if DEBUG
Log.debug("🎮 \(objectInfo(self)) 点击了:\(gameInput)")
#endif
                LibretroCore.sharedInstance().press(libretroButton, playerIndex: UInt32(playerIndex))
            }
        }
    }
    
    func gameInputToCoreInput(gameInput: PS1GameInput) -> LibretroButton? {
        if gameInput == .a { return .A }
        else if gameInput == .b { return .B }
        else if gameInput == .x { return .X }
        else if gameInput == .y { return .Y }
        else if gameInput == .up { return .up }
        else if gameInput == .down { return .down }
        else if gameInput == .left { return .left }
        else if gameInput == .right { return .right }
        else if gameInput == .l1 { return .L1 }
        else if gameInput == .l2 { return .L2 }
        else if gameInput == .l3 { return .L3 }
        else if gameInput == .r1 { return .R1 }
        else if gameInput == .r2 { return .R2 }
        else if gameInput == .r3 { return .R3 }
        else if gameInput == .start { return .start }
        else if gameInput == .select { return .select }
        return nil
    }
    
    override func deactivateInput(_ input: Int, playerIndex: Int) {
        if input == PS1GameInput.leftThumbstickUp || input == PS1GameInput.leftThumbstickDown {
            leftThumbstickPosition.y = 0
            LibretroCore.sharedInstance().moveStick(true, x: leftThumbstickPosition.x, y: leftThumbstickPosition.y, playerIndex: UInt32(playerIndex))
        } else if input == PS1GameInput.leftThumbstickLeft || input == PS1GameInput.leftThumbstickRight {
            leftThumbstickPosition.x = 0
            LibretroCore.sharedInstance().moveStick(true, x: leftThumbstickPosition.x, y: leftThumbstickPosition.y, playerIndex: UInt32(playerIndex))
        } else if input == PS1GameInput.rightThumbstickUp || input == PS1GameInput.rightThumbstickDown {
            rightThumbstickPosition.y = 0
            LibretroCore.sharedInstance().moveStick(false, x: rightThumbstickPosition.x, y: rightThumbstickPosition.y, playerIndex: UInt32(playerIndex))
        } else if input == PS1GameInput.rightThumbstickLeft || input == PS1GameInput.rightThumbstickRight {
            rightThumbstickPosition.x = 0
            LibretroCore.sharedInstance().moveStick(false, x: rightThumbstickPosition.x, y: rightThumbstickPosition.y, playerIndex: UInt32(playerIndex))
        } else {
            if let gameInput = PS1GameInput(rawValue: input),
                let libretroButton = gameInputToCoreInput(gameInput: gameInput) {
                LibretroCore.sharedInstance().release(libretroButton, playerIndex: UInt32(playerIndex))
            }
        }
    }
}
