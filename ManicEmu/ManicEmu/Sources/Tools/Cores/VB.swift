//
//  VB.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/7/16.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later


import AVFoundation

extension GameType
{
    static let vb = GameType("public.aoshuang.game.vb")
}

@objc enum VBGameInput: Int, Input, CaseIterable {
    case a
    case b
    case l
    case l1
    case r
    case r1
    case start
    case select
    case up
    case down
    case left
    case right
    case rightDpadUp
    case rightDpadDown
    case rightDpadLeft
    case rightDpadRight

    case flex
    case menu

    var type: InputType {
        return .game(.vb)
    }
    
    init?(stringValue: String) {
        if stringValue == "a" { self = .a }
        else if stringValue == "b" { self = .b }
        else if stringValue == "l" { self = .l }
        else if stringValue == "l1" { self = .l1 }
        else if stringValue == "r" { self = .r }
        else if stringValue == "r1" { self = .r1 }
        else if stringValue == "start" { self = .start }
        else if stringValue == "select" { self = .select }
        else if stringValue == "up" { self = .up }
        else if stringValue == "down" { self = .down }
        else if stringValue == "left" { self = .left }
        else if stringValue == "right" { self = .right }
        else if stringValue == "rightDpadUp" { self = .rightDpadUp }
        else if stringValue == "rightDpadDown" { self = .rightDpadDown }
        else if stringValue == "rightDpadLeft" { self = .rightDpadLeft }
        else if stringValue == "rightDpadRight" { self = .rightDpadRight }
        else if stringValue == "flex" { self = .flex }
        else if stringValue == "menu" { self = .menu }
        else { return nil }
    }
}

struct VB: DeltaCoreProtocol {
    static let core = VB()
    
    var name: String { "VB" }
    var identifier: String { "com.aoshuang.VBCore" }
    
    var gameType: GameType { GameType.vb }
    var gameInputType: Input.Type { VBGameInput.self }
    var allInputs: [Input] { VBGameInput.allCases }
    var gameSaveFileExtension: String { "srm" }
        
    
    let videoFormat = VideoFormat(format: .bitmap(.rgb565), dimensions: CGSize(width: 384, height: 224))
    
    var supportedCheatFormats: Set<CheatFormat> {
        return []
    }
    
    var emulatorBridge: EmulatorBridging { VBEmulatorBridge.shared }
        
    private init()
    {
    }
}


class VBEmulatorBridge : EmulatorBridgeBase {
    static let shared = VBEmulatorBridge()

    private var thumbstickPosition: CGPoint = .zero

    override func activateInput(_ input: Int, value: Double, playerIndex: Int) {
        guard playerIndex >= 0 else { return }
        if let gameInput = VBGameInput(rawValue: input),
            let libretroButton = gameInputToCoreInput(gameInput: gameInput) {
#if DEBUG
Log.debug("🎮 \(objectInfo(self)) 点击了:\(gameInput)")
#endif
            LibretroCore.sharedInstance().press(libretroButton, playerIndex: UInt32(playerIndex))
        }
    }
    
    func gameInputToCoreInput(gameInput: VBGameInput) -> LibretroButton? {
        if gameInput == .a { return .A }
        else if gameInput == .b { return .B }
        else if gameInput == .l { return .L1 }
        else if gameInput == .l1 { return .L1 }
        else if gameInput == .r { return .R1 }
        else if gameInput == .r1 { return .R1 }
        else if gameInput == .start { return .start }
        else if gameInput == .select { return .select }
        else if gameInput == .up { return .up }
        else if gameInput == .down { return .down }
        else if gameInput == .left { return .left }
        else if gameInput == .right { return .right }
        else if gameInput == .rightDpadUp { return .L2 }
        else if gameInput == .rightDpadDown { return .L3 }
        else if gameInput == .rightDpadLeft { return .R2 }
        else if gameInput == .rightDpadRight { return .R3 }
        return nil
    }
    
    override func deactivateInput(_ input: Int, playerIndex: Int) {
        if let gameInput = VBGameInput(rawValue: input),
            let libretroButton = gameInputToCoreInput(gameInput: gameInput) {
            LibretroCore.sharedInstance().release(libretroButton, playerIndex: UInt32(playerIndex))
        }
    }
}
