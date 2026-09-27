//
//  PM.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/7/28.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later


import AVFoundation

extension GameType
{
    static let pm = GameType("public.aoshuang.game.pm")
}

@objc enum PMGameInput: Int, Input, CaseIterable {
    case a
    case b
    case c
    case r1
    case up
    case down
    case left
    case right

    case flex
    case menu
    case shake

    var type: InputType {
        return .game(.pm)
    }
    
    init?(stringValue: String) {
        if stringValue == "a" { self = .a }
        else if stringValue == "b" { self = .b }
        else if stringValue == "c" { self = .c }
        else if stringValue == "r1" { self = .r1 }
        else if stringValue == "menu" { self = .menu }
        else if stringValue == "up" { self = .up }
        else if stringValue == "down" { self = .down }
        else if stringValue == "left" { self = .left }
        else if stringValue == "right" { self = .right }
        else if stringValue == "flex" { self = .flex }
        else if stringValue == "shake" { self = .shake }
        else { return nil }
    }
}

struct PM: DeltaCoreProtocol {
    static let core = PM()
    
    var name: String { "PM" }
    var identifier: String { "com.aoshuang.PMCore" }
    
    var gameType: GameType { GameType.pm }
    var gameInputType: Input.Type { PMGameInput.self }
    var allInputs: [Input] { PMGameInput.allCases }
    var gameSaveFileExtension: String { "eep" }
        
    
    let videoFormat = VideoFormat(format: .bitmap(.rgb565), dimensions: CGSize(width: 96, height: 64))
    
    var supportedCheatFormats: Set<CheatFormat> {
        return []
    }
    
    var emulatorBridge: EmulatorBridging { PMEmulatorBridge.shared }
        
    private init()
    {
    }
}


class PMEmulatorBridge : EmulatorBridgeBase {
    static let shared = PMEmulatorBridge()

    private var thumbstickPosition: CGPoint = .zero
    
    override func activateInput(_ input: Int, value: Double, playerIndex: Int) {
        guard playerIndex >= 0 else { return }
        if let gameInput = PMGameInput(rawValue: input),
            let libretroButton = gameInputToCoreInput(gameInput: gameInput) {
#if DEBUG
Log.debug("🎮 \(objectInfo(self)) 点击了:\(gameInput)")
#endif
            LibretroCore.sharedInstance().press(libretroButton, playerIndex: UInt32(playerIndex))
        }
    }
    
    func gameInputToCoreInput(gameInput: PMGameInput) -> LibretroButton? {
        if gameInput == .a { return .A }
        else if gameInput == .b { return .B }
        else if gameInput == .c { return .R1 }
        else if gameInput == .r1 { return .R1 }
        else if gameInput == .up { return .up }
        else if gameInput == .down { return .down }
        else if gameInput == .left { return .left }
        else if gameInput == .right { return .right }
        else if gameInput == .shake { return .L1 }
        return nil
    }
    
    override func deactivateInput(_ input: Int, playerIndex: Int) {
        if let gameInput = PMGameInput(rawValue: input),
            let libretroButton = gameInputToCoreInput(gameInput: gameInput) {
            LibretroCore.sharedInstance().release(libretroButton, playerIndex: UInt32(playerIndex))
        }
    }
}
