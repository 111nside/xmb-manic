//
//  GBC.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/8/28.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import AVFoundation

extension GameType
{
    static let gbc = GameType("public.aoshuang.game.gbc")
}

@objc enum GBCGameInput: Int, Input, CaseIterable {
    case a
    case b
    case start
    case select
    case up
    case down
    case left
    case right

    case flex
    case menu

    var type: InputType {
        return .game(.gbc)
    }
    
    init?(stringValue: String) {
        if stringValue == "a" { self = .a }
        else if stringValue == "b" { self = .b }
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

struct GBC: DeltaCoreProtocol {
    static let core = GBC()
    
    var name: String { "GBC" }
    var identifier: String { "com.aoshuang.GBCCore" }
    
    var gameType: GameType { GameType.gbc }
    var gameInputType: Input.Type { GBCGameInput.self }
    var allInputs: [Input] { GBCGameInput.allCases }
    var gameSaveFileExtension: String { "sav" }
        
    
    let videoFormat = VideoFormat(format: .bitmap(.bgra8), dimensions: CGSize(width: 160, height: 144))
    
    var supportedCheatFormats: Set<CheatFormat> {
        let gameGenieFormat = CheatFormat(name: NSLocalizedString("Game Genie", comment: ""), format: "XXX-YYY-ZZZ", type: .gameGenie)
        let gameSharkFormat = CheatFormat(name: NSLocalizedString("GameShark", comment: ""), format: "XXXXXXXX", type: .gameShark)
        return [gameGenieFormat, gameSharkFormat]
    }
    
    var emulatorBridge: EmulatorBridging { GBCEmulatorBridge.shared }
    
    private init() {}
}


class GBCEmulatorBridge : EmulatorBridgeBase {
    static let shared = GBCEmulatorBridge()

    private var thumbstickPosition: CGPoint = .zero

    override func activateInput(_ input: Int, value: Double, playerIndex: Int) {
        guard playerIndex >= 0 else { return }
        if let gameInput = GBCGameInput(rawValue: input),
            let libretroButton = gameInputToCoreInput(gameInput: gameInput) {
#if DEBUG
Log.debug("🎮 \(objectInfo(self)) 点击了:\(gameInput)")
#endif
            LibretroCore.sharedInstance().press(libretroButton, playerIndex: UInt32(playerIndex))
        }
    }
    
    func gameInputToCoreInput(gameInput: GBCGameInput) -> LibretroButton? {
        if gameInput == .a { return .A }
        else if gameInput == .b { return .B }
        else if gameInput == .start { return .start }
        else if gameInput == .select { return .select }
        else if gameInput == .up { return .up }
        else if gameInput == .down { return .down }
        else if gameInput == .left { return .left }
        else if gameInput == .right { return .right }
        return nil
    }
    
    override func deactivateInput(_ input: Int, playerIndex: Int) {
        if let gameInput = GBCGameInput(rawValue: input),
            let libretroButton = gameInputToCoreInput(gameInput: gameInput) {
            LibretroCore.sharedInstance().release(libretroButton, playerIndex: UInt32(playerIndex))
        }
    }
}
