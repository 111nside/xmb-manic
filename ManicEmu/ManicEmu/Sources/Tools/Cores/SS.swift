//
//  SS.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/6/13.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later


import AVFoundation

extension GameType
{
    static let ss = GameType("public.aoshuang.game.ss")
}

@objc enum SSGameInput: Int, Input, CaseIterable {
    case a
    case b
    case c
    case x
    case y
    case z
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

    case flex
    case menu

    var type: InputType {
        return .game(.ss)
    }
    
    init?(stringValue: String) {
        if stringValue == "a" { self = .a }
        else if stringValue == "b" { self = .b }
        else if stringValue == "x" { self = .x }
        else if stringValue == "y" { self = .y }
        else if stringValue == "l" { self = .l }
        else if stringValue == "l1" { self = .l1 }
        else if stringValue == "r" { self = .r }
        else if stringValue == "r1" { self = .r1 }
        else if stringValue == "start" { self = .start }
        else if stringValue == "select" { self = .select }
        else if stringValue == "menu" { self = .menu }
        else if stringValue == "up" { self = .up }
        else if stringValue == "down" { self = .down }
        else if stringValue == "left" { self = .left }
        else if stringValue == "right" { self = .right }
        else if stringValue == "flex" { self = .flex }
        else if stringValue == "c" { self = .c }
        else if stringValue == "z" { self = .z }
        else { return nil }
    }
}

struct SS: DeltaCoreProtocol {
    static let core = SS()
    
    var name: String { "SS" }
    var identifier: String { "com.aoshuang.SSCore" }
    
    var gameType: GameType { GameType.ss }
    var gameInputType: Input.Type { SSGameInput.self }
    var allInputs: [Input] { SSGameInput.allCases }
    var gameSaveFileExtension: String { "srm" }
        
    
    let videoFormat = VideoFormat(format: .bitmap(.rgb565), dimensions: CGSize(width: 330, height: 224))
    
    var supportedCheatFormats: Set<CheatFormat> {
        let codeBreakerFormat = CheatFormat(name: NSLocalizedString("Code Breaker", comment: ""), format: "XXXXXXXX YYYY", type: .codeBreaker)
        return [codeBreakerFormat]
    }
    
    var emulatorBridge: EmulatorBridging { SSEmulatorBridge.shared }
        
    private init()
    {
    }
}


class SSEmulatorBridge : EmulatorBridgeBase {
    static let shared = SSEmulatorBridge()

    override func activateInput(_ input: Int, value: Double, playerIndex: Int) {
        guard playerIndex >= 0 else { return }
        if let gameInput = SSGameInput(rawValue: input),
            let libretroButton = gameInputToCoreInput(gameInput: gameInput) {
#if DEBUG
Log.debug("🎮 \(objectInfo(self)) 点击了:\(gameInput)")
#endif
            LibretroCore.sharedInstance().press(libretroButton, playerIndex: UInt32(playerIndex))
        }
    }
    
    func gameInputToCoreInput(gameInput: SSGameInput) -> LibretroButton? {
        if gameInput == .a { return .B }
        else if gameInput == .b { return .A }
        else if gameInput == .c { return .R1 }
        else if gameInput == .x { return .Y }
        else if gameInput == .y { return .X }
        else if gameInput == .z { return .L1 }
        else if gameInput == .l { return .L2 }
        else if gameInput == .l1 { return .L2 }
        else if gameInput == .r { return .R2 }
        else if gameInput == .r1 { return .R2 }
        else if gameInput == .start { return .start }
        else if gameInput == .select { return .select }
        else if gameInput == .up { return .up }
        else if gameInput == .down { return .down }
        else if gameInput == .left { return .left }
        else if gameInput == .right { return .right }
        return nil
    }
    
    override func deactivateInput(_ input: Int, playerIndex: Int) {
        if let gameInput = SSGameInput(rawValue: input),
            let libretroButton = gameInputToCoreInput(gameInput: gameInput) {
            LibretroCore.sharedInstance().release(libretroButton, playerIndex: UInt32(playerIndex))
        }
    }
}
