//
//  Symbian.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/8/19.
//  Copyright © 2026 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later


import AVFoundation

/**
 RetroPad
 UP  ->   std_key_up_arrow 上
 DOWN  -> std_key_down_arrow 下
 LEFT  -> std_key_left_arrow 左
 RIGHT -> std_key_right_arrow 右
 START -> std_key_application_0 绿键
 SELECT -> std_key_application_1 红键
 A   ->   std_key_device_3 中键 / 确认 / Fire
 B    ->  std_key_menu 系统 Menu
 X    ->  std_key_device_0 左软键
 Y    ->  std_key_device_1 右软键
 L1   ->  ASCII '*'
 R1    ->   std_key_hash
 L2   ->  ASCII '2'
 R2   ->  ASCII '8'
 L3   ->  ASCII '4'
 R3   ->  ASCII '6'
 
 RetroKeyboard
 0-9 -> ASCII '0'–'9'
 *   ->  ASCII '*'
 #   ->  std_key_hash
 */

extension GameType {
    static let symbian = GameType("public.aoshuang.game.symbian")
}

@objc enum SymbianGameInput: Int, Input, CaseIterable {
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
    case fire
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
    case star
    case pound
    case softkeyLeft
    case softkeyRight
    
    case flex
    case menu
    
    var type: InputType {
        return .game(.symbian)
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
        else if stringValue == "fire" { self = .fire }
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
        else if stringValue == "star" { self = .star }
        else if stringValue == "pound" { self = .pound }
        else if stringValue == "softkeyLeft" { self = .softkeyLeft }
        else if stringValue == "softkeyRight" { self = .softkeyRight }
        else { return nil }
    }
}

struct Symbian: DeltaCoreProtocol {
    static let core = Symbian()
    
    var name: String { "Symbian" }
    var identifier: String { "com.aoshuang.SymbianCore" }
    
    var gameType: GameType { GameType.symbian }
    var gameInputType: Input.Type { SymbianGameInput.self }
    var allInputs: [Input] { SymbianGameInput.allCases }
    var gameSaveFileExtension: String { "srm" }
    
    // N-Gage native 176x208; S60 devices vary. EKA2L1 presents HW GLES.
    let videoFormat = VideoFormat(format: .bitmap(.rgb565), dimensions: CGSize(width: 176, height: 208))
    
    var supportedCheatFormats: Set<CheatFormat> {
        return []
    }
    
    var emulatorBridge: EmulatorBridging { SymbianEmulatorBridge.shared }
    
    private init() {}
}


class SymbianEmulatorBridge : EmulatorBridgeBase {
    static let shared = SymbianEmulatorBridge()
    
    private var leftThumbstickPosition: CGPoint = .zero
    private var rightThumbstickPosition: CGPoint = .zero
    
    private var thumbstickPosition: CGPoint = .zero
    
    override func activateInput(_ input: Int, value: Double, playerIndex: Int) {
        guard playerIndex >= 0 else { return }
        if let gameInput = SymbianGameInput(rawValue: input) {
#if DEBUG
            Log.debug("🎮 \(objectInfo(self)) pressed:\(gameInput)")
#endif
            if let libretroButton = gameInputToCoreInput(gameInput: gameInput) {
                LibretroCore.sharedInstance().press(libretroButton, playerIndex: UInt32(playerIndex))
            } else if gameInput == .num0, let keyCode = LibretroKeyboardCode.createCode(withLabel: "0") {
                LibretroCore.sharedInstance().pressKeyboard(keyCode)
            } else if gameInput == .num1, let keyCode = LibretroKeyboardCode.createCode(withLabel: "1") {
                LibretroCore.sharedInstance().pressKeyboard(keyCode)
            } else if gameInput == .num3, let keyCode = LibretroKeyboardCode.createCode(withLabel: "3") {
                LibretroCore.sharedInstance().pressKeyboard(keyCode)
            } else if gameInput == .num5, let keyCode = LibretroKeyboardCode.createCode(withLabel: "5") {
                LibretroCore.sharedInstance().pressKeyboard(keyCode)
            } else if gameInput == .num7, let keyCode = LibretroKeyboardCode.createCode(withLabel: "7") {
                LibretroCore.sharedInstance().pressKeyboard(keyCode)
            } else if gameInput == .num9, let keyCode = LibretroKeyboardCode.createCode(withLabel: "9") {
                LibretroCore.sharedInstance().pressKeyboard(keyCode)
            }
        }
    }
    
    func gameInputToCoreInput(gameInput: SymbianGameInput) -> LibretroButton? {
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
        else if gameInput == .fire { return .A }
        else if gameInput == .num0 { return nil }
        else if gameInput == .num1 { return nil }
        else if gameInput == .num2 { return .L2 }
        else if gameInput == .num3 { return nil }
        else if gameInput == .num4 { return .L3 }
        else if gameInput == .num5 { return nil }
        else if gameInput == .num6 { return .R3 }
        else if gameInput == .num7 { return nil }
        else if gameInput == .num8 { return .R2 }
        else if gameInput == .num9 { return nil }
        else if gameInput == .star { return .L1 }
        else if gameInput == .pound { return .R1 }
        else if gameInput == .softkeyLeft { return .X }
        else if gameInput == .softkeyRight { return .Y }
        return nil
    }
    
    override func deactivateInput(_ input: Int, playerIndex: Int) {
        if let gameInput = SymbianGameInput(rawValue: input) {
            if let libretroButton = gameInputToCoreInput(gameInput: gameInput) {
                LibretroCore.sharedInstance().release(libretroButton, playerIndex: UInt32(playerIndex))
            } else if gameInput == .num0, let keyCode = LibretroKeyboardCode.createCode(withLabel: "0") {
                LibretroCore.sharedInstance().releaseKeyboard(keyCode)
            } else if gameInput == .num1, let keyCode = LibretroKeyboardCode.createCode(withLabel: "1") {
                LibretroCore.sharedInstance().releaseKeyboard(keyCode)
            } else if gameInput == .num3, let keyCode = LibretroKeyboardCode.createCode(withLabel: "3") {
                LibretroCore.sharedInstance().releaseKeyboard(keyCode)
            } else if gameInput == .num5, let keyCode = LibretroKeyboardCode.createCode(withLabel: "5") {
                LibretroCore.sharedInstance().releaseKeyboard(keyCode)
            } else if gameInput == .num7, let keyCode = LibretroKeyboardCode.createCode(withLabel: "7") {
                LibretroCore.sharedInstance().releaseKeyboard(keyCode)
            } else if gameInput == .num9, let keyCode = LibretroKeyboardCode.createCode(withLabel: "9") {
                LibretroCore.sharedInstance().releaseKeyboard(keyCode)
            }
        }
    }
}
