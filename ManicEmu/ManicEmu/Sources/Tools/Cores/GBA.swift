//
//  GBA.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/8/28.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later


import AVFoundation

extension GameType
{
    static let gba = GameType("public.aoshuang.game.gba")
}

@objc enum GBAGameInput: Int, Input, CaseIterable {
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

    case flex
    case menu

    var type: InputType {
        return .game(.gba)
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
        else if stringValue == "menu" { self = .menu }
        else if stringValue == "up" { self = .up }
        else if stringValue == "down" { self = .down }
        else if stringValue == "left" { self = .left }
        else if stringValue == "right" { self = .right }
        else if stringValue == "flex" { self = .flex }
        else { return nil }
    }
}

struct GBA: DeltaCoreProtocol {
    static let core = GBA()
    
    var name: String { "GBA" }
    var identifier: String { "com.aoshuang.GBACore" }
    
    var gameType: GameType { GameType.gba }
    var gameInputType: Input.Type { GBAGameInput.self }
    var allInputs: [Input] { GBAGameInput.allCases }
    var gameSaveFileExtension: String { "sav" }
        
    
    let videoFormat = VideoFormat(format: .bitmap(.bgra8), dimensions: CGSize(width: 240, height: 160))
    
    var supportedCheatFormats: Set<CheatFormat> {
        let actionReplayFormat = CheatFormat(name: NSLocalizedString("Action Replay", comment: ""), format: "XXXXXXXX YYYYYYYY", type: .actionReplay)
        let gameSharkFormat = CheatFormat(name: NSLocalizedString("GameShark", comment: ""), format: "XXXXXXXX YYYYYYYY", type: .gameShark)
        let codeBreakerFormat = CheatFormat(name: NSLocalizedString("Code Breaker", comment: ""), format: "XXXXXXXX YYYY", type: .codeBreaker)
        return [actionReplayFormat, gameSharkFormat, codeBreakerFormat]
    }
    
    var emulatorBridge: EmulatorBridging { GBAEmulatorBridge.shared }
    
    private init() {}
}


class GBAEmulatorBridge : EmulatorBridgeBase {
    static let shared = GBAEmulatorBridge()

    private var thumbstickPosition: CGPoint = .zero

    override func activateInput(_ input: Int, value: Double, playerIndex: Int) {
        guard playerIndex >= 0 else { return }
        if let gameInput = GBAGameInput(rawValue: input),
            let libretroButton = gameInputToCoreInput(gameInput: gameInput) {
#if DEBUG
Log.debug("🎮 \(objectInfo(self)) 点击了:\(gameInput)")
#endif
            LibretroCore.sharedInstance().press(libretroButton, playerIndex: UInt32(playerIndex))
        }
    }
    
    func gameInputToCoreInput(gameInput: GBAGameInput) -> LibretroButton? {
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
        return nil
    }
    
    override func deactivateInput(_ input: Int, playerIndex: Int) {
        if let gameInput = GBAGameInput(rawValue: input),
            let libretroButton = gameInputToCoreInput(gameInput: gameInput) {
            LibretroCore.sharedInstance().release(libretroButton, playerIndex: UInt32(playerIndex))
        }
    }
}
