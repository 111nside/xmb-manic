//
//  Lynx.swift
//  ManicEmu
//
//  Created by Daiuno on 2026/1/23.
//  Copyright © 2026 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import AVFoundation

extension GameType
{
    static let lynx = GameType("public.aoshuang.game.lynx")
}

@objc enum LynxGameInput: Int, Input, CaseIterable {
    case a //A 正面放置的时候 dpad在左边，A按钮是最右边的
    case b //B
    case start //Pause
    case up
    case down
    case left
    case right
    case l1 //Option 1
    case r1 //Option 2

    case flex
    case menu

    var type: InputType {
        return .game(.lynx)
    }
    
    init?(stringValue: String) {
        if stringValue == "a" { self = .a }
        else if stringValue == "b" { self = .b }
        else if stringValue == "start" { self = .start }
        else if stringValue == "menu" { self = .menu }
        else if stringValue == "up" { self = .up }
        else if stringValue == "down" { self = .down }
        else if stringValue == "left" { self = .left }
        else if stringValue == "right" { self = .right }
        else if stringValue == "l1" { self = .l1 }
        else if stringValue == "r1" { self = .r1 }
        else if stringValue == "flex" { self = .flex }
        else { return nil }
    }
}

struct Lynx: DeltaCoreProtocol {
    static let core = Lynx()
    
    var name: String { "LYNX" }
    var identifier: String { "com.aoshuang.LynxCore" }
    
    var gameType: GameType { GameType.lynx }
    var gameInputType: Input.Type { LynxGameInput.self }
    var allInputs: [Input] { LynxGameInput.allCases }
    var gameSaveFileExtension: String { "srm" }
        
    
    let videoFormat = VideoFormat(format: .bitmap(.bgra8), dimensions: CGSize(width: 192, height: 160))
    
    var supportedCheatFormats: Set<CheatFormat> {
        return []
    }
    
    var emulatorBridge: EmulatorBridging { LynxEmulatorBridge.shared }
    
    private init() {}
}


class LynxEmulatorBridge : EmulatorBridgeBase {
    static let shared = LynxEmulatorBridge()

    override func activateInput(_ input: Int, value: Double, playerIndex: Int) {
        guard playerIndex >= 0 else { return }
        if let gameInput = LynxGameInput(rawValue: input),
            let libretroButton = gameInputToCoreInput(gameInput: gameInput) {
#if DEBUG
Log.debug("🎮 \(objectInfo(self)) 点击了:\(gameInput)")
#endif
            LibretroCore.sharedInstance().press(libretroButton, playerIndex: UInt32(playerIndex))
        }
    }
    
    func gameInputToCoreInput(gameInput: LynxGameInput) -> LibretroButton? {
        if gameInput == .a { return .A }
        else if gameInput == .b { return .B }
        else if gameInput == .start { return .start }
        else if gameInput == .up { return .up }
        else if gameInput == .down { return .down }
        else if gameInput == .left { return .left }
        else if gameInput == .right { return .right }
        else if gameInput == .l1 { return .L1 }
        else if gameInput == .r1 { return .R1 }
        return nil
    }
    
    override func deactivateInput(_ input: Int, playerIndex: Int) {
        if let gameInput = LynxGameInput(rawValue: input),
            let libretroButton = gameInputToCoreInput(gameInput: gameInput) {
            LibretroCore.sharedInstance().release(libretroButton, playerIndex: UInt32(playerIndex))
        }
    }
}
