//
//  N64.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/7/6.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later


import AVFoundation

extension GameType
{
    static let n64 = GameType("public.aoshuang.game.n64")
}

@objc enum N64GameInput: Int, Input, CaseIterable {
    case a
    case b
    case x
    case y
    case z
    case l
    case l1
    case r
    case r1
    case start
    case up
    case down
    case left
    case right
    case cUp
    case cDown
    case cLeft
    case cRight
    case analogStickUp
    case analogStickDown
    case analogStickLeft
    case analogStickRight

    case flex
    case menu

    var type: InputType {
        return .game(.n64)
    }
    
    var isContinuous: Bool {
        switch self
        {
        case .analogStickUp, .analogStickDown, .analogStickLeft, .analogStickRight: return true
        default: return false
        }
    }
    
    init?(stringValue: String) {
        if stringValue == "a" { self = .a }
        else if stringValue == "b" { self = .b }
        else if stringValue == "x" { self = .x }
        else if stringValue == "y" { self = .y }
        else if stringValue == "z" { self = .z }
        else if stringValue == "l" { self = .l }
        else if stringValue == "l1" { self = .l1 }
        else if stringValue == "r" { self = .r }
        else if stringValue == "r1" { self = .r1 }
        else if stringValue == "start" { self = .start }
        else if stringValue == "up" { self = .up }
        else if stringValue == "down" { self = .down }
        else if stringValue == "left" { self = .left }
        else if stringValue == "right" { self = .right }
        else if stringValue == "cUp" { self = .cUp }
        else if stringValue == "cDown" { self = .cDown }
        else if stringValue == "cLeft" { self = .cLeft }
        else if stringValue == "cRight" { self = .cRight }
        else if stringValue == "analogStickUp" { self = .analogStickUp }
        else if stringValue == "analogStickDown" { self = .analogStickDown }
        else if stringValue == "analogStickLeft" { self = .analogStickLeft }
        else if stringValue == "analogStickRight" { self = .analogStickRight }
        else if stringValue == "flex" { self = .flex }
        else if stringValue == "menu" { self = .menu }
        else { return nil }
    }
}

struct N64: DeltaCoreProtocol {
    static let core = N64()
    
    var name: String { "N64" }
    var identifier: String { "com.aoshuang.N64Core" }
    var version: String? { "1.0.0" }
    
    var gameType: GameType { GameType.n64 }
    var gameInputType: Input.Type { N64GameInput.self }
    var allInputs: [Input] { N64GameInput.allCases }
    var gameSaveFileExtension: String { "srm" }
    
    
    let videoFormat = VideoFormat(format: .bitmap(.bgra8), dimensions: CGSize(width: 320, height: 240))
    
    var supportedCheatFormats: Set<CheatFormat> {
        let gameSharkFormat = CheatFormat(name: NSLocalizedString("GameShark", comment: ""), format: "XXXXXXXX YYYY", type: .gameShark)
        return [gameSharkFormat]
    }
    
    var emulatorBridge: EmulatorBridging { N64EmulatorBridge.shared }
    
    private init() {}
}


class N64EmulatorBridge : EmulatorBridgeBase {
    static let shared = N64EmulatorBridge()

    enum CStickDirection {
        case up, down, left, right
    }
    
    private var thumbstickPosition: CGPoint = .zero
    private var cStickPressDirection: CStickDirection? = nil

