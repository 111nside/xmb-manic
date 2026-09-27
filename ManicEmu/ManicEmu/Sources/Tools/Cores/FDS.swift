//
//  FDS.swift
//  ManicEmu
//
//  Created by Daiuno on 2025/10/26.
//  Copyright © 2025 Manic EMU. All rights reserved.
//
// SPDX-License-Identifier: AGPL-3.0-or-later


import AVFoundation

extension GameType {
    static let fds = GameType("public.aoshuang.game.fds")
}

@objc enum FDSGameInput: Int, Input, CaseIterable {
    case a
    case b
    case start
    case select
    case up
    case down
    case left
    case right
    
    case x//Turbo A
    case y//Turbo B
    case l1//(FDS) Disk Side Change
    case r1//(FDS) Eject Disk
    case l2//(VSSystem) Coin 1
    case r2//(VSSystem) Coin 2
    case l3//(Famicom) Microphone
    case r3

    case flex
    case menu

    var type: InputType {
        return .game(.fds)
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
        else if stringValue == "x" { self = .x }
        else if stringValue == "y" { self = .y }
        else if stringValue == "l1" { self = .l1 }
        else if stringValue == "r1" { self = .r1 }
        else if stringValue == "l2" { self = .l2 }
        else if stringValue == "r2" { self = .r2 }
        else if stringValue == "l3" { self = .l3 }
        else if stringValue == "r3" { self = .r3 }
        else { return nil }
    }
}

struct FDS: DeltaCoreProtocol {
    static let core = FDS()
    
    var name: String { "FDS" }
    var identifier: String { "com.aoshuang.FDSCore" }
    
    var gameType: GameType { GameType.fds }
    var gameInputType: Input.Type { FDSGameInput.self }
    var allInputs: [Input] { FDSGameInput.allCases }
    var gameSaveFileExtension: String { "srm" }
        
    
    let videoFormat = VideoFormat(format: .bitmap(.rgb565), dimensions: CGSize(width: 256, height: 240))
    
    var supportedCheatFormats: Set<CheatFormat> {
        let gameGenie6Format = CheatFormat(name: NSLocalizedString("Game Genie (6)", comment: ""), format: "XXXXXX", type: .gameGenie6, allowedCodeCharacters: .letters)
        let gameGenie8Format = CheatFormat(name: NSLocalizedString("Game Genie (8)", comment: ""), format: "XXXXXXXX", type: .gameGenie8, allowedCodeCharacters: .letters)
        return [gameGenie6Format, gameGenie8Format]
    }
    
    var emulatorBridge: EmulatorBridging { FDSEmulatorBridge.shared }
    
    private init() {}
}


class FDSEmulatorBridge : EmulatorBridgeBase {
    static let shared = FDSEmulatorBridge()

    private var thumbstickPosition: CGPoint = .zero

    override func activateInput(_ input: Int, value: Double, playerIndex: Int) {
        guard playerIndex >= 0 else { return }
        if let gameInput = FDSGameInput(rawValue: input),
            let libretroButton = gameInputToCoreInput(gameInput: gameInput) {
#if DEBUG
Log.debug("🎮 \(objectInfo(self)) 点击了:\(gameInput)")
#endif
            LibretroCore.sharedInstance().press(libretroButton, playerIndex: UInt32(playerIndex))
        }
    }
    
    func gameInputToCoreInput(gameInput: FDSGameInput) -> LibretroButton? {
        if gameInput == .a { return .A }
        else if gameInput == .b { return .B }
        else if gameInput == .start { return .start }
        else if gameInput == .select { return .select }
        else if gameInput == .up { return .up }
        else if gameInput == .down { return .down }
        else if gameInput == .left { return .left }
        else if gameInput == .right { return .right }
        else if gameInput == .x { return .X }
        else if gameInput == .y { return .Y }
        else if gameInput == .l1 { return .L1 }
        else if gameInput == .r1 { return .R1 }
        else if gameInput == .l2 { return .L2 }
        else if gameInput == .r2 { return .R2 }
        else if gameInput == .l3 { return .L3 }
        else if gameInput == .r3 { return .R3 }
        return nil
    }
    
    override func deactivateInput(_ input: Int, playerIndex: Int) {
        if let gameInput = FDSGameInput(rawValue: input),
            let libretroButton = gameInputToCoreInput(gameInput: gameInput) {
            LibretroCore.sharedInstance().release(libretroButton, playerIndex: UInt32(playerIndex))
        }
    }
}

