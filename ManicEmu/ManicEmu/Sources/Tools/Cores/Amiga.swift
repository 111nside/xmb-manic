//
//  Amiga.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/8/21.
//  Copyright © 2026 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later


import AVFoundation

extension GameType {
    static let amiga = GameType("public.aoshuang.game.amiga")
}

@objc enum AmigaGameInput: Int, Input, CaseIterable {
    case a
    case b
    case x
    case y
    case start
    case select
    case up
    case down
    case left
    case right
    case l1
    case r1
    case l2
    case r2
    case l3
    case r3
    case leftThumbstickUp
    case leftThumbstickDown
    case leftThumbstickLeft
    case leftThumbstickRight
    case rightThumbstickUp
    case rightThumbstickDown
    case rightThumbstickLeft
    case rightThumbstickRight

    case flex
    case menu
    case useJoypadSkin
    case useKeyboardSkin

    var type: InputType {
        return .game(.amiga)
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
        if stringValue == "a" { self = .a}
        else if stringValue == "b" { self = .b}
        else if stringValue == "x" { self = .x}
        else if stringValue == "y" { self = .y}
        else if stringValue == "start" { self = .start}
        else if stringValue == "select" { self = .select}
        else if stringValue == "up" { self = .up}
        else if stringValue == "down" { self = .down}
        else if stringValue == "left" { self = .left}
        else if stringValue == "right" { self = .right}
        else if stringValue == "l1" { self = .l1}
        else if stringValue == "r1" { self = .r1}
        else if stringValue == "l2" { self = .l2}
        else if stringValue == "r2" { self = .r2}
        else if stringValue == "l3" { self = .l3}
        else if stringValue == "r3" { self = .r3}
        else if stringValue == "leftThumbstickUp" { self = .leftThumbstickUp}
        else if stringValue == "leftThumbstickDown" { self = .leftThumbstickDown}
        else if stringValue == "leftThumbstickLeft" { self = .leftThumbstickLeft}
        else if stringValue == "leftThumbstickRight" { self = .leftThumbstickRight}
        else if stringValue == "rightThumbstickUp" { self = .rightThumbstickUp}
        else if stringValue == "rightThumbstickDown" { self = .rightThumbstickDown}
        else if stringValue == "rightThumbstickLeft" { self = .rightThumbstickLeft}
        else if stringValue == "rightThumbstickRight" { self = .rightThumbstickRight}
        else if stringValue == "useJoypadSkin" { self = .useJoypadSkin }
        else if stringValue == "useKeyboardSkin" { self = .useKeyboardSkin }
        else { return nil }
    }
}

struct Amiga: DeltaCoreProtocol {
    static let core = Amiga()
    
    var name: String { "Amiga" }
    var identifier: String { "com.aoshuang.AmigaCore" }
    
    var gameType: GameType { GameType.amiga }
    var gameInputType: Input.Type { AmigaGameInput.self }
    var allInputs: [Input] { AmigaGameInput.allCases }
    var gameSaveFileExtension: String { "nvr" }
        
    let videoFormat = VideoFormat(format: .bitmap(.rgb565), dimensions: CGSize(width: 720, height: 574))
    
    var supportedCheatFormats: Set<CheatFormat> {
        return []
    }
    
    var emulatorBridge: EmulatorBridging { AmigaEmulatorBridge.shared }
    
    private init() {}
}


class AmigaEmulatorBridge : EmulatorBridgeBase {
    static let shared = AmigaEmulatorBridge()

    private var leftThumbstickPosition: CGPoint = .zero
    private var rightThumbstickPosition: CGPoint = .zero
    
    private var thumbstickPosition: CGPoint = .zero