    override func activateInput(_ input: Int, value: Double, playerIndex: Int) {
        guard playerIndex >= 0 else { return }
        if input == N64GameInput.analogStickUp || input == N64GameInput.analogStickDown {
            thumbstickPosition.y = input == N64GameInput.analogStickUp ? value : -value
            LibretroCore.sharedInstance().moveStick(true, x: thumbstickPosition.x, y: thumbstickPosition.y, playerIndex: UInt32(playerIndex))
        } else if input == N64GameInput.analogStickLeft || input == N64GameInput.analogStickRight {
            thumbstickPosition.x = input == N64GameInput.analogStickRight ? value : -value
            LibretroCore.sharedInstance().moveStick(true, x: thumbstickPosition.x, y: thumbstickPosition.y, playerIndex: UInt32(playerIndex))
        } else if handleCStickInput(input, value: value, playerIndex: playerIndex, press: true) {
#if DEBUG
Log.debug("🎮 \(objectInfo(self)) 点击了:cStick")
#endif
        } else {
            if let gameInput = N64GameInput(rawValue: input),
                let libretroButton = gameInputToCoreInput(gameInput: gameInput) {
#if DEBUG
Log.debug("🎮 \(objectInfo(self)) 点击了:\(gameInput)")
#endif
                LibretroCore.sharedInstance().press(libretroButton, playerIndex: UInt32(playerIndex))
            }
        }
    }
    
    func gameInputToCoreInput(gameInput: N64GameInput) -> LibretroButton? {
        if gameInput == .a { return .B }
        else if gameInput == .b { return .Y }
        else if gameInput == .x { return .X }
        else if gameInput == .y { return .Y }
        else if gameInput == .z { return .L2 }
        else if gameInput == .l { return .L1 }
        else if gameInput == .l1 { return .L1 }
        else if gameInput == .r { return .R1 }
        else if gameInput == .r1 { return .R1 }
        else if gameInput == .start { return .start }
        else if gameInput == .up { return .up }
        else if gameInput == .down { return .down }
        else if gameInput == .left { return .left }
        else if gameInput == .right { return .right }
        return nil
    }
    
    override func deactivateInput(_ input: Int, playerIndex: Int) {
        if input == N64GameInput.analogStickUp || input == N64GameInput.analogStickDown {
            thumbstickPosition.y = 0
            LibretroCore.sharedInstance().moveStick(true, x: thumbstickPosition.x, y: thumbstickPosition.y, playerIndex: UInt32(playerIndex))
        } else if input == N64GameInput.analogStickLeft || input == N64GameInput.analogStickRight {
            thumbstickPosition.x = 0
            LibretroCore.sharedInstance().moveStick(true, x: thumbstickPosition.x, y: thumbstickPosition.y, playerIndex: UInt32(playerIndex))
        } else if handleCStickInput(input, value: 0, playerIndex: playerIndex, press: false) {
            //释放了cstick
        } else {
            if let gameInput = N64GameInput(rawValue: input),
                let libretroButton = gameInputToCoreInput(gameInput: gameInput) {
                LibretroCore.sharedInstance().release(libretroButton, playerIndex: UInt32(playerIndex))
            }
        }
    }
    
    private func handleCStickInput(_ input: Int, value: Double, playerIndex: Int, press: Bool) -> Bool {
        var position: CGPoint? = nil
        if press {
            if input == N64GameInput.cUp, value > 0.5 {
                cStickPressDirection = .up
                position = CGPoint(x: 0, y: 1)
            } else if  input == N64GameInput.cDown, value > 0.5 {
                cStickPressDirection = .down
                position = CGPoint(x: 0, y: -1)
            } else if input == N64GameInput.cLeft, value > 0.5 {
                cStickPressDirection = .left
                position = CGPoint(x: -1, y: 0)
            } else if input == N64GameInput.cRight, value > 0.5 {
                cStickPressDirection = .right
                position = CGPoint(x: 1, y: 0)
            }
        } else {
            if (input == N64GameInput.cUp && cStickPressDirection == .up) ||
                (input == N64GameInput.cDown && cStickPressDirection == .down) ||
                (input == N64GameInput.cLeft && cStickPressDirection == .left) ||
                (input == N64GameInput.cRight && cStickPressDirection == .right) {
                cStickPressDirection = nil
                position = CGPoint(x: 0, y: 0)
            }
        }
        if let position {
            LibretroCore.sharedInstance().moveStick(false, x: position.x, y: position.y, playerIndex: UInt32(playerIndex))
            return true
        }
        return false
    }
}
