//
//  A5200.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/1/23.
//  Copyright © 2026 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import AVFoundation

extension GameType
{
    static let a5200 = GameType("public.aoshuang.game.5200")
}

@objc enum A5200GameInput: Int, Input, CaseIterable {
    case a //fire 1
    case b //fire 2
    case x // *
    case y // #
    case start //start
    case select //pause
    case up
    case down
    case left
    case right
    case l1 // num 0
    case r1 // num 1
    case l2 // num 2
    case r2 // num 3
    case l3 // num 7
    case r3 //Virtual Keyboard
    case num0
    case num1
    case num2
    case num3
    case num4
    case num5
    case num6
    case num7
    case num8
    case num9
    case pound //#
    case star //*
    case flex
    case menu

    var type: InputType {
        return .game(.a5200)
    }
    
    init?(stringValue: String) {
        if stringValue == "a" { self = .a }
        else if stringValue == "b" { self = .b }
        else if stringValue == "x" { self = .x }
        else if stringValue == "y" { self = .y }
        else if stringValue == "start" { self = .start }
        else if stringValue == "select" { self = .select }
        else if stringValue == "menu" { self = .menu }
        else if stringValue == "up" { self = .up }
        else if stringValue == "down" { self = .down }
        else if stringValue == "left" { self = .left }
        else if stringValue == "right" { self = .right }
        else if stringValue == "l1" { self = .l1 }
        else if stringValue == "r1" { self = .r1 }
        else if stringValue == "l2" { self = .l2 }
        else if stringValue == "r2" { self = .r2 }
        else if stringValue == "l3" { self = .l3 }
        else if stringValue == "r3" { self = .r3 }
        else if stringValue == "num0" { self = .num0 }
        else if stringValue == "num1" { self = .num1 }
        else if stringValue == "num2" { self = .num2 }
        else if stringValue == "num3" { self = .num3 }
        else if stringValue == "num4" { self = .num4 }
        else if stringValue == "num5" { self = .num5 }
        else if stringValue == "num6" { self = .num6 }
        else if stringValue == "num7" { self = .num7 }
        else if stringValue == "num8" { self = .num8 }
        else if stringValue == "num9" { self = .num9 }
        else if stringValue == "pound" { self = .pound }
        else if stringValue == "star" { self = .star }
        else if stringValue == "flex" { self = .flex }
        else { return nil }
    }
}

struct A5200: DeltaCoreProtocol {
    static let core = A5200()
    
    var name: String { "5200" }
    var identifier: String { "com.aoshuang.5200Core" }
    
    var gameType: GameType { GameType.a5200 }
    var gameInputType: Input.Type { A5200GameInput.self }
    var allInputs: [Input] { A5200GameInput.allCases }
    var gameSaveFileExtension: String { "srm" }
        
    let videoFormat = VideoFormat(format: .bitmap(.bgra8), dimensions: CGSize(width: 320, height: 240))
    
    var supportedCheatFormats: Set<CheatFormat> {
        return []
    }
    
    var emulatorBridge: EmulatorBridging { A5200EmulatorBridge.shared }
    
    private init() {}
}


class A5200EmulatorBridge : EmulatorBridgeBase {
    static let shared = A5200EmulatorBridge()

    private var thumbstickPosition: CGPoint = .zero

    override func activateInput(_ input: Int, value: Double, playerIndex: Int) {
        guard playerIndex >= 0 else { return }
        if let gameInput = A5200GameInput(rawValue: input) {
#if DEBUG
                Log.debug("🎮 \(objectInfo(self)) 点击了:\(gameInput)")
#endif
            if let libretroButton = gameInputToCoreInput(gameInput: gameInput) {
                LibretroCore.sharedInstance().press(libretroButton, playerIndex: UInt32(playerIndex))
            } else {
                if gameInput == .num4, let keyCode = LibretroKeyboardCode.createCode(withLabel: "4") {
                    LibretroCore.sharedInstance().pressKeyboard(keyCode)
                } else if gameInput == .num5, let keyCode = LibretroKeyboardCode.createCode(withLabel: "5")  {
                    LibretroCore.sharedInstance().pressKeyboard(keyCode)
                } else if gameInput == .num6, let keyCode = LibretroKeyboardCode.createCode(withLabel: "6")  {
                    LibretroCore.sharedInstance().pressKeyboard(keyCode)
                } else if gameInput == .num8, let keyCode = LibretroKeyboardCode.createCode(withLabel: "8")  {
                    LibretroCore.sharedInstance().pressKeyboard(keyCode)
                } else if gameInput == .num9, let keyCode = LibretroKeyboardCode.createCode(withLabel: "9")  {
                    LibretroCore.sharedInstance().pressKeyboard(keyCode)
                }
            }
        }
    }
    
    func gameInputToCoreInput(gameInput: A5200GameInput) -> LibretroButton? {
        if gameInput == .a { return .B }
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
        else if gameInput == .num0 { return .L1 }
        else if gameInput == .num1 { return .R1 }
        else if gameInput == .num2 { return .L2 }
        else if gameInput == .num3 { return .R2 }
        else if gameInput == .num4 { return nil }
        else if gameInput == .num5 { return nil }
        else if gameInput == .num6 { return nil }
        else if gameInput == .num7 { return .L3 }
        else if gameInput == .num8 { return nil }
        else if gameInput == .num9 { return nil }
        else if gameInput == .pound { return .Y }
        else if gameInput == .star { return .X }
        
        return nil
    }
    
    override func deactivateInput(_ input: Int, playerIndex: Int) {
        if let gameInput = A5200GameInput(rawValue: input) {
            if let libretroButton = gameInputToCoreInput(gameInput: gameInput) {
                LibretroCore.sharedInstance().release(libretroButton, playerIndex: UInt32(playerIndex))
            } else {
                if gameInput == .num4, let keyCode = LibretroKeyboardCode.createCode(withLabel: "4")  {
                    LibretroCore.sharedInstance().releaseKeyboard(keyCode)
                } else if gameInput == .num5, let keyCode = LibretroKeyboardCode.createCode(withLabel: "5")  {
                    LibretroCore.sharedInstance().releaseKeyboard(keyCode)
                } else if gameInput == .num6, let keyCode = LibretroKeyboardCode.createCode(withLabel: "6")  {
                    LibretroCore.sharedInstance().releaseKeyboard(keyCode)
                } else if gameInput == .num8, let keyCode = LibretroKeyboardCode.createCode(withLabel: "8")  {
                    LibretroCore.sharedInstance().releaseKeyboard(keyCode)
                } else if gameInput == .num9, let keyCode = LibretroKeyboardCode.createCode(withLabel: "9")  {
                    LibretroCore.sharedInstance().releaseKeyboard(keyCode)
                }
            }
        }
        
    }
}