    override func activateInput(_ input: Int, value: Double, playerIndex: Int) {
        guard playerIndex >= 0 else { return }
        if input == AmigaGameInput.leftThumbstickUp || input == AmigaGameInput.leftThumbstickDown {
            leftThumbstickPosition.y = input == AmigaGameInput.leftThumbstickUp ? value : -value
            LibretroCore.sharedInstance().moveStick(true, x: leftThumbstickPosition.x, y: leftThumbstickPosition.y, playerIndex: UInt32(playerIndex))
        } else if input == AmigaGameInput.leftThumbstickLeft || input == AmigaGameInput.leftThumbstickRight {
            leftThumbstickPosition.x = input == AmigaGameInput.leftThumbstickRight ? value : -value
            LibretroCore.sharedInstance().moveStick(true, x: leftThumbstickPosition.x, y: leftThumbstickPosition.y, playerIndex: UInt32(playerIndex))
        } else if input == AmigaGameInput.rightThumbstickUp || input == AmigaGameInput.rightThumbstickDown {
            rightThumbstickPosition.y = input == AmigaGameInput.rightThumbstickUp ? value : -value
            LibretroCore.sharedInstance().moveStick(false, x: rightThumbstickPosition.x, y: rightThumbstickPosition.y, playerIndex: UInt32(playerIndex))
        } else if input == AmigaGameInput.rightThumbstickLeft || input == AmigaGameInput.rightThumbstickRight {
            rightThumbstickPosition.x = input == AmigaGameInput.rightThumbstickRight ? value : -value
            LibretroCore.sharedInstance().moveStick(false, x: rightThumbstickPosition.x, y: rightThumbstickPosition.y, playerIndex: UInt32(playerIndex))
        }  else {
            if let gameInput = AmigaGameInput(rawValue: input),
                let libretroButton = gameInputToCoreInput(gameInput: gameInput) {
#if DEBUG
Log.debug("🎮 \(objectInfo(self)) 点击了:\(gameInput)")
#endif
                LibretroCore.sharedInstance().press(libretroButton, playerIndex: UInt32(playerIndex))
            }
        }
    }
    
    func gameInputToCoreInput(gameInput: AmigaGameInput) -> LibretroButton? {
        if gameInput == .a { return .A }
        else if gameInput == .b { return .B }
        else if gameInput == .x { return .X }
        else if gameInput == .y { return .Y }
        else if gameInput == .start { return .start }
        else if gameInput == .select { return .select }
        else if gameInput == .up { return .up }
        else if gameInput == .down { return .down }
        else if gameInput == .left { return .left }
        else if gameInput == .right { return .right }
        else if gameInput == .l1 { return .L1 }
        else if gameInput == .r1 { return .R1 }
        else if gameInput == .l2 { return .L2 }
        else if gameInput == .r2 { return .R2 }
        else if gameInput == .l3 { return .L3 }
        else if gameInput == .r3 { return .R3 }
        return nil
    }
    
    override func deactivateInput(_ input: Int, playerIndex: Int) {
        if input == AmigaGameInput.leftThumbstickUp || input == AmigaGameInput.leftThumbstickDown {
            leftThumbstickPosition.y = 0
            LibretroCore.sharedInstance().moveStick(true, x: leftThumbstickPosition.x, y: leftThumbstickPosition.y, playerIndex: UInt32(playerIndex))
        } else if input == AmigaGameInput.leftThumbstickLeft || input == AmigaGameInput.leftThumbstickRight {
            leftThumbstickPosition.x = 0
            LibretroCore.sharedInstance().moveStick(true, x: leftThumbstickPosition.x, y: leftThumbstickPosition.y, playerIndex: UInt32(playerIndex))
        } else if input == AmigaGameInput.rightThumbstickUp || input == AmigaGameInput.rightThumbstickDown {
            rightThumbstickPosition.y = 0
            LibretroCore.sharedInstance().moveStick(false, x: rightThumbstickPosition.x, y: rightThumbstickPosition.y, playerIndex: UInt32(playerIndex))
        } else if input == AmigaGameInput.rightThumbstickLeft || input == AmigaGameInput.rightThumbstickRight {
            rightThumbstickPosition.x = 0
            LibretroCore.sharedInstance().moveStick(false, x: rightThumbstickPosition.x, y: rightThumbstickPosition.y, playerIndex: UInt32(playerIndex))
        } else {
            if let gameInput = AmigaGameInput(rawValue: input),
                let libretroButton = gameInputToCoreInput(gameInput: gameInput) {
                LibretroCore.sharedInstance().release(libretroButton, playerIndex: UInt32(playerIndex))
            }
        }
    }
}
